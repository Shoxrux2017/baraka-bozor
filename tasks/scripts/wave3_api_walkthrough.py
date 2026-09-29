"""Wave 3 closure: the API walkthrough against the real stack.

usage: python tasks/scripts/wave3_api_walkthrough.py [base]
       (default http://127.0.0.1:8000/api/v1)

Needs the stack served as `docker/README.md` says, the staff accounts of
`WalkthroughSeeder`, and the first of `LOGIN_CODE_TEST_PHONES` as the
Customer. The staff password, the test phones and their code are read from
`backend/.env`; variables of the same names in the environment take
precedence. Rerunning within a minute waits out the code resend limit.

It takes about thirty-five minutes: a question to the Customer expires
thirty minutes after it is asked, and an approval's instants cannot be moved
(its guard trigger keeps them, `DL-55`), so the question is asked first, on
an order of its own, and the rest of the scenario runs while it waits
(`DL-73` (1)). The expiry command runs through `docker compose exec`, as the
stack has no scheduler yet; the order's history proves it wrote the expiry.

The Admin completes the settings and a catalog and creates two Couriers, who
pass their first-login gate. The Customer places three cash orders; the
Operator assigns the Shopper to all three. On the first order the Shopper
buys a fixed line and an estimate within the tolerance, asks about a price
above it, replaces a line automatically and another with the Customer's
approval, and marks one line unavailable; the Customer approves one question
and rejects the other; the Admin corrects a price; the shopping completes
with the final amount. A first Courier fails the delivery, which returns to
the board; a second one delivers it and collects the exact cash. The second
order's cancellation is requested during shopping and approved. On the third
order a question about a smaller quantity expires, and the Operator removes
its line. The attention list and the summary strip are checked as the orders
move. Every step is checked; tokens, codes and passwords are never printed.
"""

import json
import os
import pathlib
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/api/v1"
ROOT = pathlib.Path(__file__).resolve().parents[2]
# The details name products in Russian too; a Windows console or a log file
# otherwise takes its code page.
sys.stdout.reconfigure(encoding="utf-8")
RESULTS: list[tuple[str, bool, str]] = []


def local_setting(name: str) -> str:
    if os.environ.get(name):
        return os.environ[name]
    env = ROOT / "backend" / ".env"
    for line in env.read_text(encoding="utf-8").splitlines():
        key, _, value = line.partition("=")
        if key.strip() == name and value.strip():
            return value.strip().strip('"')
    sys.exit(f"{name} is not set in backend/.env or the environment")


STAFF_PASSWORD = local_setting("WALKTHROUGH_STAFF_PASSWORD")
TEST_PHONES = [p.strip() for p in local_setting("LOGIN_CODE_TEST_PHONES").split(",")]
TEST_CODE = local_setting("LOGIN_CODE_TEST_CODE")
CUSTOMER_PHONE = TEST_PHONES[0]
SHOPPER_PHONE = "+998900000002"
OPERATOR_PHONE = "+998900000004"
ADMIN_PHONE = "+998900000005"


