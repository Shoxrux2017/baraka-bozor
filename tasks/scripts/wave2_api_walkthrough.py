"""Wave 2 closure: the API walkthrough against the real stack.

usage: python tasks/scripts/wave2_api_walkthrough.py [base]
       (default http://127.0.0.1:8000/api/v1)

Needs the stack served as `docker/README.md` says, the staff accounts of
`WalkthroughSeeder` and two test phones: the first of
`LOGIN_CODE_TEST_PHONES` is the Customer, and the Shopper's own phone
(+998 90 000 00 02, also a test phone) orders in Customer mode. The staff
password, the test phones and their code are read from `backend/.env`;
variables of the same names in the environment take precedence. Rerunning
within a minute waits out the code resend limit.

The Admin completes the settings and the catalog; the Customer fills a cart,
is refused below the minimum and with online payment, orders with cash
(once, whatever the retries), edits the order — refused below the minimum,
then changing, taking out and adding lines — and cancels a second order; the
Shopper orders from their own phone. The Operator sees the orders on the
board and in the summary, assigns a Shopper, reassigns, is refused a stale
reassignment, and sees the Shopper's own order flagged. Every step is
checked; tokens, codes and passwords are never printed.
"""

import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/api/v1"
RESULTS: list[tuple[str, bool, str]] = []


def local_setting(name: str) -> str:
    if os.environ.get(name):
        return os.environ[name]
    env = pathlib.Path(__file__).resolve().parents[2] / "backend" / ".env"
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
if SHOPPER_PHONE not in TEST_PHONES:
    sys.exit("the Shopper's phone must be one of LOGIN_CODE_TEST_PHONES to order in Customer mode")


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
    print(("PASS " if ok else "FAIL ") + name + (f" — {detail}" if detail else ""))
    return ok


def code(answer):
    return answer and answer.get("code")


def staff(phone):
    status, answer = call("POST", "/auth/staff/login", body={"phone": phone, "password": STAFF_PASSWORD})
    return status, answer


def customer_sign_in(phone, name):
    status, answer = call("POST", "/auth/customer/code/request", body={"phone": phone})
    if status == 429 or code(answer) == "code_resend_too_soon":
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


def address(token, house):
    status, answer = call("POST", "/customer/addresses", token, {
        "latitude": "41.320000", "longitude": "69.250000", "street": "Navoiy", "house": house})
    return answer["data"]["id"] if status == 201 else None


def line_of(cart, product):
    return next((i for i in cart["items"] if i["product_id"] == product), None)


# --- Admin ---------------------------------------------------------------
status, answer = staff(ADMIN_PHONE)
check("Admin signs in", status == 200 and answer["data"]["user"]["role"] == "admin", f"{status}")
admin = answer["data"]["token"]

status, answer = call("PATCH", "/admin/settings/business", admin, {
    "markup_percent": "15.00",
    "service_fee_mode": "fixed",
    "service_fee_fixed_uzs": 5000,
    "service_fee_percent": None,
    "delivery_fee_uzs": 15000,
    "minimum_order_uzs": 50000,
    "price_tolerance_percent": "15.00",
    "opens_at": "08:00",
    "closes_at": "22:00",
    "service_centre_latitude": "41.311081",
    "service_centre_longitude": "69.240562",
    "service_radius_km": "5.00",
})
check("Admin completes the business settings", status == 200 and answer["data"]["minimum_order_uzs"] == 50000,
      f"{status}")

stamp = str(int(time.time()))[-5:]
status, answer = call("POST", "/admin/categories", admin, {
    "name_uz": f"Bozor {stamp}", "name_ru": f"Базар {stamp}", "sort_order": 1})
check("Admin creates a category", status == 201, f"{status}")
category = answer["data"]["id"]


def product(name_uz, name_ru, unit, mode, market):
    status, answer = call("POST", "/admin/products", admin, {
        "category_id": category, "name_uz": f"{name_uz} {stamp}", "name_ru": f"{name_ru} {stamp}",
        "unit_code": unit, "price_mode": mode, "market_price_uzs": market, "sort_order": 0})
    return status, answer


status, answer = product("Pomidor", "Помидор", "kg", "estimate", 16000)
check("Admin creates an estimate product by weight", status == 201 and answer["data"]["customer_unit_price_uzs"] == 18400,
      f"{status}")
tomato = answer["data"]["id"]
status, answer = product("Olma", "Яблоко", "piece", "fixed", 3000)
check("Admin creates a fixed product by the piece", status == 201 and answer["data"]["customer_unit_price_uzs"] == 3450,
      f"{status}")
