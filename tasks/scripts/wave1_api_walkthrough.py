"""Wave 1 closure: the API walkthrough against the real stack.

usage: python tasks/scripts/wave1_api_walkthrough.py [base]
       (default http://127.0.0.1:8000/api/v1)

Needs the stack served as `docker/README.md` says, the staff accounts of
`WalkthroughSeeder` and a test phone. The staff password, the test phone and
its code are read from `backend/.env` (`WALKTHROUGH_STAFF_PASSWORD`, the first
of `LOGIN_CODE_TEST_PHONES`, `LOGIN_CODE_TEST_CODE`); variables of the same
names in the environment take precedence. Image URLs are built from
`APP_URL`, which must be `http://localhost:8000` for the run. Rerunning
within a minute waits out the code resend limit.

Admin configures the business, the catalog with an image, and a Shopper;
the Customer keeps a name, saves an address inside and one outside the
service area, and browses and searches at the customer price; devices
register for push. Every step is checked; tokens, codes and passwords are
never printed.
"""

import json
import os
import secrets
import pathlib
import struct
import sys
import time
import urllib.error
import urllib.request
import uuid
import zlib

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
TEST_PHONE = local_setting("LOGIN_CODE_TEST_PHONES").split(",")[0].strip()
TEST_CODE = local_setting("LOGIN_CODE_TEST_CODE")
ADMIN_PHONE = "+998900000005"


def call(method, path, token=None, body=None, raw=None, content_type=None):
    headers = {"Accept": "application/json"}
    data = None
    if token:
        headers["Authorization"] = "Bearer " + token
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if raw is not None:
        data = raw
        headers["Content-Type"] = content_type
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


def png() -> bytes:
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes([200, 60, 40] * 32) for _ in range(32))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 32, 32, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def multipart(field, filename, content, mime):
    boundary = "----bb" + uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field}\"; filename=\"{filename}\"\r\n"
            f"Content-Type: {mime}\r\n\r\n").encode() + content + f"\r\n--{boundary}--\r\n".encode()
    return body, "multipart/form-data; boundary=" + boundary


# --- Admin ---------------------------------------------------------------
status, answer = call("POST", "/auth/staff/login", body={"phone": ADMIN_PHONE, "password": STAFF_PASSWORD})
check("Admin signs in", status == 200 and answer["data"]["user"]["role"] == "admin", f"{status}")
admin = answer["data"]["token"]

settings = {
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
}
status, answer = call("PATCH", "/admin/settings/business", admin, settings)
check("Admin saves the business settings", status == 200 and answer["data"]["service_radius_km"] == "5.00",
      f"{status}")
status, answer = call("PATCH", "/admin/settings/business", admin, {"service_fee_percent": "3.00"})
check("A fee value of the mode not chosen is refused", status == 422, f"{status} {answer and answer.get('code')}")
status, answer = call("PATCH", "/admin/settings/payment-providers/payme", admin, {"is_enabled": True})
check("Admin enables a payment provider", status == 200 and answer["data"]["is_enabled"] is True, f"{status}")
call("PATCH", "/admin/settings/payment-providers/payme", admin, {"is_enabled": False})

stamp = str(int(time.time()))[-5:]
status, answer = call("POST", "/admin/categories", admin, {
    "name_uz": f"Sabzavotlar {stamp}", "name_ru": f"Овощи {stamp}", "sort_order": 1})
check("Admin creates a category", status == 201, f"{status}")
category = answer["data"]["id"]
status, answer = call("POST", "/admin/products", admin, {
    "category_id": category, "name_uz": f"Pomidor {stamp}", "name_ru": f"Помидор {stamp}",
    "unit_code": "kg", "price_mode": "estimate", "market_price_uzs": 16000, "sort_order": 0})
check("Admin creates an estimate product", status == 201 and answer["data"]["customer_unit_price_uzs"] == 18400,
      f"{status} customer price {answer and answer.get('data', {}).get('customer_unit_price_uzs')}")
product = answer["data"]["id"]
status, answer = call("POST", "/admin/products", admin, {
    "category_id": category, "name_uz": f"Olma {stamp}", "name_ru": f"Яблоко {stamp}",
    "unit_code": "piece", "price_mode": "fixed", "market_price_uzs": 3000, "sort_order": 1})
