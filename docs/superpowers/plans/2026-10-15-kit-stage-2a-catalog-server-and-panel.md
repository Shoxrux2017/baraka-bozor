# Kit Stage 2a — Catalog Server and Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The server and the web panel give the kit home (stage 2b) everything it needs, as the Owner decided on 2026-10-15: every product's price is an estimate; a category has a picture the Admin uploads; the Admin marks products for "Рекомендуем"; the Customer can sort products by price; the Customer keeps favourite products on the server.

**Architecture:** Catalog module: `products.price_mode` is pinned to `estimate` by a migration and a database check, the Admin write body loses `price_mode` (the strict request shape then refuses it); `category_images` mirrors `product_images` with its own replace/remove actions; `products.is_featured` plus the Customer list's `featured` and `sort` filters. Customer module: `customer_favorites` with `GET /customer/favorites`, `PUT|DELETE /customer/favorites/{product}`, and `is_favorite` on every Customer catalog product. Orders keep their `fixed` lines for orders placed before the change; no Orders code changes. Panel: the product form loses the price-mode selector and gains the "Рекомендуем" switch; the category dialog gains the picture card extracted from the product form.

**Tech Stack:** Laravel 13 + PostgreSQL 17 (Sanctum), Flutter 3.47.5 + Riverpod 3 + go_router, `flutter gen-l10n` (template `app_uz.arb`).

**Spec:** Claude Design project "BarakaBozor — стиль покупателя", file `kit/02-glavnaya.dc.html`, approved by the Owner 2026-10-15 (screens 10, 10а–10г, 11–14, 14а–14б), and the Owner's answers of 2026-10-15 recorded in Task 1 as `DL-78`. Stage 2b (`2026-10-15-kit-stage-2b-customer-home.md`) builds the Customer screens on this API.

## Global Constraints