apple = answer["data"]["id"]
status, answer = product("Non", "Хлеб", "piece", "fixed", 4000)
check("Admin creates a third product", status == 201 and answer["data"]["customer_unit_price_uzs"] == 4600, f"{status}")
bread = answer["data"]["id"]

second_phone = "+99891" + stamp.rjust(7, "0")
status, answer = call("POST", "/admin/staff", admin, {"full_name": "Bobur Aliyev", "phone": second_phone, "role": "shopper"})
check("Admin creates a second Shopper", status == 201, f"{status}")
second_shopper = answer["data"]["user"]["id"]

# --- The Customer ----------------------------------------------------------
status, customer = customer_sign_in(CUSTOMER_PHONE, "Aziza Karimova")
check("The Customer signs in with a test phone and keeps a name", status == 200 and customer, f"{status}")
home = address(customer, "5A")
check("The Customer saves an address inside the area", home, "")

status, answer = call("POST", "/customer/cart/items", customer, {"product_id": tomato, "quantity": "1.500"})
check("A kilo and a half of the estimate product goes into the cart",
      status == 201 and line_of(answer["data"], tomato)["quantity"] == "1.500", f"{status}")
status, answer = call("POST", "/customer/cart/items", customer, {
    "product_id": apple, "quantity": "2", "customer_note": "Qizil", "substitution_policy": "contact_before_substitution"})
check("Two of the fixed product go in, with a note and a rule",
      status == 201 and answer["data"]["item_count"] == 2 and answer["data"]["estimated_subtotal_uzs"] == 27600 + 6900,
      f"{status} {answer and answer.get('data', {}).get('estimated_subtotal_uzs')}")
tomato_line = line_of(answer["data"], tomato)["id"]
status, answer = call("POST", "/customer/cart/items", customer, {"product_id": apple, "quantity": "1"})
check("The same product again is refused, naming its line",
      status == 409 and code(answer) == "cart_item_already_exists" and answer["details"]["cart_item_id"], f"{status}")
status, answer = call("POST", "/customer/cart/items", customer, {"product_id": bread, "quantity": "1.5"})
check("A fraction of a piece is refused", status == 422, f"{status}")

status, answer = call("POST", "/customer/checkout/preview", customer, {
    "address_id": home, "payment_method": "cash", "delivery_time_note": None})
check("Below the minimum the preview is refused with the shortfall",
      status == 409 and code(answer) == "minimum_order_not_reached"
      and answer["details"]["minimum_order_uzs"] == 50000 and answer["details"]["shortfall_uzs"] == 50000 - 34500,
      f"{status} {answer and answer.get('details')}")
status, answer = call("PATCH", f"/customer/cart/items/{tomato_line}", customer, {"quantity": "3"})
check("The Customer raises the weight", status == 200 and line_of(answer["data"], tomato)["quantity"] == "3.000",
      f"{status}")
status, answer = call("POST", "/customer/checkout/preview", customer, {
    "address_id": home, "payment_method": "online", "delivery_time_note": None})
check("Online payment is refused in this wave", status == 409 and code(answer) == "payment_method_unavailable",
      f"{status} {code(answer)}")

status, answer = call("POST", "/customer/checkout/preview", customer, {
    "address_id": home, "payment_method": "cash", "delivery_time_note": "Kechqurun"})
preview = answer["data"] if status == 200 else {}
check("The cash preview totals the lines, the fee and the delivery as an estimate",
      status == 200 and preview["merchandise_subtotal_uzs"] == 55200 + 6900 and preview["service_fee_uzs"] == 5000
      and preview["delivery_fee_uzs"] == 15000 and preview["total_uzs"] == 62100 + 20000
      and preview["total_kind"] == "estimate", f"{status} {preview.get('total_uzs')}")
key = str(uuid.uuid4())
status, answer = call("POST", "/customer/orders", customer, {"checkout_token": preview.get("checkout_token")}, key)
check("The Customer orders with cash", status == 201 and answer["data"]["status"] == "new"
      and answer["data"]["can_edit"] is True, f"{status}")
first = answer["data"]
status, answer = call("POST", "/customer/orders", customer, {"checkout_token": preview.get("checkout_token")}, key)
check("A retry of the same order answers the same order", status == 201 and answer["data"]["id"] == first["id"],
      f"{status}")
status, answer = call("GET", "/customer/cart", customer)
check("The cart is empty after the order", status == 200 and answer["data"]["items"] == [], f"{status}")
status, answer = call("GET", "/customer/orders", customer)
check("The order heads the Customer's orders", status == 200 and answer["data"][0]["id"] == first["id"], f"{status}")