check("Admin creates a fixed product", status == 201 and answer["data"]["customer_unit_price_uzs"] == 3450, f"{status}")
fixed = answer["data"]["id"]

raw, content_type = multipart("image", "pomidor.png", png(), "image/png")
status, answer = call("POST", f"/admin/products/{product}/image", admin, raw=raw, content_type=content_type)
image_url = answer["data"]["image_url"] if status == 200 else None
check("Admin uploads the product image", status == 200 and image_url, f"{status} {image_url}")
if image_url:
    try:
        with urllib.request.urlopen(image_url.replace("localhost", "127.0.0.1"), timeout=30) as response:
            check("The image is served", response.status == 200 and response.read(8) == b"\x89PNG\r\n\x1a\n")
    except OSError as error:
        check("The image is served", False, f"{error}; APP_URL must be http://localhost:8000")
raw, content_type = multipart("image", "fake.png", b"GIF89a....", "image/png")
status, answer = call("POST", f"/admin/products/{product}/image", admin, raw=raw, content_type=content_type)
check("A file that is not an image is refused", status == 422, f"{status}")

status, _ = call("POST", f"/admin/products/{fixed}/archive", admin, {"reason": "x"})
check("A bodyless action refuses a body (DL-31)", status == 422, f"{status}")
status, answer = call("POST", f"/admin/products/{fixed}/archive", admin)
check("Admin archives a product", status == 200 and answer["data"]["archived_at"], f"{status}")
status, answer = call("POST", f"/admin/products/{fixed}/restore", admin)
check("Admin restores it", status == 200 and answer["data"]["archived_at"] is None, f"{status}")

shopper_phone = "+99891" + stamp.rjust(7, "0")
status, answer = call("POST", "/admin/staff", admin, {"full_name": "Aziz Rahimov", "phone": shopper_phone, "role": "shopper"})
check("Admin creates a Shopper with a temporary password",
      status == 201 and answer["data"]["user"]["must_change_password"] is True and answer["data"]["temporary_password"],
      f"{status}")
shopper_id = answer["data"]["user"]["id"]
temporary = answer["data"]["temporary_password"]
new_password = secrets.token_urlsafe(16)
status, answer = call("POST", "/auth/staff/login", body={"phone": shopper_phone, "password": temporary})
check("The Shopper signs in with it and meets the password gate",
      status == 200 and answer["data"]["user"]["must_change_password"] is True, f"{status}")
shopper = answer["data"]["token"]
status, _ = call("POST", "/push-devices", shopper, {"platform": "android", "token": "fcm-shopper"})
check("The gate refuses push registration before the change", status == 403, f"{status}")
status, _ = call("POST", "/auth/change-password", shopper, {
    "current_password": temporary, "new_password": new_password, "new_password_confirmation": new_password})
check("The Shopper changes the password", status in (200, 204), f"{status}")
status, answer = call("POST", "/push-devices", shopper, {"platform": "android", "token": "fcm-shopper"})
check("Past the gate the Shopper's device registers", status == 200, f"{status}")
status, answer = call("POST", "/admin/staff/" + shopper_id + "/reset-password", admin)
check("Admin resets the Shopper's password", status == 200 and answer["data"]["temporary_password"] != temporary, f"{status}")
status, _ = call("GET", "/auth/me", shopper)
check("The reset ended the Shopper's sessions", status == 401, f"{status}")
status, answer = call("POST", "/admin/staff/" + shopper_id + "/block", admin)
check("Admin blocks the Shopper", status == 200 and answer["data"]["status"] == "blocked", f"{status}")
status, answer = call("POST", "/admin/staff/" + shopper_id + "/activate", admin)
check("Admin activates the Shopper", status == 200 and answer["data"]["status"] == "active", f"{status}")
status, answer = call("GET", "/admin/staff?role=shopper", admin)
check("The staff list filters by role", status == 200 and all(m["role"] == "shopper" for m in answer["data"]), f"{status}")