def call(method, path, token=None, body=None, key=None):
    headers = {"Accept": "application/json"}
    data = None
    if token:
        headers["Authorization"] = "Bearer " + token
    if key:
        headers["Idempotency-Key"] = key
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(BASE + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            text = response.read().decode()
            return response.status, (json.loads(text) if text else None)
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        return error.code, (json.loads(text) if text else None)


def check(name, ok, detail=""):
    RESULTS.append((name, bool(ok), detail))
    print(("PASS " if ok else "FAIL ") + name + (f" — {detail}" if detail else ""), flush=True)
    return ok


def code(answer):
    return answer and answer.get("code")


def staff(phone, password=STAFF_PASSWORD):
    status, answer = call("POST", "/auth/staff/login", body={"phone": phone, "password": password})
    return status, answer


def customer_sign_in(phone, name):
    status, answer = call("POST", "/auth/customer/code/request", body={"phone": phone})
    # A resend within the minute waits it out; the hourly limit does not pass
    # by waiting, and the sign-in below then fails as itself.
    if code(answer) == "code_resend_too_soon":
        time.sleep(61)
        status, answer = call("POST", "/auth/customer/code/request", body={"phone": phone})
    status, answer = call("POST", "/auth/customer/code/verify", body={"phone": phone, "code": TEST_CODE})
    token = answer["data"]["token"] if status == 200 else None
    if token:
        call("PATCH", "/customer/profile", token, {"full_name": name})
        # A cart left from an earlier run starts empty.
        _, cart = call("GET", "/customer/cart", token)
        for item in (cart or {}).get("data", {}).get("items", []):
            call("DELETE", f"/customer/cart/items/{item['id']}", token)
    return status, token


def attention(operator):
    status, answer = call("GET", "/operations/attention", operator)
    return {(i["type"], i["order_id"]) for i in answer["data"]} if status == 200 else set()


def summary(operator):
    status, answer = call("GET", "/operations/summary", operator)
    return answer["data"] if status == 200 else {}


def moved(before, after, **deltas):
    """Whether the summary moved by exactly [deltas] between two readings:
    `completed_today=1`, or `open_new=-3` for `open_by_status.new`."""
    def value(reading, name):
        if name.startswith("open_"):
            return reading.get("open_by_status", {}).get(name[5:], 0)
        return reading.get(name, 0)

    return all(value(after, name) - value(before, name) == delta for name, delta in deltas.items())


def picker(operator, path):
    """Every entry of a staff picker, page by page, by phone."""
    entries, page = {}, 1
    while True:
        status, answer = call("GET", f"{path}?per_page=100&page={page}", operator)
        if status != 200:
            return entries
        entries.update({entry["phone"]: entry["id"] for entry in answer["data"]})
        if page >= answer["meta"]["pagination"]["last_page"]:
            return entries
        page += 1


def artisan(*arguments):
    run = subprocess.run(
        ["docker", "compose", "-f", str(ROOT / "docker" / "compose.yaml"), "exec", "-T", "app", "php", "artisan",
         *arguments], capture_output=True, text=True)
    return run.returncode, run.stdout


def history_events(operator, order_id):
    status, answer = call("GET", f"/operations/orders/{order_id}", operator)
    return [h["event_type"] for h in answer["data"]["history"]] if status == 200 else None


def await_attention(operator, item, timeout=240):
    """Polls the attention list until [item] is on it; the server's clock,
    not this machine's, decides when a question needs an Operator."""
    deadline = time.monotonic() + timeout
    while True:
        if item in attention(operator):
            return True
        if time.monotonic() > deadline:
            return False
        time.sleep(10)


def walk():
    # --- The Admin: settings, a catalog, two Couriers -----------------------
    status, answer = staff(ADMIN_PHONE)
    check("Admin signs in", status == 200 and answer["data"]["user"]["role"] == "admin", f"{status}")
    admin = answer["data"]["token"]
    status, answer = call("PATCH", "/admin/settings/business", admin, {
        "markup_percent": "15.00", "service_fee_mode": "fixed", "service_fee_fixed_uzs": 5000,
        "service_fee_percent": None, "delivery_fee_uzs": 15000, "minimum_order_uzs": 50000,
        "price_tolerance_percent": "15.00", "opens_at": "08:00", "closes_at": "22:00",
        "service_centre_latitude": "41.311081", "service_centre_longitude": "69.240562",
        "service_radius_km": "5.00", "delivery_delay_threshold_minutes": 60,
    })
    check("Admin completes the business settings, tolerance 15 %", status == 200
          and answer["data"]["price_tolerance_percent"] == "15.00", f"{status}")

    stamp = str(int(time.time()))[-5:]
    status, answer = call("POST", "/admin/categories", admin, {
        "name_uz": f"Bozor {stamp}", "name_ru": f"Базар {stamp}", "sort_order": 1})
    category = answer["data"]["id"] if status == 201 else None
    check("Admin creates a category", status == 201, f"{status}")

    products = {}
    for key, name_uz, name_ru, unit, mode, market in [
        ("apple", "Olma", "Яблоко", "piece", "fixed", 3000),
        ("bread", "Non", "Хлеб", "piece", "fixed", 4000),
        ("tomato", "Pomidor", "Помидор", "kg", "estimate", 16000),
        ("cucumber", "Bodring", "Огурец", "kg", "estimate", 10000),
        ("potato", "Kartoshka", "Картофель", "kg", "estimate", 8000),
        ("new_potato", "Yangi kartoshka", "Молодой картофель", "kg", "estimate", 8500),
        ("onion", "Piyoz", "Лук", "kg", "estimate", 6000),
        ("red_onion", "Qizil piyoz", "Красный лук", "kg", "estimate", 6500),
        ("carrot", "Sabzi", "Морковь", "kg", "estimate", 5000),
    ]:
        status, answer = call("POST", "/admin/products", admin, {
            "category_id": category, "name_uz": f"{name_uz} {stamp}", "name_ru": f"{name_ru} {stamp}",
            "unit_code": unit, "price_mode": mode, "market_price_uzs": market, "sort_order": 0})
        products[key] = answer["data"]["id"] if status == 201 else None
    check("Admin creates nine products, fixed and estimate", all(products.values()), "")

    couriers = {}
    for label, prefix in (("first", "+99893"), ("second", "+99894")):
        phone = prefix + stamp.rjust(7, "0")
        status, answer = call("POST", "/admin/staff", admin, {
            "full_name": f"Courier {label.title()} {stamp}", "phone": phone, "role": "courier"})
        temporary = answer["data"]["temporary_password"] if status == 201 else ""
        status, answer = staff(phone, temporary)
        token = answer["data"]["token"] if status == 200 else None
        password = secrets.token_urlsafe(16)
        status, _ = call("POST", "/auth/change-password", token, {
            "current_password": temporary, "new_password": password, "new_password_confirmation": password})
        couriers[label] = {"phone": phone, "token": token}
        check(f"The {label} Courier is created and passes the first-login gate", status in (200, 204), f"{status}")

    # --- The Customer places three cash orders -------------------------------
    status, customer = customer_sign_in(CUSTOMER_PHONE, "Aziza Karimova")
    check("The Customer signs in with a test phone", status == 200 and customer, f"{status}")
    status, answer = call("POST", "/customer/addresses", customer, {
        "latitude": "41.320000", "longitude": "69.250000", "street": "Navoiy", "house": "7",
        "apartment": "12", "landmark": "Maktab yonida", "delivery_note": "Podyezdda qo'ng'iroq qiling"})
    home = answer["data"]["id"] if status == 201 else None

    def order(lines, wish=None):
        for product, quantity, policy in lines:
            call("POST", "/customer/cart/items", customer, {
                "product_id": products[product], "quantity": quantity, "substitution_policy": policy})
        status, answer = call("POST", "/customer/checkout/preview", customer, {
            "address_id": home, "payment_method": "cash", "delivery_time_note": wish})
        token = answer["data"]["checkout_token"] if status == 200 else None
        status, answer = call("POST", "/customer/orders", customer, {"checkout_token": token}, str(uuid.uuid4()))
        return answer["data"] if status == 201 else {}

    similar, contact, remove = ("allow_similar_substitution", "contact_before_substitution", "remove_if_unavailable")
    first = order([("apple", "2", similar), ("tomato", "2.000", similar), ("cucumber", "1.000", contact),
                   ("potato", "2.000", similar), ("onion", "1.000", contact), ("bread", "1", remove)], "Kechqurun")
    check("The Customer places the first order, six lines, an estimate of 105 100",
          first.get("totals", {}).get("total_uzs") == 105100, f"{first.get('totals')}")
    second = order([("apple", "20", similar)])
    check("The Customer places a second order", second.get("status") == "new", "")
    third = order([("apple", "15", similar), ("carrot", "3.000", contact)])
    check("The Customer places a third order", third.get("status") == "new", "")

    # --- The Operator assigns the Shopper ------------------------------------
    status, answer = staff(OPERATOR_PHONE)
    check("The Operator signs in", status == 200, f"{status}")
    operator = answer["data"]["token"]
    shopper_id = picker(operator, "/operations/shoppers").get(SHOPPER_PHONE)
    placed_summary = summary(operator)
    for placed in (third, first, second):
        status, answer = call("POST", f"/operations/orders/{placed['id']}/shopper-assignment", operator,
                              {"shopper_id": shopper_id})
        check(f"The Operator assigns order {placed.get('order_number')} to the Shopper",
              status == 200 and answer["data"]["status"] == "shopping_assigned", f"{status}")
    assigned_summary = summary(operator)
    check("The summary strip moves the three orders from new to a Shopper assigned",
          moved(placed_summary, assigned_summary, open_new=-3, open_shopping_assigned=3), f"{assigned_summary}")

    status, answer = staff(SHOPPER_PHONE)
    check("The Shopper signs in", status == 200, f"{status}")
    shopper = answer["data"]["token"]

    def shopping(placed):
        _, accepted = call("POST", f"/shopper/orders/{placed['id']}/accept", shopper)
        status, answer = call("POST", f"/shopper/orders/{placed['id']}/start", shopper)
        lines = {i["product_id"]: i for i in answer["data"]["items"]} if status == 200 else {}
        return status, answer, lines, accepted

    def line_path(placed, lines, product):
        return f"/shopper/orders/{placed['id']}/items/{lines[products[product]]['id']}"

    # --- The third order: the question that will expire ----------------------
    status, answer, third_lines, accepted = shopping(third)
    check("Accepted, the order shows the Shopper no phone yet",
          (accepted or {}).get("data", {}).get("customer_phone", "") is None, "")
    check("Started, it shows the Customer's phone while shopping",
          status == 200 and answer["data"]["status"] == "shopping" and answer["data"]["customer_phone"] == CUSTOMER_PHONE,
          f"{status}")
    call("POST", line_path(third, third_lines, "apple") + "/purchase", shopper, {"purchased_quantity": "15"},
         str(uuid.uuid4()))
    status, answer = call("POST", line_path(third, third_lines, "carrot") + "/reduced-quantity-approval", shopper,
                          {"proposed_quantity": "2.000", "note": "Faqat 2 kg qoldi"})
    carrot = next((i for i in answer["data"]["items"] if i["product_id"] == products["carrot"]), {}) if status == 200 else {}
    question = carrot.get("pending_approval") or {}
    check("The Shopper asks the Customer about a smaller quantity", status == 200
          and carrot.get("status") == "awaiting_customer" and question.get("type") == "reduced_quantity", f"{status}")
    expires_at = datetime.fromisoformat(question["expires_at"].replace("Z", "+00:00")) if question \
        else datetime.now(timezone.utc)

    # --- The first order at the market ---------------------------------------
    status, answer, lines, _ = shopping(first)
    check("The Shopper starts the first order; the Customer can no longer edit it",
          status == 200 and call("GET", f"/customer/orders/{first['id']}", customer)[1]["data"]["can_edit"] is False,
          f"{status}")
    status, answer = call("POST", line_path(first, lines, "apple") + "/purchase", shopper,
                          {"purchased_quantity": "2"}, str(uuid.uuid4()))
    check("The Shopper buys the fixed line as itself", status == 200, f"{status}")
    key = str(uuid.uuid4())
    status, answer = call("POST", line_path(first, lines, "tomato") + "/purchase", shopper,
                          {"purchased_quantity": "2.000", "actual_market_price_uzs": 17000}, key)
    tomato = next((i for i in answer["data"]["items"] if i["product_id"] == products["tomato"]), {}) if status == 200 else {}
    check("The Shopper buys the estimate within the tolerance: 17 000 on the market bills 19 550",
          status == 200 and tomato.get("purchase", {}).get("billable_unit_price_uzs") == 19550, f"{status}")
    status, again = call("POST", line_path(first, lines, "tomato") + "/purchase", shopper,
                         {"purchased_quantity": "2.000", "actual_market_price_uzs": 17000}, key)
    check("The purchase sent again under its key answers once", status == 200, f"{status}")

    status, answer = call("POST", line_path(first, lines, "cucumber") + "/purchase", shopper,
                          {"purchased_quantity": "1.000", "actual_market_price_uzs": 12000}, str(uuid.uuid4()))
    check("A price above the tolerance needs the Customer (13 800 against a bound of 13 225)",
          status == 409 and code(answer) == "customer_approval_required"
          and answer["details"]["approval_type"] == "price_over_tolerance"
          and answer["details"]["ceiling_customer_unit_price_uzs"] == 13225
          and answer["details"]["proposed_customer_unit_price_uzs"] == 13800, f"{status} {code(answer)}")
    status, answer = call("POST", line_path(first, lines, "cucumber") + "/price-approval", shopper,
                          {"actual_market_price_uzs": 12000})
    cucumber = next((i for i in answer["data"]["items"] if i["product_id"] == products["cucumber"]), {}) if status == 200 else {}
    check("The Shopper asks the Customer about the price", status == 200
          and cucumber.get("status") == "awaiting_customer"
          and (cucumber.get("pending_approval") or {}).get("type") == "price_over_tolerance", f"{status}")
    status, answer = call("POST", line_path(first, lines, "potato") + "/substitution", shopper,
                          {"replacement_product_id": products["new_potato"], "actual_market_price_uzs": 8500})
    potato = next((i for i in answer["data"]["items"] if i["product_id"] == products["potato"]), {}) if status == 200 else {}
    check("A replacement within the ceiling is authorized at once",
          status == 200 and (potato.get("replacement") or {}).get("substitution_resolution") == "automatic", f"{status}")
    status, answer = call("POST", line_path(first, lines, "potato") + "/purchase", shopper, {
        "purchased_quantity": "2.000", "actual_market_price_uzs": 8500, "fulfilled_product_id": products["new_potato"]},
        str(uuid.uuid4()))
    potato = next((i for i in answer["data"]["items"] if i["product_id"] == products["potato"]), {}) if status == 200 else {}
    check("The Shopper buys the replacement: 8 500 on the market bills 9 775", status == 200
          and (potato.get("purchase") or {}).get("billable_unit_price_uzs") == 9775, f"{status}")
    status, answer = call("POST", line_path(first, lines, "onion") + "/substitution", shopper,
                          {"replacement_product_id": products["red_onion"], "actual_market_price_uzs": 6500,
                           "note": "Oq piyoz yo'q"})
    onion = next((i for i in answer["data"]["items"] if i["product_id"] == products["onion"]), {}) if status == 200 else {}
    check("A replacement under 'contact before' is asked of the Customer", status == 200
          and onion.get("status") == "awaiting_customer"
          and (onion.get("pending_approval") or {}).get("type") == "substitution", f"{status}")
    status, answer = call("POST", line_path(first, lines, "bread") + "/unavailable", shopper, {"note": "Tugagan"})
    bread = next((i for i in answer["data"]["items"] if i["product_id"] == products["bread"]), {}) if status == 200 else {}
    check("The Shopper marks a line unavailable", status == 200
          and bread.get("removed_reason_code") == "unavailable", f"{status}")
    status, answer = call("POST", f"/shopper/orders/{first['id']}/complete", shopper, None, str(uuid.uuid4()))
    check("Shopping cannot complete while the Customer's questions wait",
          status == 409 and code(answer) == "shopping_incomplete" and len(answer["details"]["item_ids"]) == 2,
          f"{status} {code(answer)}")

    # --- The Customer answers -----------------------------------------------
    status, answer = call("GET", "/customer/orders", customer)
    listed = next((o for o in answer["data"] if o["id"] == first["id"]), {}) if status == 200 else {}
    check("My orders counts the two questions waiting", listed.get("pending_approval_count") == 2, f"{listed}")
    status, answer = call("GET", f"/customer/orders/{first['id']}", customer)
    items = {i["product_id"]: i for i in answer["data"]["items"]} if status == 200 else {}
    price_question = items.get(products["cucumber"], {}).get("pending_approval") or {}
    swap_question = items.get(products["onion"], {}).get("pending_approval") or {}
    check("The Customer reads the price question in their prices only",
          price_question.get("proposed_customer_unit_price_uzs") == 13800
          and "proposed_actual_market_price_uzs" not in price_question, f"{price_question}")
    check("The Customer reads the replacement proposed",
          (swap_question.get("replacement") or {}).get("customer_unit_price_uzs") == 7475, f"{swap_question}")
    key = str(uuid.uuid4())
    status, answer = call("POST", f"/customer/approvals/{price_question.get('id')}/decision", customer,
                          {"decision": "approve"}, key)
    check("The Customer approves the price", status == 200 and answer["data"]["status"] == "approved", f"{status}")
    status, answer = call("POST", f"/customer/approvals/{price_question.get('id')}/decision", customer,
                          {"decision": "approve"}, key)
    check("The decision sent again under its key answers the same", status == 200
          and answer["data"]["status"] == "approved", f"{status}")
    status, answer = call("POST", f"/customer/approvals/{swap_question.get('id')}/decision", customer,
                          {"decision": "reject"}, str(uuid.uuid4()))
    check("The Customer rejects the replacement", status == 200 and answer["data"]["status"] == "rejected",
          f"{status}")
    status, answer = call("POST", f"/customer/approvals/{swap_question.get('id')}/decision", customer,
                          {"decision": "approve"}, str(uuid.uuid4()))
    check("A question already answered is refused", status == 409 and code(answer) == "approval_already_resolved",
          f"{status} {code(answer)}")

    status, answer = call("POST", line_path(first, lines, "cucumber") + "/purchase", shopper,
                          {"purchased_quantity": "1.000", "actual_market_price_uzs": 12000}, str(uuid.uuid4()))
    cucumber = next((i for i in answer["data"]["items"] if i["product_id"] == products["cucumber"]), {}) if status == 200 else {}
    check("At the approved price the Shopper buys: 12 000 bills 13 800", status == 200
          and (cucumber.get("purchase") or {}).get("billable_unit_price_uzs") == 13800, f"{status}")

    # --- The Admin corrects a price ------------------------------------------
    status, answer = call("POST", f"/admin/orders/{first['id']}/items/{lines[products['tomato']]['id']}/price-correction",
                          admin, {"actual_market_price_uzs": 16500, "reason": "Chekda 16 500"})
    corrected = next((i for i in answer["data"]["items"] if i["product_id"] == products["tomato"]), {}) \
        if status == 200 else {}
    check("The Admin corrects the price paid: the line bills 18 975", status == 200
          and corrected.get("billable_unit_price_uzs") == 18975, f"{status} {code(answer)}")

    status, answer = call("POST", f"/shopper/orders/{first['id']}/complete", shopper, None, str(uuid.uuid4()))
    check("Shopping completes: ready for delivery", status == 200
          and answer["data"]["status"] == "ready_for_delivery", f"{status} {code(answer)}")
    status, answer = call("GET", f"/customer/orders/{first['id']}", customer)
    done = answer["data"] if status == 200 else {}
    removed = {i["product_id"]: i["removed_reason_code"] for i in done.get("items", []) if i["status"] == "removed"}
    check("The Customer sees the final amount: 78 200 of goods, 98 200 in all",
          done.get("totals", {}).get("total_kind") == "final" and done["totals"]["merchandise_subtotal_uzs"] == 78200
          and done["totals"]["total_uzs"] == 98200, f"{done.get('totals')}")
    check("The rejected and the unavailable lines are removed with their reasons",
          removed == {products["onion"]: "customer_rejected", products["bread"]: "unavailable"}, f"{removed}")

    # --- The second order: a cancellation requested and approved ------------
    status, answer, _, _ = shopping(second)
    status, answer = call("POST", f"/customer/orders/{second['id']}/cancel", customer, {}, str(uuid.uuid4()))
    check("Once shopping started, a cancel needs its reason",
          status == 422 and "reason" in (answer or {}).get("errors", {}), f"{status}")
    status, answer = call("POST", f"/customer/orders/{second['id']}/cancel", customer, {"reason": "Rejam o'zgardi"},
                          str(uuid.uuid4()))
    request = (answer["data"].get("cancellation_request") or {}) if status == 200 else {}
    check("The Customer asks for the cancellation during shopping", status == 200
          and answer["data"]["status"] == "shopping" and request.get("status") == "pending", f"{status}")
    check("The attention list shows the request", ("cancellation_request", second["id"]) in attention(operator), "")
    before_decision = summary(operator)
    status, answer = call("POST", f"/operations/cancellation-requests/{request.get('id')}/decision", operator,
                          {"decision": "approve", "note": "Mijoz so'radi"})
    check("The Operator approves it: the order is cancelled", status == 200
          and answer["data"]["status"] == "cancelled", f"{status} {code(answer)}")
    after_decision = summary(operator)
    check("The summary strip counts the cancellation",
          moved(before_decision, after_decision, cancelled_today=1, open_shopping=-1), f"{after_decision}")
    status, answer = call("GET", f"/customer/orders/{second['id']}", customer)
    check("The Customer sees the request approved", status == 200
          and answer["data"]["cancellation_request"]["status"] == "approved", f"{status}")

    # --- Delivery: a failure, then the cash ---------------------------------
    courier_ids = picker(operator, "/operations/couriers")
    check("The Courier picker lists the new Couriers",
          all(c["phone"] in courier_ids for c in couriers.values()), "")

    def deliver_by(label):
        token = couriers[label]["token"]
        status, answer = call("POST", f"/operations/orders/{first['id']}/courier-assignment", operator,
                              {"courier_id": courier_ids[couriers[label]["phone"]]})
        check(f"The Operator assigns the {label} Courier", status == 200
              and answer["data"]["status"] == "delivery_assigned", f"{status} {code(answer)}")
        status, answer = call("GET", "/courier/orders", token)
        row = next((o for o in answer["data"] if o["id"] == first["id"]), {}) if status == 200 else {}
        check(f"The {label} Courier sees the delivery with the cash to collect",
              row.get("amount_to_collect_uzs") == 98200 and row.get("recipient", {}).get("full_name") == "Aziza Karimova"
              and "shopper_phone" not in row, f"{status}")
        call("POST", f"/courier/orders/{first['id']}/accept", token)
        status, answer = call("POST", f"/courier/orders/{first['id']}/start", token)
        check(f"The {label} Courier sets off", status == 200 and answer["data"]["status"] == "on_the_way"
              and answer["data"]["assignment"]["delay_at"], f"{status}")
        return token

    first_courier = deliver_by("first")
    status, answer = call("POST", f"/courier/orders/{first['id']}/not-delivered", first_courier,
                          {"reason_code": "no_answer"})
    check("The first Courier cannot deliver: the order is back with the Operator, the answer tells no recipient",
          status == 200 and answer["data"]["status"] == "ready_for_delivery" and answer["data"]["recipient"] is None,
          f"{status}")
    check("The attention list shows the failed delivery", ("delivery_failed", first["id"]) in attention(operator), "")
    second_courier = deliver_by("second")
    check("Assigning another Courier takes the failure off the list",
          ("delivery_failed", first["id"]) not in attention(operator), "")
    before_delivery = summary(operator)
    key = str(uuid.uuid4())
    status, answer = call("POST", f"/courier/orders/{first['id']}/delivered", second_courier,
                          {"cash_received_uzs": 97200}, key)
    check("Cash short of the total is refused with the amount to collect",
          status == 409 and code(answer) == "cash_amount_mismatch" and answer["details"]["expected_uzs"] == 98200,
          f"{status} {code(answer)}")
    status, answer = call("POST", f"/courier/orders/{first['id']}/delivered", second_courier,
                          {"cash_received_uzs": 98200}, key)
    check("The second Courier delivers and takes the exact cash", status == 200
          and answer["data"]["status"] == "completed", f"{status} {code(answer)}")
    status, answer = call("POST", f"/courier/orders/{first['id']}/delivered", second_courier,
                          {"cash_received_uzs": 98200}, str(uuid.uuid4()))
    check("Delivered again with a new key answers the completed order", status == 200
          and answer["data"]["status"] == "completed", f"{status}")
    status, answer = call("GET", f"/customer/orders/{first['id']}", customer)
    payment = answer["data"]["payment"] if status == 200 else None
    check("The Customer sees the order delivered and paid in cash", answer["data"]["status"] == "completed"
          and payment and payment["method"] == "cash" and payment["amount_uzs"] == 98200, f"{payment}")
    status, answer = call("GET", f"/operations/orders/{first['id']}", operator)
    assignments = answer["data"]["courier_assignments"] if status == 200 else []
    check("The board keeps both Couriers: the failure with its reason, then the delivery",
          [(a["ended_reason"], a["failed_reason_code"]) for a in assignments]
          == [("delivery_failed", "no_answer"), ("completed", None)]
          and answer["data"]["payment"]["recorded_by"]["id"] == courier_ids[couriers["second"]["phone"]], f"{status}")
    after_delivery = summary(operator)
    check("The summary strip counts the delivery and its sales",
          moved(before_delivery, after_delivery, completed_today=1, sales_today_uzs=98200, open_on_the_way=-1),
          f"{after_delivery}")

    # --- The third order: the question expires ------------------------------
    def wait_until(instant, what):
        wait = (instant - datetime.now(timezone.utc)).total_seconds() + 5
        if wait > 0:
            print(f"… waiting {int(wait)} s {what}", flush=True)
            time.sleep(wait)

    # Ten minutes after it was asked, an unanswered question needs an
    # Operator; thirty minutes after, it has expired (BR-APP-002, -003).
    wait_until(expires_at - timedelta(minutes=20), "for the question to need an Operator")
    check("Unanswered after ten minutes, the question is an attention item",
          await_attention(operator, ("approval_pending", third["id"])), "")
    wait_until(expires_at, "for the question to expire")
    check("Past its expiry the question is an attention item",
          await_attention(operator, ("approval_expired", third["id"])), "")
    check("Nothing has written the expiry yet",
          "approval_expired" not in (history_events(operator, third["id"]) or ["approval_expired"]), "")
    returned, output = artisan("approvals:expire")
    written = re.search(r"Expired (\d+) approval", output)
    check("The expiry command writes it", returned == 0 and written and int(written.group(1)) >= 1
          and (history_events(operator, third["id"]) or []).count("approval_expired") == 1,
          (written.group(0) if written else "no count"))
    status, answer = call("POST", f"/customer/approvals/{question.get('id')}/decision", customer,
                          {"decision": "approve"}, str(uuid.uuid4()))
    check("The Customer can no longer answer it", status == 409 and code(answer) == "approval_expired",
          f"{status} {code(answer)}")
    status, answer = call("GET", "/customer/approvals?status=expired", customer)
    check("The Customer's expired questions list it",
          status == 200 and question.get("id") in [a["id"] for a in answer["data"]], f"{status}")
    status, answer = call("POST", f"/operations/approvals/{question.get('id')}/resolve-expired", operator,
                          {"resolution": "remove_item", "note": "Mijoz javob bermadi"})
    carrot = next((i for i in answer["data"]["items"] if i["product_id"] == products["carrot"]), {}) \
        if status == 200 else {}
    check("The Operator removes its line", status == 200 and carrot.get("removed_reason_code") == "approval_expired",
          f"{status} {code(answer)}")
    check("The expired question leaves the attention list", ("approval_expired", third["id"]) not in attention(operator),
          "")
    status, answer = call("POST", f"/shopper/orders/{third['id']}/complete", shopper, None, str(uuid.uuid4()))
    check("The third order's shopping completes on what was bought, and the phone is gone", status == 200
          and answer["data"]["status"] == "ready_for_delivery" and answer["data"]["customer_phone"] is None,
          f"{status} {code(answer)}")

    for token in (customer, operator, admin, shopper, *(c["token"] for c in couriers.values())):
        call("POST", "/auth/logout", token)


try:
    walk()
except (KeyError, TypeError, IndexError, AttributeError) as error:
    # An answer without the field a later step needs: the steps before say which.
    check("The walkthrough reached its end", False, type(error).__name__)

passed = sum(1 for _, ok, _ in RESULTS if ok)
print(f"\n{passed} of {len(RESULTS)} steps pass")
sys.exit(0 if passed == len(RESULTS) else 1)