status, answer = call("PUT", f"/customer/orders/{first['id']}/items", customer, {
    "items": [{"product_id": tomato, "quantity": "2.500"}], "delivery_time_note": "Kechqurun"})
check("An edit that leaves the order below the minimum is refused",
      status == 409 and code(answer) == "minimum_order_not_reached", f"{status} {code(answer)}")
status, answer = call("PUT", f"/customer/orders/{first['id']}/items", customer, {
    "items": [
        {"product_id": tomato, "quantity": "2.750", "customer_note": None,
         "substitution_policy": "allow_similar_substitution"},
        {"product_id": bread, "quantity": "2", "customer_note": None,
         "substitution_policy": "remove_if_unavailable"},
    ],
    "delivery_time_note": "Ertalab",
})
edited = answer["data"] if status == 200 else {}
open_lines = {i["product_id"]: i for i in edited.get("items", []) if i["status"] != "removed"}
removed = [i for i in edited.get("items", []) if i["status"] == "removed"]
check("The Customer changes a quantity, takes a line out and adds a product",
      status == 200 and set(open_lines) == {tomato, bread} and open_lines[tomato]["quantity"] == "2.750"
      and [i["product_id"] for i in removed] == [apple] and removed[0]["removed_reason_code"] == "customer_removed"
      and edited["delivery_time_note"] == "Ertalab"
      and edited["totals"]["merchandise_subtotal_uzs"] == 50600 + 9200, f"{status} {code(answer)}")

status, answer = call("POST", "/customer/cart/items", customer, {"product_id": apple, "quantity": "20"})
status, answer = call("POST", "/customer/checkout/preview", customer, {
    "address_id": home, "payment_method": "cash", "delivery_time_note": None})
status, answer = call("POST", "/customer/orders", customer, {"checkout_token": answer["data"]["checkout_token"]},
                      str(uuid.uuid4()))
check("The Customer places a second order", status == 201, f"{status}")
second = answer["data"]
cancel_key = str(uuid.uuid4())
status, answer = call("POST", f"/customer/orders/{second['id']}/cancel", customer, {"reason": "Kerak emas"}, cancel_key)
check("The Customer cancels it directly: nothing is due",
      status == 200 and answer["data"]["status"] == "cancelled" and answer["data"]["totals"]["total_kind"] == "none"
      and answer["data"]["totals"]["total_uzs"] is None, f"{status}")
status, answer = call("POST", f"/customer/orders/{second['id']}/cancel", customer, {"reason": "Kerak emas"}, cancel_key)
check("A retry of the cancel answers the cancelled order", status == 200 and answer["data"]["status"] == "cancelled",
      f"{status}")
status, answer = call("PUT", f"/customer/orders/{second['id']}/items", customer, {
    "items": [{"product_id": apple, "quantity": "1"}], "delivery_time_note": None})
check("A cancelled order can no longer be edited", status == 409 and code(answer) == "order_editing_locked",
      f"{status} {code(answer)}")
status, answer = call("GET", "/operations/orders", customer)
check("The Customer cannot reach the board", status == 403, f"{status}")

# --- The Shopper, in Customer mode ----------------------------------------
status, own = customer_sign_in(SHOPPER_PHONE, "Shopper Walkthrough")
check("The Shopper signs in as a Customer with their own phone", status == 200 and own, f"{status}")
own_home = address(own, "9")
call("POST", "/customer/cart/items", own, {"product_id": apple, "quantity": "20"})
status, answer = call("POST", "/customer/checkout/preview", own, {
    "address_id": own_home, "payment_method": "cash", "delivery_time_note": None})
status, answer = call("POST", "/customer/orders", own, {"checkout_token": answer["data"]["checkout_token"]},
                      str(uuid.uuid4()))
check("The Shopper places an order of their own", status == 201, f"{status}")
self_order = answer["data"]

# --- The Operator --------------------------------------------------------
status, answer = staff(OPERATOR_PHONE)
check("The Operator signs in", status == 200 and answer["data"]["user"]["role"] == "operator", f"{status}")
operator = answer["data"]["token"]

status, answer = call("GET", "/operations/orders?per_page=50", operator)
rows = {r["id"]: r for r in answer["data"]} if status == 200 else {}
check("The board lists the three orders, the Customer and the total with its kind",
      all(o["id"] in rows for o in (first, second, self_order))
      and rows[first["id"]]["customer"]["full_name"] == "Aziza Karimova"
      and rows[first["id"]]["total_kind"] == "estimate" and rows[second["id"]]["status"] == "cancelled",
      f"{status}")