# --- Customer ------------------------------------------------------------
status, answer = call("POST", "/auth/customer/code/request", body={"phone": TEST_PHONE})
if status == 429 or (answer and answer.get("code") == "code_resend_too_soon"):
    time.sleep(61)
    status, answer = call("POST", "/auth/customer/code/request", body={"phone": TEST_PHONE})
check("The Customer asks for a code", status == 200 and answer["data"]["channel"] == "test", f"{status}")
status, answer = call("POST", "/auth/customer/code/verify", body={"phone": TEST_PHONE, "code": TEST_CODE})
check("The Customer signs in", status == 200 and answer["data"]["user"]["role"] == "customer", f"{status}")
customer = answer["data"]["token"]

status, answer = call("PATCH", "/customer/profile", customer, {"full_name": "Aziza Karimova"})
check("The Customer keeps a name", status == 200 and answer["data"]["full_name"] == "Aziza Karimova", f"{status}")
status, answer = call("PATCH", "/auth/me", customer, {"preferred_language": "ru"})
check("The Customer's language is reported", status == 200, f"{status}")

inside = {"latitude": "41.320000", "longitude": "69.250000", "street": "Navoiy", "house": "5A"}
status, answer = call("POST", "/customer/addresses", customer, inside)
check("An address inside the service area is saved", status == 201, f"{status}")
address = answer["data"]["id"]
outside = {"latitude": "41.550000", "longitude": "69.600000", "street": "Chirchiq yo'li", "house": "1"}
status, answer = call("POST", "/customer/addresses", customer, outside)
check("An address outside it is refused with both distances",
      status == 422 and answer["code"] == "address_outside_service_area"
      and answer["details"]["max_distance_km"] and answer["details"]["distance_km"],
      f"{status} {answer and answer.get('details')}")
status, answer = call("PATCH", f"/customer/addresses/{address}", customer, {"house": "7"})
check("An address is edited without moving the pin", status == 200 and answer["data"]["house"] == "7", f"{status}")

status, answer = call("GET", "/catalog/categories?per_page=100", customer)
check("The Customer sees the new section", status == 200 and any(c["id"] == category for c in answer["data"]), f"{status}")
status, answer = call("GET", f"/catalog/products?category_id={category}&page=1&per_page=20", customer)
names = {p["id"]: p for p in answer["data"]} if status == 200 else {}
check("The section lists its products at the customer price",
      status == 200 and names.get(product, {}).get("customer_unit_price_uzs") == 18400
      and "market_price_uzs" not in names.get(product, {}), f"{status}")
status, answer = call("GET", f"/catalog/products?search=pomidor%20{stamp}", customer)
check("A search finds the product", status == 200 and any(p["id"] == product for p in answer["data"]), f"{status}")
status, answer = call("GET", "/catalog/products?search=" + "a" * 101, customer)
check("A search over 100 characters is refused", status == 422, f"{status}")
status, answer = call("GET", f"/catalog/products/{product}", customer)
check("The product shows its image and estimate mode",
      status == 200 and answer["data"]["image_url"] and answer["data"]["price_mode"] == "estimate", f"{status}")
status, answer = call("GET", "/admin/categories", customer)
check("The Customer cannot reach the Admin catalog", status == 403, f"{status}")

status, answer = call("POST", "/push-devices", customer, {"platform": "android", "token": "fcm-walkthrough"})
check("The Customer's device registers for push", status == 200 and "token" not in answer["data"], f"{status}")
device = answer["data"]["id"]
status, _ = call("DELETE", f"/push-devices/{device}", customer)
check("The device is revoked", status == 204, f"{status}")
status, _ = call("DELETE", f"/customer/addresses/{address}", customer)
check("The address is removed", status == 204, f"{status}")

status, _ = call("POST", "/auth/logout", customer)
check("The Customer logs out", status == 204, f"{status}")
status, _ = call("GET", "/auth/me", customer)
check("The token no longer works", status == 401, f"{status}")
call("POST", "/auth/logout", admin)

passed = sum(1 for _, ok, _ in RESULTS if ok)
print(f"\n{passed} of {len(RESULTS)} steps pass")
sys.exit(0 if passed == len(RESULTS) else 1)
