import '../../../core/catalog/catalog_values.dart';
import '../../../core/network/json_fields.dart';
import '../domain/admin_catalog.dart';

/// Strict parsing and request bodies for `docs/09-api-contracts.md`
/// sections 15 and 16.
abstract final class AdminCatalogDto {
  static AdminCategory parseCategory(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'category');

    return AdminCategory(
      id: json.string('id'),
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
  }

  static AdminProduct parseProduct(Object? raw) {
    final JsonFields json = JsonFields.of(raw, 'product');

    return AdminProduct(
      id: json.string('id'),
      categoryId: json.string('category_id'),
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
  }

  /// Every field of the category form; an empty description goes as `null`,
  /// and `is_active` only when the form offers it.
  static Map<String, Object?> categoryBody(CategoryDraft draft) =>
      <String, Object?>{
        'name_uz': draft.nameUz,
        'name_ru': draft.nameRu,
        'description_uz': draft.descriptionUz,
        'description_ru': draft.descriptionRu,
        'sort_order': draft.sortOrder,
        if (draft.isActive != null) 'is_active': draft.isActive,
      };

  /// Every field of the product form, `is_active` as for [categoryBody].
  static Map<String, Object?> productBody(ProductDraft draft) =>
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
}