status, answer = call("GET", f"/operations/orders?search={first['order_number']}", operator)
check("The board finds an order by its number",
      status == 200 and [r["id"] for r in answer["data"]] == [first["id"]], f"{status}")
status, answer = call("GET", "/operations/orders?status=new&per_page=50", operator)
check("The board filters by status",
      status == 200 and all(r["status"] == "new" for r in answer["data"])
      and second["id"] not in [r["id"] for r in answer["data"]], f"{status}")
status, before = call("GET", "/operations/summary", operator)
check("The summary strip counts open and cancelled orders",
      status == 200 and before["data"]["open_by_status"]["new"] >= 2 and before["data"]["cancelled_today"] >= 1,
      f"{status}")

status, answer = call("GET", "/operations/shoppers?per_page=100", operator)
shoppers = {s["phone"]: s for s in answer["data"]} if status == 200 else {}
check("The Shopper picker lists the active Shoppers", SHOPPER_PHONE in shoppers and second_phone in shoppers,
      f"{status}")
shopper = shoppers[SHOPPER_PHONE]["id"]

status, answer = call("POST", f"/operations/orders/{first['id']}/shopper-assignment", operator, {"shopper_id": shopper})
current = [a for a in answer["data"]["shopper_assignments"] if a["ended_at"] is None] if status == 200 else []
check("The Operator assigns a Shopper", status == 200 and answer["data"]["status"] == "shopping_assigned"
      and len(current) == 1 and current[0]["is_self_order"] is False, f"{status}")
status, answer = call("PUT", f"/operations/orders/{first['id']}/shopper-assignment", operator, {
    "shopper_id": second_shopper, "replaces_assignment_id": current[0]["id"] if current else None})
now = [a for a in answer["data"]["shopper_assignments"] if a["ended_at"] is None] if status == 200 else []
check("The Operator reassigns it to another Shopper",
      status == 200 and len(now) == 1 and now[0]["shopper"]["id"] == second_shopper
      and len(answer["data"]["shopper_assignments"]) == 2, f"{status}")
status, answer = call("PUT", f"/operations/orders/{first['id']}/shopper-assignment", operator, {
    "shopper_id": shopper, "replaces_assignment_id": current[0]["id"] if current else None})
check("A reassignment of an assignment already replaced is refused",
      status == 409 and code(answer) == "order_state_conflict", f"{status} {code(answer)}")
status, answer = call("GET", f"/operations/orders/{first['id']}", operator)
events = [h["event_type"] for h in answer["data"]["history"]] if status == 200 else []
check("The order's history keeps the creation, the edit and both assignments",
      status == 200 and events.count("edited") == 1 and len(answer["data"]["shopper_assignments"]) == 2,
      f"{status} {events}")

status, answer = call("POST", f"/operations/orders/{self_order['id']}/shopper-assignment", operator,
                      {"shopper_id": shopper})
flagged = [a for a in answer["data"]["shopper_assignments"] if a["ended_at"] is None] if status == 200 else []
check("Assigning the Shopper their own order flags it as a self-order",
      status == 200 and flagged and flagged[0]["is_self_order"] is True, f"{status}")
status, answer = call("GET", "/operations/attention", operator)
check("The attention list shows the self-order",
      status == 200 and any(i["type"] == "self_order" and i["order_id"] == self_order["id"] for i in answer["data"]),
      f"{status}")
status, answer = call("GET", "/operations/orders?attention=self_order&per_page=50", operator)
check("The board filters the self-orders",
      status == 200 and self_order["id"] in [r["id"] for r in answer["data"]]
      and all(r["is_self_order"] for r in answer["data"]), f"{status}")
status, after = call("GET", "/operations/summary", operator)
check("The summary strip moves the assigned orders",
      status == 200 and after["data"]["open_by_status"]["new"] == before["data"]["open_by_status"]["new"] - 2
      and after["data"]["open_by_status"]["shopping_assigned"]
      == before["data"]["open_by_status"]["shopping_assigned"] + 2
      and after["data"]["attention_count"] >= 1, f"{status}")

status, answer = call("GET", f"/customer/orders/{first['id']}", customer)
check("The Customer may still edit and cancel before shopping starts",
      status == 200 and answer["data"]["status"] == "shopping_assigned" and answer["data"]["can_edit"] is True
      and answer["data"]["can_cancel_directly"] is True, f"{status}")

for token in (customer, own, operator, admin):
    call("POST", "/auth/logout", token)

passed = sum(1 for _, ok, _ in RESULTS if ok)
print(f"\n{passed} of {len(RESULTS)} steps pass")
sys.exit(0 if passed == len(RESULTS) else 1)