- Branch `task/kit-2a-catalog-server` from `main` 6230868. Never commit to `main`.
- Backend commands run in Docker from the repo root: `docker compose -f docker/compose.yaml exec -T app <cmd>` (`php artisan test --filter=…`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse`). Flutter: `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`.
- Migrations: `backend/database/migrations/2026_10_15_00000N_<snake>.php`, N = 2…5 in task order, anonymous class, checks and partial indexes by `DB::statement` through a private `check()` helper as `2026_09_26_000004_create_product_images_table.php` does; uuid primary keys; `timestampTz`.
- Security (AGENTS.md §5): Customer routes sit in the `AuthServiceProvider::PROTECTED` + `RequireRole::of(Role::Customer)` group, Admin routes in the Admin group; a record the actor may not see answers the scope-safe `404 resource_not_found` (`ScopedLookup::firstOrNotFound`); a valid UUID never grants access; nothing new is logged.
- Strict request shape (`docs/09` §4): unknown body fields are `422 validation_failed`; a route that takes no body refuses any field.
- Historical integrity (AGENTS.md §6): `order_items.price_mode_snapshot` keeps `fixed` for lines already placed; `PriceMode::Fixed` and every Orders branch on it stay; no Orders file changes.
- No new Composer or pub package; `pubspec.lock` and `composer.lock` unchanged. Generated l10n files are regenerated with `flutter gen-l10n`, never hand-edited. Texts: Uzbek (template, ASCII apostrophe as the ARB files use) and Russian.
- Each decision the agent takes is an item of `DL-79` in `docs/DECISIONS.md`, written in the same task as its code, and the affected `docs/01–09` section is updated in that task (AGENTS.md §3).
- New `docs/08` table sections are appended after section 30 (31 `category_images`, 32 `customer_favorites`) so existing section numbers stay; the new `docs/09` section is 58 under a new heading `# Favourites`.
- Never delete, skip or weaken a test; a test whose flow changed is rewritten to assert the new flow.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- Favourites scope: Customer B can neither list, add to, nor remove from Customer A's favourites; `PUT` on an inactive, archived, hidden-category or unknown product is the same `404`; `DELETE` answers `204` whatever the product, so it reveals nothing; a Shopper token is `403`, a blocked Customer `401 account_blocked`.
- Fixed lines from before the change: an order placed with a `fixed` line keeps its fixed price through purchase, approvals, replacement ceiling, totals and price correction (the rewritten Orders tests must still assert these), while every new cart, preview and order is an estimate.
- Price sort across pages: with equal prices and `per_page` smaller than the list, pages 1 and 2 together hold every product exactly once in non-decreasing (or non-increasing) customer price.
- Picture files: replacing a category picture deletes the old file only after the commit, a failed replace leaves no stray file, and an archived category still takes a picture; the Customer sees `image_url` only for listed categories.
- Panel edit of an old product: an edit never sends `price_mode` (the server would refuse it), and a change of only "Рекомендуем" sends only `is_featured`.

---

### Task 1: Every product is an estimate (the Owner's `DL-78`)

**Files:**
- Create: `backend/database/migrations/2026_10_15_000002_make_every_product_an_estimate.php`
- Modify: `backend/app/Models/Product.php` (drop `price_mode` from `$fillable`, keep the cast), `backend/app/Modules/Catalog/Http/Requests/ProductRequest.php` (drop the `price_mode` rule), `backend/app/Modules/Catalog/Actions/SaveCatalogEntry.php` (a created product gets `price_mode = PriceMode::Estimate`), `backend/database/factories/ProductFactory.php` (remove `fixed()`), `backend/database/factories/OrderItemFactory.php` (add `fixed()`), `tasks/scripts/wave1_api_walkthrough.py` (lines 177–205: no `price_mode` in the bodies; the second product is an estimate piece product, its check reads "Admin creates a second product")
- Modify docs: `docs/DECISIONS.md` (new `DL-78`, new `DL-79` item 1), `docs/01-business-overview.md` §8 (lines 84–85, 113), `docs/03-features.md` §5–6 (lines 35, 39, 51) and §23 (line 114), `docs/04-user-flows.md` §13 and line 66, `docs/05-business-rules.md` BR-PRICE-002/003, `docs/08-database.md` §7, `docs/09-api-contracts.md` §15, `tasks/REDESIGN_CUSTOMER.md` (stage 1 "Merged (PR #88)", stage 2 "In Progress (2a server and panel, 2b screens)")
- Test: Modify `backend/tests/Feature/Catalog/AdminProductsApiTest.php`, `backend/tests/Feature/Catalog/CustomerCatalogApiTest.php:49`, `backend/tests/Feature/Schema/ProductsTableTest.php`, and every `Product::factory()->fixed()` site: `tests/Feature/Orders/CheckoutPreviewApiTest.php:60`, `CreateOrderApiTest.php:77`, `EditAndCancelOrderApiTest.php:58`, `CompleteShoppingApiTest.php:300`, `PriceCorrectionApiTest.php:251`, `RecordPurchaseApiTest.php:359`, `ShopperOrdersApiTest.php:95`, `ShopperQuestionsApiTest.php:92,260`, `tests/Feature/Schema/Wave1ModelsAndFactoriesTest.php:54`, `Wave2ModelsAndFactoriesTest.php:111`

**Interfaces:**
- Produces (API): Admin `POST|PATCH /admin/products` body without `price_mode`; sending it is `422 validation_failed` with an error on `price_mode`. Every product response (Admin and Customer) still carries `"price_mode":"estimate"`.
- Produces (test support): `OrderItemFactory::fixed(): self` — a line placed before `DL-78`: `price_mode_snapshot = PriceMode::Fixed`, everything else as the definition. Use as `OrderItem::factory()->fixed()->for($order)->for(Product::factory()->unit(UnitCode::Piece)->state(['market_price_uzs' => 3000]))`.

- [ ] **Step 1: Record the Owner's decisions.** Append to `docs/DECISIONS.md` after `DL-77`:

```markdown
## DL-78 — The kit home, every price an estimate (2026-10-15, Owner)

Answers to the questions of kit stage 2 (`kit/02-glavnaya.dc.html`, approved the same day).

1. **The home.** From the top: the delivery address and the cart with its count; the search and the filter button; the categories four in a row, the first eight, with "Все" opening every category; the "Рекомендуем" row. No banner.
2. **"Рекомендуем".** The Admin marks a product "show on the home" in the panel. The row lists the marked products and hides when none is marked; "Все" opens the full list. There are no discounts and no struck-out prices (`docs/08` section 30 stands).
3. **Every price is an estimate.** The Admin no longer chooses a price mode; every product, existing ones included, is an estimate, and the Admin can change its market price at any time. The Customer pays after shopping, at the price the Shopper paid plus the markup, with the tolerance approval as before. This supersedes interview 2.2's two modes; lines of orders placed before this decision keep their `fixed` price. In Wave 4 the Customer is notified of the final amount for a cash order too, as `payment_required` does for an online one.
4. **Category pictures.** The Admin uploads a picture per category, under the rules of the product image. Without one the tile shows the first letter of the name.
5. **Favourites.** A heart on every product card keeps the product in the Customer's favourites, stored with the account on the server; the "Избранное" screen lists them, and one no longer sold stays, greyed, as "Нет в продаже".
6. **The bottom bar.** Главная, Избранное, Заказы, Профиль. The cart stays at the top right with its count. No dot on Заказы. This supersedes `DL-75` item 4 on the bar's items.
7. **The filter button** opens a sort: "Как в магазине", "Сначала дешевле", "Сначала дороже", over every product or the search results.
```

and start `DL-79` (agent) with item 1:

```markdown
## DL-79 — Catalog server and panel for the kit home, kit stage 2a (2026-10-15, agent)

1. **How "every price an estimate" is enforced.** A migration sets every product to `estimate` and narrows `products_price_mode_check` to `price_mode = 'estimate'`; the Admin write body loses `price_mode`, so the strict request shape refuses it; a created product is an estimate. `price_mode` stays in product responses (always `estimate`) so clients keep one shape. `PriceMode::Fixed`, `order_items.price_mode_snapshot` and every Orders branch on a fixed line stay for lines placed before `DL-78`; the checkout's `final` total kind no longer occurs for a new cart. Tests of fixed lines build them with `OrderItemFactory::fixed()`, a line placed before the decision.
```

- [ ] **Step 2: Write the failing tests.**
  1. `ProductsTableTest`: inserting a product row with `price_mode = 'fixed'` raises a `QueryException` naming `products_price_mode_check`; `'estimate'` inserts.
  2. `AdminProductsApiTest`: `POST /admin/products` with a full valid body and `"price_mode":"fixed"` → `422`, `code = validation_failed`, `errors.price_mode` present; the same with `"estimate"` → `422` too (the field is gone, not narrowed); the body without `price_mode` → `201`, `data.price_mode = "estimate"`; `PATCH` with only `{"price_mode":"estimate"}` → `422`.
  3. Rewrite every `Product::factory()->fixed()` site (the list in **Files**):
     - lines that test fixed-line behaviour (`CompleteShopping…:300`, `PriceCorrection…:251`, `RecordPurchase…:359`, `ShopperOrders…:95`, `ShopperQuestions…:92,260`, `EditAndCancel…:58` and its `breadLine`, `Wave2…:111`) become `OrderItem::factory()->fixed()->for(…)->for(Product::factory()->…)` with the same product state, and keep every assertion (the fixed price, `BR-PRICE-005`'s ceiling, `approval_not_needed`, `PriceMode::Fixed` on the snapshot);
     - `CheckoutPreviewApiTest:60` and `CreateOrderApiTest:77`: the bread product is an estimate piece product now; an assertion that relied on bread being fixed (a `fixed` snapshot, a `final` total kind, a fixed line amount) is rewritten to the new flow — the line snapshots `estimate`, the preview's `total_kind` is `estimate` — and the test name says so (e.g. `…_every_new_line_is_an_estimate`);
     - `CustomerCatalogApiTest:49` drops `->fixed()` and asserts `price_mode = "estimate"`;
     - `Wave1ModelsAndFactoriesTest:54` becomes an archived box product asserting `PriceMode::Estimate`.
  Run: `docker compose -f docker/compose.yaml exec -T app php artisan test --filter='ProductsTableTest|AdminProductsApiTest'` — expect the new cases to FAIL; the rewritten Orders tests fail with "Call to undefined method …fixed()" on `OrderItemFactory` until Step 3.

- [ ] **Step 3: Implement.**

Migration:

```php
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("update products set price_mode = 'estimate', updated_at = now() where price_mode <> 'estimate'");
        DB::statement('alter table products drop constraint products_price_mode_check');
        DB::statement("alter table products add constraint products_price_mode_check check (price_mode = 'estimate')");
    }

    public function down(): void
    {
        DB::statement('alter table products drop constraint products_price_mode_check');
        DB::statement("alter table products add constraint products_price_mode_check check (price_mode in ('fixed', 'estimate'))");
    }
};
```

`SaveCatalogEntry`: where a product is created, set `$product->price_mode = PriceMode::Estimate;` before save (it is no longer mass-assignable). `ProductRequest`: delete the `price_mode` rule line and its import if unused. `OrderItemFactory`:

```php
    /**
     * A line placed before every product became an estimate (DL-78): its
     * customer price was guaranteed.
     */
    public function fixed(): self
    {
        return $this->state(fn (): array => ['price_mode_snapshot' => PriceMode::Fixed]);
    }
```

- [ ] **Step 4: Run** the Catalog, Orders and Schema suites: `php artisan test --filter='Catalog|Orders|Schema'` — all PASS. Then `vendor/bin/pint --test` and `vendor/bin/phpstan analyse`.

- [ ] **Step 5: Docs.** Update the sections listed in **Files**: `docs/01` §8 says every product is an estimate since `DL-78` and `fixed` survives on lines placed before it; `docs/03` line 35 drops "price mode" from what the Admin manages, line 39 says every product is an estimate, line 51 notes a new order's total is always `estimate`, §23 adds to the Customer events "and, for a cash order, the final amount at shopping completion (`DL-78`, Wave 4)"; `docs/04` §13 starts "A line placed before `DL-78`…", line 66 notes `final` no longer occurs for a new cart; `docs/05` BR-PRICE-002 gains "(lines placed before `DL-78`)" and BR-PRICE-003 starts "Every product is an estimate (`DL-78`)"; `docs/08` §7 check reads `price_mode = 'estimate'`; `docs/09` §15 write body drops `price_mode`. Update `tasks/REDESIGN_CUSTOMER.md` as listed. Run `python tasks/scripts/wave1_api_walkthrough.py --help` only if the script has a dry mode; otherwise check it parses: `python -m py_compile tasks/scripts/wave1_api_walkthrough.py`.

- [ ] **Step 6: Commit** — `feat(catalog): every product is an estimate (DL-78)`.

---

### Task 2: Category pictures (server)

**Files:**
- Create: `backend/database/migrations/2026_10_15_000003_create_category_images_table.php`, `backend/app/Models/CategoryImage.php`, `backend/database/factories/CategoryImageFactory.php`, `backend/app/Modules/Catalog/CategoryImages.php`, `backend/app/Modules/Catalog/Actions/ReplaceCategoryImage.php`, `backend/app/Modules/Catalog/Actions/RemoveCategoryImage.php`, `backend/app/Modules/Catalog/Http/Controllers/AdminCategoryImageController.php`
- Rename: `backend/app/Modules/Catalog/Http/Requests/ProductImageRequest.php` → `CatalogImageRequest.php` (class `CatalogImageRequest`, same rules), used by both image controllers
- Modify: `backend/app/Models/Category.php` (`image(): HasOne`), `backend/routes/api/v1/catalog.php` (admin group), `backend/app/Modules/Catalog/Http/Resources/AdminCategoryResource.php` and `CustomerCategoryResource.php` (`image_url`), `backend/app/Modules/Catalog/AdminCatalogListing.php` and `CustomerCatalogListing::categories()` (`->with('image')`), `backend/app/Modules/Catalog/Http/Controllers/AdminProductImageController.php` (request rename)
- Modify docs: `DL-79` item 2, `docs/05` BR-CAT-004, `docs/08` §2 Table Map + new §31, `docs/09` §14, §15, §16 (retitled "Product and Category Images")
- Test: Create `backend/tests/Feature/Catalog/AdminCategoryImageApiTest.php`, `backend/tests/Feature/Schema/CategoryImagesTableTest.php`; modify `CustomerCatalogApiTest.php`, `AdminCategoriesApiTest.php`

**Interfaces:**
- Produces (API): `POST /admin/categories/{category}/image` (multipart field `image`) and `DELETE /admin/categories/{category}/image` → `200` with the Admin category; Admin and Customer category objects gain `"image_url": null | "https://…/storage/categories/<uuid>.<ext>"`.
- Produces (PHP): `CategoryImages::DIR = 'categories'`, `CategoryImages::url(?CategoryImage): ?string`; `Category::image(): HasOne<CategoryImage>`.

- [ ] **Step 1: Write the failing tests.** `AdminCategoryImageApiTest` mirrors `AdminProductImageApiTest` case by case (copy its `Storage::fake('public')` setup, `ImageBytes` helpers and `upload()` helper, pointing at `/api/v1/admin/categories/{id}/image`):
  1. JPEG, PNG and WebP each upload → `200`, `data.image_url` ends with `/storage/categories/<uuid>.<jpg|png|webp>`, the file exists on the fake disk, one `category_images` row.
  2. A PNG named `photo.jpg` is stored as `.png` (bytes decide); a text file named `x.png` → `422`; a file of 5 MiB + 1 byte → `422`; exactly 5 MiB → `200`.
  3. A second upload changes `image_url`, the old file is gone after the request, still one row.
  4. `DELETE` → `200`, `image_url` null, file gone; a second `DELETE` → `200` (natural repeat).
  5. A field named other than `image` → `422 validation_failed`; no file → `422`.
  6. An archived category accepts a picture.
  7. Unknown category UUID → `404 resource_not_found`; a Customer token → `403`; no token → `401`.
  8. When the row write fails after the file was written (simulate as the product test does, e.g. by a unique-violation stub if it has one; otherwise skip this single case and say so in the report), the new file is deleted.
  `CategoryImagesTableTest`: size and MIME checks refuse bad metadata; `category_id` is unique. `CustomerCatalogApiTest`: a listed category carries `image_url` (null, then a URL after a `CategoryImage::factory()` row); the key list assertion includes `image_url`. `AdminCategoriesApiTest`: the Admin category carries `image_url`.
  Run `php artisan test --filter='CategoryImage|CustomerCatalogApiTest|AdminCategoriesApiTest'` — expect FAIL.

- [ ] **Step 2: Implement.** Migration: copy `2026_09_26_000004_create_product_images_table.php` with `category_images`, `category_id` (unique, FK `categories` restrict on delete), checks `category_images_size_bytes_check` and `category_images_mime_type_check`. Model `CategoryImage` and its factory: copy `ProductImage` and `ProductImageFactory` with `category_id`. `CategoryImages`:

```php
final class CategoryImages
{
    public const DIR = 'categories';

    public static function url(?CategoryImage $image): ?string
    {
        return $image === null ? null : Storage::disk(ProductImages::DISK)->url($image->storage_key);
    }
}
```

`ReplaceCategoryImage` / `RemoveCategoryImage`: copy `ReplaceProductImage` / `RemoveProductImage` line for line, with the category row locked first, then its image row, key `categories/<uuid4>.<ext>` from `ProductImages::EXTENSIONS`, the same after-commit delete of the old key and the same cleanup of the new key on failure. Controller: `store(CatalogImageRequest $request, string $category)` and `destroy(string $category)` resolve the category with `ScopedLookup::firstOrNotFound(Category::query()->whereKey($category))` and answer `new AdminCategoryResource($category->fresh('image'))`. Routes in the Admin group next to the product image routes:

```php
Route::post('categories/{category}/image', [AdminCategoryImageController::class, 'store']);
Route::delete('categories/{category}/image', [AdminCategoryImageController::class, 'destroy']);
```

Resources add `'image_url' => CategoryImages::url($this->resource->image)`; listings eager-load `image`.

- [ ] **Step 3: Run** the filter of Step 1 plus `AdminProductImageApiTest` (the request rename) — PASS; pint and phpstan.

- [ ] **Step 4: Docs.** `DL-79` item 2: "**Category pictures** mirror product images: `category_images`, one per category, the same formats and size, a fresh key per upload under `categories/`, replace and remove serialized on the category row, the old file deleted after commit. The request class is shared (`CatalogImageRequest`). The Customer's category carries `image_url`; the letter shown without a picture is the client's." `docs/05` BR-CAT-004 → "One current image per product and per category; …". `docs/08`: Table Map gains `category_images`; §31 `category_images` (migrated) with the columns and checks. `docs/09` §14 category fields gain `image_url`; §15 Admin category responses carry `image_url`; §16 retitled "Product and Category Images" with a sentence: "`POST|DELETE /admin/categories/{category}/image` work the same way for a category's picture and answer the Admin category."

- [ ] **Step 5: Commit** — `feat(catalog): category pictures`.

---

### Task 3: "Рекомендуем" and the price sort (server)

**Files:**
- Create: `backend/database/migrations/2026_10_15_000004_add_is_featured_to_products.php`, `backend/app/Modules/Catalog/ProductSort.php`
- Modify: `backend/app/Models/Product.php` (`is_featured` fillable, cast bool), `backend/app/Modules/Catalog/Http/Requests/ProductRequest.php`, `backend/app/Modules/Catalog/Http/Resources/AdminProductResource.php`, `backend/app/Modules/Catalog/Http/Requests/ListCustomerProductsRequest.php`, `backend/app/Modules/Catalog/CustomerCatalogListing.php` (`products()`), `backend/app/Modules/Catalog/Http/Controllers/CustomerCatalogController.php`, `backend/database/factories/ProductFactory.php` (`featured()` state)
- Modify docs: `DL-79` items 3–4, `docs/03` §5, `docs/08` §7, `docs/09` §14–15
- Test: `backend/tests/Feature/Catalog/CustomerCatalogApiTest.php`, `AdminProductsApiTest.php`, `backend/tests/Feature/Schema/ProductsTableTest.php`

**Interfaces:**
- Produces (API): `GET /catalog/products?featured=1&sort=price_asc|price_desc|default&category_id=&search=&page=&per_page=`; `featured` takes `1|0|true|false`; an unknown `sort` is `422 validation_failed`. Admin product body and responses gain `is_featured` (boolean, default `false`).
- Produces (PHP): `enum ProductSort: string { case Default = 'default'; case PriceAsc = 'price_asc'; case PriceDesc = 'price_desc'; }`; `CustomerCatalogListing::products(?string $categoryId, ?string $search, bool $featuredOnly = false, ProductSort $sort = ProductSort::Default): Builder<Product>`.

- [ ] **Step 1: Write the failing tests.** `CustomerCatalogApiTest`:
  1. `featured=1` lists only featured visible products; a featured archived product, a featured inactive one and one in an archived category are absent; `featured=0` and no `featured` list all visible products.
  2. `sort=price_asc` with market prices 9000, 5000, 7000, 5000 lists 5000, 5000, 7000, 9000, the two 5000s in `sort_order`, `name_uz`, `id` order; `price_desc` the reverse by price with the same tie order; `default` (and absent) keeps `sort_order`, `name_uz`, `id`.
  3. With `per_page=2`, `sort=price_asc`: pages 1 and 2 together list every product exactly once, prices non-decreasing.
  4. `sort` composes with `category_id`, `search` and `featured`.
  5. `sort=cheap` → `422`; `featured=yes` → `422`.
  `AdminProductsApiTest`: create without `is_featured` → `false`; create and patch with `true` → `true`; `"is_featured":"1"` → `422` (strict boolean). `ProductsTableTest`: the column exists, not null, default false.
  Run `php artisan test --filter='CustomerCatalogApiTest|AdminProductsApiTest|ProductsTableTest'` — expect FAIL.

- [ ] **Step 2: Implement.** Migration:

```php
Schema::table('products', function (Blueprint $table): void {
    $table->boolean('is_featured')->default(false);
});
DB::statement('create index products_featured_idx on products (sort_order, name_uz, id) where is_featured');
```

(`down` drops the index and the column.) `ProductRequest` adds `'is_featured' => ['sometimes', 'required', 'boolean:strict']`. `AdminProductResource` adds `'is_featured' => $product->is_featured`. `ListCustomerProductsRequest::filters()` adds `'featured' => ['sometimes', 'boolean']` and `'sort' => ['sometimes', Rule::enum(ProductSort::class)]`, with `featuredOnly(): bool` (`$this->boolean('featured')`) and `sort(): ProductSort` (`ProductSort::tryFrom((string) $this->query('sort', 'default')) ?? ProductSort::Default`). `CustomerCatalogListing::products()`:

```php
public static function products(?string $categoryId, ?string $search, bool $featuredOnly = false, ProductSort $sort = ProductSort::Default): Builder
{
    $query = CatalogSearch::matching(self::visibleProducts(), $search);

    if ($categoryId !== null) {
        $query->where($query->qualifyColumn('category_id'), $categoryId);
    }

    if ($featuredOnly) {
        $query->where($query->qualifyColumn('is_featured'), true);
    }

    // One markup applies to every product, so the market price orders the
    // customer prices too; ties keep the shop's order, which ends in `id`,
    // so pages never repeat or skip a product.
    match ($sort) {
        ProductSort::PriceAsc => $query->orderBy($query->qualifyColumn('market_price_uzs')),
        ProductSort::PriceDesc => $query->orderByDesc($query->qualifyColumn('market_price_uzs')),
        ProductSort::Default => null,
    };

    return CatalogSearch::ordered($query);
}
```

The controller passes `$request->featuredOnly()` and `$request->sort()`. `ProductFactory::featured()` sets `is_featured = true`.

- [ ] **Step 3: Run** the Step 1 filter and `CartApiTest` (it uses `visibleProducts()`) — PASS; pint, phpstan.

- [ ] **Step 4: Docs.** `DL-79` item 3: "**"Рекомендуем"** is `products.is_featured`, set by the Admin; the Customer list takes `featured`. A partial index serves the home row." Item 4: "**The price sort** orders by `market_price_uzs`, which orders customer prices because one markup applies to all, then by the shop's order ending in `id`, so paging is stable. Popularity is not offered: no figures exist before the pilot (`docs/05` section 20)." `docs/03` §5: the Admin marks products for "Рекомендуем"; Customers list the marked products and sort any list by price. `docs/08` §7: `is_featured` and the index. `docs/09` §14: the two parameters and their answers; §15: `is_featured` in the body and responses.

- [ ] **Step 5: Commit** — `feat(catalog): recommended products and the price sort`.

---

### Task 4: Favourites (server)

**Files:**
- Create: `backend/database/migrations/2026_10_15_000005_create_customer_favorites_table.php`, `backend/app/Models/CustomerFavorite.php`, `backend/database/factories/CustomerFavoriteFactory.php`, `backend/app/Modules/Customer/CustomerFavorites.php`, `backend/app/Modules/Customer/Actions/ChangeFavorites.php`, `backend/app/Modules/Customer/Http/Controllers/FavoriteController.php`, `backend/app/Modules/Customer/Http/Requests/ListFavoritesRequest.php`, `backend/app/Modules/Customer/Http/Resources/FavoriteProductResource.php`
- Modify: `backend/routes/api/v1/customer.php`, `backend/app/Models/Product.php` (`favorites(): HasMany`), `backend/app/Modules/Catalog/Http/Resources/CustomerProductResource.php` (`is_favorite`), `backend/app/Modules/Catalog/Http/Controllers/CustomerCatalogController.php` (list and detail add the `is_favorite` flag for the session's Customer)
- Modify docs: `DL-79` items 5–6, `docs/03` §5, `docs/05` new BR-CAT-007, `docs/08` §2 + new §32, `docs/09` §14 and new §58 under `# Favourites`
- Test: Create `backend/tests/Feature/Customer/FavoritesApiTest.php`, `backend/tests/Feature/Schema/CustomerFavoritesTableTest.php`; modify `backend/tests/Feature/Catalog/CustomerCatalogApiTest.php`

**Interfaces:**
- Produces (API):
  - `GET /customer/favorites?page=&per_page=` → paginated (`docs/09` §2), newest first; each entry is a Customer product object plus `"is_available": bool` (`false` when the product or its category is inactive or archived); `is_favorite` is `true`.
  - `PUT /customer/favorites/{product}` (no body) → `204`; repeat → `204`; a product not listed for Customers or unknown → `404 resource_not_found`; the 501st → `409 favorites_full` with `details.limit = 500`.
  - `DELETE /customer/favorites/{product}` (no body) → `204` always.
  - Every Customer catalog product (`GET /catalog/products`, `GET /catalog/products/{product}`) gains `"is_favorite": bool` for the session's Customer.
- Produces (PHP): `CustomerFavorites::own(User $customer): Builder<CustomerFavorite>`; `CustomerFavorites::LIMIT = 500`; `ChangeFavorites::add(User $customer, string $productId): void`, `ChangeFavorites::remove(User $customer, string $productId): void`.

- [ ] **Step 1: Write the failing tests** (`FavoritesApiTest`; helpers `asCustomer(User)` as in `CustomerCatalogApiTest`):
  1. `PUT` a listed product → `204`; `GET` lists it with `is_favorite` true, `is_available` true, the customer price, never `market_price_uzs`.
  2. `PUT` twice → one row, both `204`.
  3. `PUT` an inactive product, an archived one, one in an archived category, an unknown UUID → each `404 resource_not_found`; `PUT /customer/favorites/not-a-uuid` → `404`.
  4. `PUT` with a body `{"x":1}` → `422 validation_failed`; `DELETE` with a body → `422`.
  5. `DELETE` a favourite → `204`, gone; `DELETE` a non-favourite, an unknown UUID, an archived product → `204`.
  6. Scope: Customer B's `GET` does not list A's favourites; B's `DELETE` of A's product removes only B's row (A keeps hers); B's catalog list shows `is_favorite` false for A's favourite.
  7. A favourite whose product is then archived stays in `GET` with `is_available` false; one whose category is archived likewise.
  8. Order: three favourites added at travelled times are listed newest first; equal times fall back to `id`.
  9. Limit: with 500 rows (factory), `PUT` of a new product → `409 favorites_full`, `details.limit = 500`; `PUT` of one already favourite → `204`.
  10. A Shopper token → `403` on all three routes; a blocked Customer → `401 account_blocked`; no token → `401`.
  `CustomerFavoritesTableTest`: `(customer_id, product_id)` unique. `CustomerCatalogApiTest`: list and detail carry `is_favorite` (false, then true after a favourite row); the key list assertion includes it.
  Run `php artisan test --filter='Favorites|CustomerCatalogApiTest'` — expect FAIL.

- [ ] **Step 2: Implement.** Migration:

```php
Schema::create('customer_favorites', function (Blueprint $table): void {
    $table->uuid('id')->primary();
    $table->foreignUuid('customer_id')->constrained('users')->restrictOnDelete();
    $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
    $table->timestampTz('created_at');
    $table->unique(['customer_id', 'product_id']);
});
DB::statement('create index customer_favorites_customer_created_idx on customer_favorites (customer_id, created_at desc, id desc)');
```

`CustomerFavorite`: `HasUuids`, `const UPDATED_AT = null`, `customer(): BelongsTo<User>`, `product(): BelongsTo<Product>`. `CustomerFavorites::own()` = `CustomerFavorite::query()->where('customer_id', $customer->id)`. `ChangeFavorites`:

```php
public function add(User $customer, string $productId): void
{
    DB::transaction(function () use ($customer, $productId): void {
        // One customer's adds are serialized, so the limit holds under
        // concurrent requests.
        User::query()->whereKey($customer->id)->lockForUpdate()->firstOrFail();
        ScopedLookup::firstOrNotFound(CustomerCatalogListing::visibleProducts()->whereKey($productId));

        if (CustomerFavorites::own($customer)->where('product_id', $productId)->exists()) {
            return;
        }
        if (CustomerFavorites::own($customer)->count() >= CustomerFavorites::LIMIT) {
            throw ApiException::conflict('favorites_full', ['limit' => CustomerFavorites::LIMIT]);
        }
        CustomerFavorite::query()->create(['customer_id' => $customer->id, 'product_id' => $productId]);
    });
}

public function remove(User $customer, string $productId): void
{
    CustomerFavorites::own($customer)->where('product_id', $productId)->delete();
}
```

(Check `ApiException`'s conflict factory signature and use it as the cart's `cart_full` does.) The `visibleProducts()` lookup must not take the product row lock path the cart uses; a plain read is enough. Routes in `customer.php`'s Customer group:

```php
Route::get('favorites', [FavoriteController::class, 'index']);
Route::put('favorites/{product}', [FavoriteController::class, 'store']);
Route::delete('favorites/{product}', [FavoriteController::class, 'destroy']);
```

`store`/`destroy` refuse any body field the way other no-body routes do (find the existing helper for "an endpoint that takes no body refuses any field", e.g. the archive routes' request, and reuse it). `index`: `CustomerFavorites::own($c)->with(['product.image', 'product.category'])->orderByDesc('created_at')->orderByDesc('id')->paginate(…)`, each through `FavoriteProductResource` = the `CustomerProductResource` array with `is_favorite` true plus `is_available` (product active, unarchived, its category active and unarchived). The catalog list adds `->withExists(['favorites as is_favorite' => fn (Builder $q) => $q->where('customer_id', $customerId)])` to the query of `products()` in the controller (not inside `visibleProducts()`, which the cart locks with), the detail the same; `CustomerProductResource` outputs `'is_favorite' => (bool) ($product->is_favorite ?? false)`.

- [ ] **Step 3: Run** the Step 1 filter, `CartApiTest`, `CheckoutPreviewApiTest` — PASS; pint, phpstan.

- [ ] **Step 4: Docs.** `DL-79` item 5: "**Favourites** live in `customer_favorites`, one row per Customer and product, at most 500. `PUT` adds only a product the Customer can see (otherwise the scope-safe `404`); `DELETE` answers `204` whatever the product, so it tells nothing. A favourite that stops being sold stays and is listed with `is_available: false`. The catalog product carries `is_favorite` so every list draws its hearts without another request." Item 6: "**Numbering.** New tables are appended to `docs/08` as sections 31 and 32 and the favourites API is `docs/09` section 58, so earlier section numbers cited across the documents stay." `docs/03` §5: the Customer's favourites. `docs/05` BR-CAT-007: "A Customer keeps at most 500 favourite products; a product becomes a favourite only while the Customer can see it; a favourite that stops being sold stays, shown as unavailable." `docs/08`: Table Map + §32. `docs/09` §14: `is_favorite`; §58 the three routes as in **Interfaces**.

- [ ] **Step 5: Commit** — `feat(customer): favourite products`.

---

### Task 5: Panel — the product form (no price mode, "Рекомендуем")

**Files:**
- Modify: `frontend/lib/features/admin/domain/admin_catalog.dart` (`AdminProduct`: drop `priceMode`, add `final bool isFeatured`; `ProductDraft`: drop `priceMode`, add `isFeatured`), `frontend/lib/features/admin/data/admin_catalog_dto.dart` (stop reading and sending `price_mode`; read `is_featured`; send `is_featured` when changed), `frontend/lib/features/admin/presentation/product_edit_screen.dart` (remove the `field-price_mode` SegmentedButton at 437–451; add the switch), `frontend/lib/features/admin/presentation/products_screen.dart` (row: drop the price-mode label at 209, add the "Рекомендуем" chip), `frontend/lib/core/localization/l10n/app_uz.arb` and `app_ru.arb` (+ regenerate)
- Test: `frontend/test/features/admin/presentation/catalog_screens_test.dart`, `frontend/test/features/admin/data/admin_catalog_api_test.dart`, `frontend/test/support/fake_admin_catalog_repository.dart`

**Interfaces:**
- Produces: `AdminProduct.isFeatured`, `ProductDraft.isFeatured`; switch key `field-is_featured`; list chip key `featured-<productId>`. ARB keys `productFeatured`, `productFeaturedHint`, `productFeaturedBadge`.

- [ ] **Step 1: Write the failing tests.** API test: a create body has no `price_mode` key and has `is_featured` false; an edit that only flips the switch sends exactly `{"is_featured": true}`; parsing reads `is_featured`. Screen test: the form has no `field-price_mode`; toggling `field-is_featured` and saving calls the fake with `isFeatured: true`; a featured product's row shows `featured-<id>`; the form renders at 320×640 with `textScaleFactorTestValue = 2` in `uz` and `ru` without an exception (follow the existing small-screen pattern of the file if any; otherwise use `tester.view.physicalSize = const Size(320, 640)`, `devicePixelRatio = 1`, `platformDispatcher.textScaleFactorTestValue = 2`, with `addTearDown` resets).
  Run `G:/tools/flutter/bin/flutter test test/features/admin` — expect FAIL.

- [ ] **Step 2: Implement.** ARB (uz / ru): `productFeatured` "Tavsiya etamiz bo'limida ko'rsatish" / "Показывать в «Рекомендуем»"; `productFeaturedHint` "Mahsulot bosh sahifadagi «Tavsiya etamiz» qatorida chiqadi" / "Товар появится в ряду «Рекомендуем» на главной"; `productFeaturedBadge` "Tavsiya" / "Рекомендуем". The switch is a `SwitchListTile` like `field-is_active`, placed after the sort order. Drop `productPriceMode` from the ARB files only if nothing else uses it (`grep -rn productPriceMode lib`); `CatalogLabels.priceMode` and the `priceMode*` keys stay (orders and the operations board still show a line's mode). Run `G:/tools/flutter/bin/flutter gen-l10n`.

- [ ] **Step 3: Run** `flutter test test/features/admin`, `flutter analyze`, `dart format --set-exit-if-changed lib test` — PASS.

- [ ] **Step 4: Commit** — `feat(panel): the product form loses the price mode and gains "Рекомендуем"`.

---

### Task 6: Panel — category pictures

**Files:**
- Create: `frontend/lib/features/admin/presentation/catalog_image_card.dart` (the image card extracted from `product_edit_screen.dart` `_ProductImageCard` at 490)
- Modify: `frontend/lib/features/admin/presentation/product_edit_screen.dart` (use `CatalogImageCard`), `frontend/lib/features/admin/presentation/categories_screen.dart` (dialog section and row thumbnail), `frontend/lib/features/admin/domain/admin_catalog.dart` (`AdminCategory.imageUrl`), `frontend/lib/features/admin/domain/admin_catalog_repository.dart`, `frontend/lib/features/admin/data/admin_catalog_api.dart`, `frontend/lib/features/admin/data/admin_catalog_dto.dart`, `frontend/lib/features/admin/application/admin_catalog_controllers.dart` (upload/remove controller for a category, as the product's), ARB files (+ regenerate)
- Test: `frontend/test/features/admin/presentation/catalog_screens_test.dart`, `frontend/test/features/admin/data/admin_catalog_api_test.dart`, `frontend/test/support/fake_admin_catalog_repository.dart`

**Interfaces:**
- Consumes: Task 2's `POST|DELETE /admin/categories/{id}/image`.
- Produces: `AdminCatalogRepository.uploadCategoryImage(String categoryId, PickedImage image): Future<AdminCategory>`, `removeCategoryImage(String categoryId): Future<AdminCategory>`; `AdminCategory.imageUrl: String?`; `CatalogImageCard({required String? imageUrl, required Future<void> Function(PickedImage) onUpload, required Future<void> Function() onRemove, required String keyPrefix})` — the product form passes `keyPrefix: ''` so its keys stay `choose-image`, `upload-image`, `remove-image`, `current-image`, `picked-image`, `confirm-remove-image`; the category dialog passes `'category-'`.

- [ ] **Step 1: Write the failing tests.** API test: `uploadCategoryImage` posts multipart field `image` to `/admin/categories/<id>/image`; `removeCategoryImage` sends `DELETE`; both parse `image_url`. Screen test: editing an existing category shows `category-choose-image`; picking (the existing `_FakePicker`) and uploading calls the fake and the dialog then shows `category-current-image`; remove asks `category-confirm-remove-image` and clears it; a new category's dialog shows the hint `categoryImageAfterSave` and no picker; the category row shows a thumbnail when `imageUrl` is set and the first letter otherwise; every product-image test of the file still passes unchanged (the extraction keeps the keys); the dialog renders at 320×640, text ×2, `uz` and `ru`.
  Run `flutter test test/features/admin` — expect FAIL.

- [ ] **Step 2: Implement.** Move `_ProductImageCard` and its state into `CatalogImageCard` with the parameters above (keys built as `'${keyPrefix}choose-image'` etc.), the product form passing its existing upload/remove calls. In the category dialog, for an existing category, a `CatalogImageCard` under the fields; for a new one, the text `categoryImageAfterSave`. ARB: `categoryImage` "Rasm" / "Картинка"; `categoryImageAfterSave` "Rasmni saqlagandan keyin qo'shish mumkin" / "Картинку можно добавить после сохранения". Regenerate l10n.

- [ ] **Step 3: Run** `flutter test test/features/admin`, `flutter analyze`, `dart format --set-exit-if-changed lib test` — PASS.

- [ ] **Step 4: Docs.** `DL-79` item 7: "**The panel's picture card** is shared by the product form and the category dialog; a category takes a picture once it exists, as a product does." `docs/03` §5: the Admin uploads a category picture.

- [ ] **Step 5: Commit** — `feat(panel): category pictures`.

---

## After the tasks

Full backend suite and full frontend suite through `test-runner`; `git diff --check`; branch review (`branch-reviewer`) with this plan, BASE 6230868 and HEAD; one fix wave; `/security-review` (the branch adds a Customer-owned resource and uploads); PR; both required checks green; merge; then stage 2b on a new branch from the new `main`.
