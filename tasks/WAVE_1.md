# Wave 1 — Catalog and account

Status: **Planned** (2026-09-26). Plan under workflow v6 (`tasks/README.md`). Scope from `DL-5` and `docs/06-roadmap.md` section 3; engineering decisions for the wave in `DL-17`.

## Goal

The business can be set up and the Customer can look at it: Admin enters the business settings, the categories and the products with images in the web panel and manages staff; the Customer browses and searches the catalog at customer prices, keeps a name and a language, and saves delivery addresses inside the service area on a map. Devices can register for push. Nothing is ordered yet; that is Wave 2.

## Owner gate

The Yandex MapKit API key (`docs/06` section 5). Only W1-13 needs it; every other task proceeds without it. If the key is not there when W1-13 starts, the address screens ship with the map picker wired but unverified on a device, and the verification moves to the Wave 1 closure or, failing that, to Wave 2.

## Tasks

| # | Task | Status |
|---|---|---|
| W1-1 | Schema: `customer_addresses`, `categories`, `products`, `product_images`, `business_settings`, `payment_provider_settings`, `push_devices`; models and factories | Planned |
| W1-2 | Pricing core and business settings API: `MoneyCalculator`, `CustomerPriceCalculator`, `ServiceAreaPolicy`, `WorkingHours`; `GET\|PATCH /admin/settings/business`, `GET\|PATCH /admin/settings/payment-providers` | Planned |
| W1-3 | Admin catalog API: categories and products list, create, read, update, archive, restore | Planned |
| W1-4 | Product image API: upload or replace, delete, public URL | Planned |
| W1-5 | Customer catalog API: categories, products with search and pagination, product detail, customer price | Planned |
| W1-6 | Customer profile and addresses API with the service-area check | Planned |
| W1-7 | Staff management API: create with a temporary password, block, activate, reset password | Planned |
| W1-8 | Push device registration API | Planned |
| W1-9 | Panel: business settings and payment providers screen | Planned |
| W1-10 | Panel: categories and products management with image upload | Planned |
| W1-11 | Panel: staff management | Planned |
| W1-12 | App: Customer catalog, search and product screen | Planned |
| W1-13 | App: profile, addresses list and form with the Yandex map picker | Planned, gated |
| W1-14 | App and panel: push token registration behind a token source | Planned |
| W1-15 | Wave closure: full suites, builds, real-stack walkthrough of the wave's scenario, Owner checklist and report | Planned |

Backend tasks first, in order; the panel screens after their APIs; the app screens after theirs; W1-13 last because of the gate.

## Task notes

**W1-1.** Forward migrations for the seven tables exactly as `docs/08` sections 5 to 8, 11, 12 and 25 describe them: UUID keys, `timestamptz`, named checks and partial indexes, `RESTRICT` foreign keys. The `business_settings` migration inserts the singleton row `id = 1` with the non-null defaults (`markup_percent 0`, `service_fee_mode fixed`, `price_tolerance_percent 15`, `delivery_delay_threshold_minutes 60`) and nulls elsewhere; the `payment_provider_settings` migration inserts the four providers disabled. Eloquent models with casts and no mass-assignment surprises, factories for tests. No endpoint. Tests: migrations run and roll back on PostgreSQL, every check and partial unique index refuses what it must.

**W1-2.** `App\Modules\Settings`. `MoneyCalculator::halfUp` on integer UZS with integer arithmetic only (`BR-MONEY-002`); `CustomerPriceCalculator` per `BR-PRICE-001` from a markup given as a decimal string; `ServiceAreaPolicy` with the great-circle distance in kilometres against the configured centre and radius (`BR-AREA-001`), answering the distance and the maximum for the error `details`; `WorkingHours` in `Asia/Tashkent` answering whether an instant is inside the hours and when the business next opens. `GET /admin/settings/business` returns every field of `docs/08` section 11 with nulls for what is unset; `PATCH` takes any subset, validates each field's shape and the service-fee cross-field rule, records `updated_by_user_id`. Payment providers: list and `PATCH .../{provider}` with `is_enabled` only, no secrets anywhere. Admin only (`role:admin`); an Operator gets `403 forbidden`. Tests: rounding at the half, negative and out-of-range values, the cross-field rule, role refusal, the distance at and just beyond the radius.

**W1-3.** `App\Modules\Catalog`. `GET|POST /admin/categories`, `GET|PATCH /admin/categories/{category}`, `POST .../archive`, `.../restore`; the same for products with the write body of `docs/09` section 15. Rules `BR-CAT-001` to `BR-CAT-006` and `BR-QTY-001`'s unit list; `market_price_uzs` a positive integer; archive sets `archived_at` and `is_active = false`, restore clears both; archiving a category does not archive its products and a product may not be created in an archived category. Lists are paginated (`docs/09` section 5), ordered by `sort_order` then `name_uz`, and accept `include_archived`. Admin responses carry `market_price_uzs` and the computed `customer_unit_price_uzs`. Strict request shape. Tests: validation of every field, the unit and price-mode checks, archive and restore round trip, Operator refused, scope-safe `404` for a missing id.

**W1-4.** `POST /admin/products/{product}/image` (multipart `image`, JPEG, PNG or WebP by content, at most 5 MB, `BR-CAT-004`) stores the bytes on the `public` disk under `products/<uuid>.<ext>`, writes the `product_images` row, deletes the previous file after the new row is committed, and answers the product with its new `image_url`; `DELETE` removes the row and the file. The URL is the disk's public URL of the storage key, so it changes with every upload (`docs/07` section 10). Tests with the fake storage: replace, delete, a 6 MB file, a PDF renamed `.jpg`, an archived product still accepts an image.

