# Wave 1 — Catalog and account

Status: **Planned** (2026-09-26). Plan under workflow v6 (`tasks/README.md`). Scope from `DL-5` and `docs/06-roadmap.md` section 3; engineering decisions for the wave in `DL-17`.

## Goal

The business can be set up and the Customer can look at it: Admin enters the business settings, the categories and the products with images in the web panel and manages staff; the Customer browses and searches the catalog at customer prices, keeps a name and a language, and saves delivery addresses inside the service area on a map. Devices can register for push. Nothing is ordered yet; that is Wave 2.

## Owner gate

The Yandex MapKit API key (`docs/06` section 5). Only W1-13 needs it; every other task proceeds without it. If the key is not there when W1-13 starts, the address screens ship with the map picker wired but unverified on a device, and the verification moves to the Wave 1 closure or, failing that, to Wave 2.

## Tasks

| # | Task | Status |
|---|---|---|
| W1-1 | Schema: `customer_addresses`, `categories`, `products`, `product_images`, `business_settings`, `payment_provider_settings`, `push_devices`; models and factories | Merged |
| W1-2 | Pricing core and business settings API: `MoneyCalculator`, `CustomerPriceCalculator`, `ServiceAreaPolicy`; `GET\|PATCH /admin/settings/business`, `GET\|PATCH /admin/settings/payment-providers` | Merged |
| W1-3 | Admin catalog API: categories and products list, create, read, update, archive, restore | Merged |
| W1-4 | Product image API: upload or replace, delete, public URL | Merged |
| W1-5 | Customer catalog API: categories, products with search and pagination, product detail, customer price | Merged |
| W1-6 | Customer profile and addresses API with the service-area check | Merged |
| W1-7 | Staff management API: create with a temporary password, block, activate, reset password | Merged |
| W1-8 | Push device registration API | In review |
| W1-9 | Panel: business settings and payment providers screen | Planned |
| W1-10 | Panel: categories and products management with image upload | Planned |
| W1-11 | Panel: staff management | Planned |
| W1-12 | App: Customer catalog, search and product screen | Planned |
| W1-13 | App: profile, addresses list and form with the Yandex map picker | Planned, gated |
| W1-14 | App and panel: push token registration behind a token source | Planned |
| W1-15 | Wave closure: full suites, builds, real-stack walkthrough of the wave's scenario, Owner checklist and report | Planned |

Backend tasks first, in order; the panel screens after their APIs; the app screens after theirs; W1-13 last because of the gate. This is a split by layer rather than by vertical slice (`tasks/README.md` section 2), chosen because the panel and the app consume the same APIs and each screen task then tests against a merged contract; the trade-off is that no feature is usable end to end before its screen task lands.

## Task notes

**W1-1.** Forward migrations for the seven tables exactly as `docs/08` sections 5 to 8, 11, 12 and 25 describe them: UUID keys, `timestamptz`, named checks and partial indexes, `RESTRICT` foreign keys. The `business_settings` migration inserts the singleton row `id = 1` with the non-null defaults (`markup_percent 0`, `service_fee_mode fixed`, `price_tolerance_percent 15`, `delivery_delay_threshold_minutes 60`) and nulls elsewhere; its cross-field check is exactly: in `fixed` mode `service_fee_percent` is null, in `percentage` mode `service_fee_fixed_uzs` is null, so the inserted row passes and the value of the inactive mode can never linger. The `payment_provider_settings` migration inserts the four providers disabled. Eloquent models with casts and no mass-assignment surprises, factories for tests. No endpoint. Tests: migrations run and roll back on PostgreSQL; every check, unique constraint and partial index refuses or holds what it must.

**W1-2.** `App\Modules\Settings`. `MoneyCalculator::increaseByPercent` on integer UZS with integer arithmetic only (`BR-MONEY-002`); `CustomerPriceCalculator` per `BR-PRICE-001` from a markup given as a decimal string; `ServiceAreaPolicy` with the great-circle distance in kilometres against the configured centre and radius (`BR-AREA-001`), answering the distance and the maximum for the error `details`. `WorkingHours` belongs to Wave 2, whose checkout is its first consumer. `GET /admin/settings/business` returns every field of `docs/08` section 11 with nulls for what is unset; `PATCH` takes any subset, validates each field's shape and the service-fee cross-field rule (a mode switch must come with the other mode's value cleared), records `updated_by_user_id`. Payment providers: list and `PATCH .../{provider}` with `is_enabled` only, no secrets anywhere; `{provider}` is a route parameter constrained to the four values, and `UuidRouteParameters` with `ProtectedRoutesTest` grow a second kind of admitted parameter, a closed enum, for it (`DL-17` (13)). Admin only (`role:admin`); an Operator gets `403 forbidden`. Tests: rounding at the half, negative and out-of-range values, the cross-field rule, role refusal, the distance at and just beyond the radius, the structural route test still green.

