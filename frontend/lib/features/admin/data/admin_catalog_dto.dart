import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/json_fields.dart';
import '../domain/admin_catalog.dart';

/// Strict parsing and request bodies for `docs/09-api-contracts.md`
/// sections 15 and 16.
abstract final class AdminCatalogDto {
  static AdminCategory parseCategory(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'category');

    final AdminCategory category = AdminCategory(
      id: json.uuid('id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      descriptionUz: json.nullableString('description_uz'),
      descriptionRu: json.nullableString('description_ru'),
      sortOrder: json.integer('sort_order'),
      isActive: json.boolean('is_active'),
      archivedAt: json.nullableInstant('archived_at'),
      createdAt: json.instant('created_at'),
      updatedAt: json.instant('updated_at'),
    );
    _neverArchivedAndActive(category.archivedAt, category.isActive);
    return category;
  }

  static AdminProduct parseProduct(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'product');

    final AdminProduct product = AdminProduct(
      id: json.uuid('id'),
      categoryId: json.uuid('category_id'),
      nameUz: json.string('name_uz'),
      nameRu: json.string('name_ru'),
      descriptionUz: json.nullableString('description_uz'),
      descriptionRu: json.nullableString('description_ru'),
      unitCode: json.choice('unit_code', UnitCode.tryParse),
      priceMode: json.choice('price_mode', PriceMode.tryParse),
      marketPriceUzs: json.integer('market_price_uzs'),
      customerUnitPriceUzs: json.integer('customer_unit_price_uzs'),
      imageUrl: json.nullableString('image_url'),
      sortOrder: json.integer('sort_order'),
      isActive: json.boolean('is_active'),
      archivedAt: json.nullableInstant('archived_at'),
      createdAt: json.instant('created_at'),
      updatedAt: json.instant('updated_at'),
    );
    _neverArchivedAndActive(product.archivedAt, product.isActive);
    return product;
  }

  /// A new category: every field; `is_active` only when the form offers it.
  /// An edit of [base]: only what changed (`DL-28` (9)).
  static Map<String, Object?> categoryBody(
    CategoryDraft draft, {
    AdminCategory? base,
  }) => _changed(
    _categoryFields(draft),
    base == null ? null : _categoryFields(CategoryDraft.fromCategory(base)),
  );

  /// As [categoryBody], for a product.
  static Map<String, Object?> productBody(
    ProductDraft draft, {
    AdminProduct? base,
  }) => _changed(
    _productFields(draft),
    base == null ? null : _productFields(ProductDraft.fromProduct(base)),
  );

  static Map<String, Object?> _categoryFields(CategoryDraft draft) =>
      <String, Object?>{
        'name_uz': draft.nameUz,
        'name_ru': draft.nameRu,
        'description_uz': draft.descriptionUz,
        'description_ru': draft.descriptionRu,
        'sort_order': draft.sortOrder,
        if (draft.isActive != null) 'is_active': draft.isActive,
      };

  static Map<String, Object?> _productFields(ProductDraft draft) =>
      <String, Object?>{
        'category_id': draft.categoryId,
        'name_uz': draft.nameUz,
        'name_ru': draft.nameRu,
        'description_uz': draft.descriptionUz,
        'description_ru': draft.descriptionRu,
        'unit_code': draft.unitCode.code,
        'price_mode': draft.priceMode.code,
        'market_price_uzs': draft.marketPriceUzs,
        'sort_order': draft.sortOrder,
        if (draft.isActive != null) 'is_active': draft.isActive,
      };

  static Map<String, Object?> _changed(
    Map<String, Object?> after,
    Map<String, Object?>? before,
  ) => before == null
      ? after
      : <String, Object?>{
          for (final MapEntry<String, Object?> field in after.entries)
            if (!before.containsKey(field.key) ||
                before[field.key] != field.value)
              field.key: field.value,
        };

  /// `DL-17` (14): an archived entry is never active.
  static void _neverArchivedAndActive(DateTime? archivedAt, bool isActive) {
    if (archivedAt != null && isActive) {
      throw const FormatException('an archived entry is marked active');
    }
  }
}