**W1-5.** `GET /catalog/categories` (active, ordered), `GET /catalog/products?category_id=&search=&page=&per_page=` (active products of active categories, search over `lower(name_uz)` and `lower(name_ru)` with escaped wildcards, ordered by `sort_order` then `name_uz`), `GET /catalog/products/{product}` (an archived or inactive product is a scope-safe `404`). Every product carries `customer_unit_price_uzs` from the current markup and `image_url` or `null`. The `protected` group plus `role:customer` (`DL-17`). Tests: search in either language and case, pagination bounds, inactive products hidden, the price recomputed when the markup changes, a staff token refused.

**W1-6.** `App\Modules\Customer`. `GET|PATCH /customer/profile` (`full_name` 1–120 characters trimmed, `preferred_language`); addresses per `docs/09` section 13 with `ServiceAreaPolicy` on create and update (`422 address_outside_service_area`, `details.max_distance_km`, `details.distance_km`); a missing service-area setting answers `409 checkout_configuration_incomplete`; `DELETE` deactivates (`DL-17`); lists return active addresses only, own only, scope-safe `404` for another Customer's id. Tests: ownership across two Customers, the circle at the edge, coordinate ranges, the deactivated address gone from the list but readable by id nowhere.

**W1-7.** `App\Modules\Staff`. `GET|POST /admin/staff`, `GET|PATCH /admin/staff/{user}` (`full_name`, never `role`), `block`, `activate`, `reset-password` per `docs/09` section 43 and `docs/04` section 32. Create checks the phone family (`409 phone_already_active`), generates a temporary password (`DL-17`), sets the gate, returns the password once in the response and nowhere else. Block: not self (`409 self_block_not_allowed`), not the last active Admin (`409 last_active_admin_required`), deletes every token of the account, sets `blocked_at`. Activate: refused while another active staff account holds the phone. Natural repeats (`docs/09` section 49). Lists paginated, filter by `role` and `status`. Admin only. Tests: every refusal, the token deletion proven by a request with the old token, the password never in logs (the log sink asserted), repeats.

**W1-8.** `App\Modules\Notifications`. `POST /push-devices` `{platform, token}` bound to the calling account: upsert on `(push_token, user_id)`, clears `revoked_at`, sets `last_seen_at`; `DELETE /push-devices/{device}` revokes an own device only (scope-safe `404` otherwise). Any authenticated role. Tests: two accounts registering the same token get two rows, a re-registration is one row, a revoked device can be registered again.

**W1-9.** Panel feature `admin` (`features/admin/`): the settings screen of interview topic 9.0, one form with every business setting, decimal strings sent as the API takes them, money rendered per `docs/07` section 27, the service-fee mode switching its value field, working hours as times, the service area as centre coordinates and radius; the providers as four switches. Errors from `failureText`, field errors from `validation_failed` shown under the fields. Tests: DTOs from the `docs/09` examples, request bodies, the form refusing what the API would refuse, a saved change reflected.

**W1-10.** Panel feature `admin`: categories (list, create, edit, archive, restore) and products (paginated list with search and category filter, create, edit, archive, restore, image upload with a preview and the 5 MB rule checked before sending). Bilingual fields side by side. Tests as W1-9 plus the image picker path with a fake file.

**W1-11.** Panel feature `admin`: staff list with role and status filters, create (shows the temporary password once with a copy button and a warning that it will not be shown again), edit name, block, activate, reset password. Tests: the temporary password shown once and never kept in state after the dialog closes.

**W1-12.** App feature `catalog`: categories, product list with search and infinite pagination, product screen with both names in the interface language, unit, price mode wording ("narx taxminiy" / "цена ориентировочная" for estimates) and the customer price. Stale search results discarded by request generation (`docs/07` section 28). Tests: DTOs, search debouncing not required, pagination end, price mode texts, the stale completion.

**W1-13.** App features `profile` and `addresses`: profile screen (name, language); addresses list, create and edit with the Yandex map picker (a draggable pin on the map, the coordinates read back), the text fields, the service-area refusal shown with the distance from `details`; deactivate with confirmation. The MapKit package is added here with the reason in the commit message and the exact package recorded in the wave file; the key is read from a `--dart-define` and never committed. Tests: everything but the map widget itself, which is verified on the emulator at closure.

**W1-14.** Client feature `notifications`: a `PushTokenSource` port (a fake that yields no token until Wave 4 supplies FCM) and a registrar that registers the token once per signed-in account and revokes it on logout, through the W1-8 API. Tests with a fake source that yields a token.

**W1-15.** Closure per `tasks/README.md` section 4: suites, Pint, PHPStan, analyze, format, web and Android builds; the real stack; the walkthrough — Admin configures settings, creates categories, products and images, creates a Shopper; the Customer sets a name, saves an address inside and one outside the circle, browses and searches at the customer price — on the API, on the emulator and in the panel; the Owner's checklist and report.

## Risks and housekeeping

| Item | Status |
|---|---|
| The Yandex MapKit key is not there yet | Open; W1-13 is last and can close without device verification |
| No product images exist and no brand assets; the panel needs no placeholder art beyond a neutral icon | Accepted |
| The walkthrough seed and API script of Wave 0 are local files; Wave 1's closure commits a seeder guarded to the local environment and a script under `tasks/scripts/` | Planned in W1-15 |
| The frontend CI job is not yet a required check on `main` | Open, Owner |

## Independent-review findings not acted on

None yet.

## Closure

Not yet.