**W1-3.** `App\Modules\Catalog`. `GET|POST /admin/categories`, `GET|PATCH /admin/categories/{category}`, `POST .../archive`, `.../restore`; the same for products with the write body of `docs/09` section 15. Rules `BR-CAT-001` to `BR-CAT-006` and `BR-QTY-001`'s unit list; `market_price_uzs` a positive integer; archive sets `archived_at` and `is_active = false`, restore clears `archived_at` and sets `is_active = true`, and `is_active` in the write body hides a product or category without archiving it; archiving a category does not archive its products and a product may not be created in an archived category. Lists are paginated (`docs/09` section 5), ordered by `sort_order` then `name_uz`, and accept `include_archived`; the product list also accepts `category_id` and `search` (the same search as the Customer catalog), which W1-10 needs. Admin responses carry `market_price_uzs`, the computed `customer_unit_price_uzs` and `archived_at`. `is_active` is outside the models' `$fillable` (`DL-18` (2)): the actions assign it explicitly, and a write that would make an archived entry active is refused with `409 business_conflict` before it reaches the database check. Name lengths: categories 1–120, products 1–160 characters. Strict request shape. Tests: validation of every field, the unit and price-mode checks, archive and restore round trip, Operator refused, scope-safe `404` for a missing id.

**W1-4.** `POST /admin/products/{product}/image` (multipart `image`, JPEG, PNG or WebP by content, at most 5 MB, `BR-CAT-004`) stores the bytes on the `public` disk under `products/<uuid>.<ext>`, writes the `product_images` row, deletes the previous file after the new row is committed, and answers the product with its new `image_url`; `DELETE` removes the row and the file. The URL is the disk's public URL of the storage key, so it changes with every upload (`docs/07` section 10). Tests with the fake storage: replace, delete, a 6 MB file, a PDF renamed `.jpg`, an archived product still accepts an image.

**W1-5.** `GET /catalog/categories` (active, ordered), `GET /catalog/products?category_id=&search=&page=&per_page=` (active products of active categories, search over `lower(name_uz)` and `lower(name_ru)` with escaped wildcards, ordered by `sort_order` then `name_uz`), `GET /catalog/products/{product}` (an archived or inactive product is a scope-safe `404`). Every product carries `customer_unit_price_uzs` from the current markup and `image_url` or `null`. The `protected` group plus `role:customer` (`DL-17`). Tests: search in either language and case, pagination bounds, inactive products hidden, the price recomputed when the markup changes, a staff token refused.

**W1-6.** `App\Modules\Customer`. `GET|PATCH /customer/profile` (`full_name` 1–120 characters trimmed, the same rule as staff names, `preferred_language`); addresses per `docs/09` section 13 with `ServiceAreaPolicy` on create and on an update that moves the point (`DL-23`; `422 address_outside_service_area`, `details.max_distance_km`, `details.distance_km`); a missing service-area setting answers `409 checkout_configuration_incomplete`; `DELETE` deactivates (`DL-17`); lists return active addresses only, own only, scope-safe `404` for another Customer's id. Tests: ownership across two Customers, the circle at the edge, coordinate ranges, the deactivated address gone from the list but readable by id nowhere.

**W1-7.** `App\Modules\Staff`. `GET|POST /admin/staff`, `GET|PATCH /admin/staff/{user}` (`full_name`, never `role`), `block`, `activate`, `reset-password` per `docs/09` section 43 and `docs/04` section 32. Create (`full_name` 1–120 characters) checks the phone family (`409 phone_already_active`), generates a temporary password (`DL-17`), sets the gate, returns the password once in the response and nowhere else. Block: not self (`409 self_block_not_allowed`), not the last active Admin (`409 last_active_admin_required`), deletes every token of the account, sets `blocked_at`. Reset-password: a new temporary password, the gate set, and every token of the account deleted, like block (`DL-17`), so a lost phone cannot keep working on an old session. Activate: refused while another active staff account holds the phone. Natural repeats (`docs/09` section 49). Lists paginated, filter by `role` and `status`. Admin only. Tests: every refusal, the token deletion proven by a request with the old token after block and after reset, the password never in logs (the log sink asserted), repeats.

**W1-8.** `App\Modules\Notifications`. `POST /push-devices` `{platform, token}` bound to the calling account: upsert on `(push_token, user_id)`, clears `revoked_at`, sets `last_seen_at`; `DELETE /push-devices/{device}` revokes an own device only (scope-safe `404` otherwise). Any authenticated role. Tests: two accounts registering the same token get two rows, a re-registration is one row, a revoked device can be registered again.

**W1-9.** Panel feature `admin` (`features/admin/`): the settings screen of interview topic 9.0, one form with every business setting, decimal strings sent as the API takes them, money rendered per `docs/07` section 27, the service-fee mode switching its value field, working hours as times, the service area as centre coordinates and radius; the providers as four switches. Errors from `failureText`, field errors from `validation_failed` shown under the fields. Tests: DTOs from the `docs/09` examples, request bodies, the form refusing what the API would refuse, a saved change reflected.

**W1-10.** Panel feature `admin`: categories (list, create, edit, archive, restore) and products (paginated list with search and category filter, create, edit, archive, restore, image upload with a preview and the 5 MB rule checked before sending). Bilingual fields side by side. Tests as W1-9 plus the image picker path with a fake file.

**W1-11.** Panel feature `admin`: staff list with role and status filters, create (shows the temporary password once with a copy button and a warning that it will not be shown again), edit name, block, activate, reset password. Tests: the temporary password shown once and never kept in state after the dialog closes.

**W1-12.** App feature `catalog`: categories (fetched once with `per_page=100`, `DL-22` (4)), product list with search and infinite pagination, product screen with both names in the interface language, unit, price mode wording ("narx taxminiy" / "цена ориентировочная" for estimates) and the customer price. Stale search results discarded by request generation (`docs/07` section 28). Tests: DTOs, pagination end, price mode texts, the stale completion.

**W1-13.** App features `profile` and `addresses`: profile screen (name, language); addresses list, create and edit with the Yandex map picker (a draggable pin on the map, the coordinates read back), the text fields, the service-area refusal shown with the distance from `details`; deactivate with confirmation. The MapKit package is added here with the reason in the commit message and the exact package recorded in the wave file; the key is read from a `--dart-define` and never committed. Tests: everything but the map widget itself, which is verified on the emulator at closure.

**W1-14.** Client feature `notifications`: a `PushTokenSource` port (a fake that yields no token until Wave 4 supplies FCM) and a registrar that registers the token once per signed-in account and revokes it on logout, through the W1-8 API — the revoke goes before `POST /auth/logout`, while the session still works, and a staff member registers only after the first-login password change, since the gate refuses it before. Tests with a fake source that yields a token.

**W1-15.** Closure per `tasks/README.md` section 4: suites, Pint, PHPStan, analyze, format, web and Android builds; the real stack; the walkthrough — Admin configures settings, creates categories, products and images, creates a Shopper; the Customer sets a name, saves an address inside and one outside the circle, browses and searches at the customer price — on the API, on the emulator and in the panel; the Owner's checklist and report.

## Risks and housekeeping

| Item | Status |
|---|---|
| The Yandex MapKit key is not there yet | Open; W1-13 is last and can close without device verification |
| The MapKit package has no web implementation while the frontend CI job builds the web panel on every pull request | W1-13 must keep `flutter build web` green: the map widget is imported only by the mobile-only `addresses` feature, and the package chosen must take the key from Dart (`--dart-define`), not from committed native files |
| A body the JSON decoder cannot read reaches every endpoint as an empty body: a POST fails its required fields and every PATCH refuses an empty body with `422`, but no endpoint answers the `400 malformed_request` of `docs/09` section 3. A string with an interior NUL byte is silently cut at the NUL by the input handling | Closed by one global middleware (`DL-24`) |
| A device stays live when a session ends on the server — the 30-day idle expiry, or a logout whose revoke failed — and an account may register any number of devices (found by the W1-8 review) | Open for Wave 4, before the first push: prune devices unseen for longer than the token lifetime (the app re-registering at every start), and cap live devices per account |
| Bodyless actions — archive, restore, block, activate, reset-password, logout, address and push-device delete — take a plain request and ignore a body, where `docs/09` section 4 says unknown fields are refused (found by the W1-7 review) | Open; one shared empty strict request for all of them in one small pull request before the wave closes |
| Paynet and xazna have rows and switches but no adapter before Wave 5; enabling one would satisfy `BR-CHK-004` with a provider that cannot take a payment | Wave 5 decides "enabled" as "enabled and an adapter is registered"; until then online payment is shown as unavailable anyway (Wave 2) |
| No product images exist and no brand assets; the panel needs no placeholder art beyond a neutral icon | Accepted |
| The walkthrough seed and API script of Wave 0 are local files; Wave 1's closure commits a seeder guarded to the local environment and a script under `tasks/scripts/` | Planned in W1-15 |
| The frontend CI job is not yet a required check on `main` | Open, Owner |

## Independent-review findings not acted on

None yet.

## Closure

Not yet.
