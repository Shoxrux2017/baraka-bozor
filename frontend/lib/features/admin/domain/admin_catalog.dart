import 'dart:typed_data';

import '../../../core/catalog/catalog_values.dart';

/// Where a catalog entry stands for the Admin (`DL-17` (14)): shown to
/// Customers, hidden without being archived, or archived.
enum CatalogEntryState { active, hidden, archived }

/// A category as the Admin manages it (`docs/09-api-contracts.md`
/// section 15).
final class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.nameUz,
    required this.nameRu,
    required this.descriptionUz,
    required this.descriptionRu,
    required this.sortOrder,
    required this.isActive,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final int sortOrder;
  final bool isActive;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatalogEntryState get state => archivedAt != null
      ? CatalogEntryState.archived
      : isActive
      ? CatalogEntryState.active
      : CatalogEntryState.hidden;
}

/// A product as the Admin manages it: the market price the Admin enters and
/// the customer price the current markup makes of it (`BR-PRICE-001`).
final class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.categoryId,
    required this.nameUz,
    required this.nameRu,
    required this.descriptionUz,
    required this.descriptionRu,
    required this.unitCode,
    required this.priceMode,
    required this.marketPriceUzs,
    required this.customerUnitPriceUzs,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final UnitCode unitCode;
  final PriceMode priceMode;
  final int marketPriceUzs;
  final int customerUnitPriceUzs;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CatalogEntryState get state => archivedAt != null
      ? CatalogEntryState.archived
      : isActive
      ? CatalogEntryState.active
      : CatalogEntryState.hidden;
}

/// A category as its form submits it.
final class CategoryDraft {
  const CategoryDraft({
    required this.nameUz,
    required this.nameRu,
    required this.descriptionUz,
    required this.descriptionRu,
    required this.sortOrder,
    required this.isActive,
  });

  /// The draft of [category] nobody has edited: what its form started from.
  factory CategoryDraft.fromCategory(AdminCategory category) => CategoryDraft(
    nameUz: category.nameUz,
    nameRu: category.nameRu,
    descriptionUz: category.descriptionUz,
    descriptionRu: category.descriptionRu,
    sortOrder: category.sortOrder,
    isActive: category.state == CatalogEntryState.archived
        ? null
        : category.isActive,
  );

  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final int sortOrder;

  /// `null` leaves the flag as it is: an archived entry is restored by its
  /// own action, and `is_active: true` on it would be a `409`.
  final bool? isActive;

  List<Object?> get _values => <Object?>[
    nameUz,
    nameRu,
    descriptionUz,
    descriptionRu,
    sortOrder,
    isActive,
  ];

  @override
  bool operator ==(Object other) =>
      other is CategoryDraft && _sameValues(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);
}

/// A product as its form submits it.
final class ProductDraft {
  const ProductDraft({
    required this.categoryId,
    required this.nameUz,
    required this.nameRu,
    required this.descriptionUz,
    required this.descriptionRu,
    required this.unitCode,
    required this.priceMode,
    required this.marketPriceUzs,
    required this.sortOrder,
    required this.isActive,
  });

  /// The draft of [product] nobody has edited: what its form started from.
  factory ProductDraft.fromProduct(AdminProduct product) => ProductDraft(
    categoryId: product.categoryId,
    nameUz: product.nameUz,
    nameRu: product.nameRu,
    descriptionUz: product.descriptionUz,
    descriptionRu: product.descriptionRu,
    unitCode: product.unitCode,
    priceMode: product.priceMode,
    marketPriceUzs: product.marketPriceUzs,
    sortOrder: product.sortOrder,
    isActive: product.state == CatalogEntryState.archived
        ? null
        : product.isActive,
  );

  final String categoryId;
  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final UnitCode unitCode;
  final PriceMode priceMode;
  final int marketPriceUzs;
  final int sortOrder;

  /// `null` leaves the flag as it is, as for [CategoryDraft.isActive].
  final bool? isActive;

  List<Object?> get _values => <Object?>[
    categoryId,
    nameUz,
    nameRu,
    descriptionUz,
    descriptionRu,
    unitCode,
    priceMode,
    marketPriceUzs,
    sortOrder,
    isActive,
  ];

  @override
  bool operator ==(Object other) =>
      other is ProductDraft && _sameValues(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);
}

bool _sameValues(List<Object?> a, List<Object?> b) {
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// What the Admin asks of the category list.
final class CategoryQuery {
  const CategoryQuery({this.page = 1, this.includeArchived = false});

  final int page;
  final bool includeArchived;

  CategoryQuery copyWith({int? page, bool? includeArchived}) => CategoryQuery(
    page: page ?? this.page,
    includeArchived: includeArchived ?? this.includeArchived,
  );

  @override
  bool operator ==(Object other) =>
      other is CategoryQuery &&
      other.page == page &&
      other.includeArchived == includeArchived;

  @override
  int get hashCode => Object.hash(page, includeArchived);
}

/// What the Admin asks of the product list.
final class ProductQuery {
  const ProductQuery({
    this.page = 1,
    this.includeArchived = false,
    this.categoryId,
    this.search = '',
  });

  /// The longest search the server takes, in code points
  /// (`CatalogSearch::MAX_TERM_LENGTH`).
  static const int searchMaxLength = 100;

  final int page;
  final bool includeArchived;
  final String? categoryId;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.page == page &&
      other.includeArchived == includeArchived &&
      other.categoryId == categoryId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(page, includeArchived, categoryId, search);
}

/// An image the Admin picked, as bytes, with the name the file had.
final class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;

  /// `BR-CAT-004`: at most 5 MiB, counted in bytes.
  static const int maxBytes = 5 * 1024 * 1024;

  bool get isTooLarge => bytes.length > maxBytes;

  /// Whether the bytes begin like a JPEG, PNG or WebP file — the three the
  /// server accepts, judged by the bytes (`BR-CAT-004`). The server decides;
  /// this only spares a pointless upload.
  bool get looksLikeAcceptedImage {
    bool startsWith(List<int> prefix, [int offset = 0]) {
      if (bytes.length < offset + prefix.length) {
        return false;
      }
      for (int i = 0; i < prefix.length; i++) {
        if (bytes[offset + i] != prefix[i]) {
          return false;
        }
      }
      return true;
    }

    return startsWith(<int>[0xFF, 0xD8, 0xFF]) ||
        startsWith(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) ||
        (startsWith(<int>[0x52, 0x49, 0x46, 0x46]) &&
            startsWith(<int>[0x57, 0x45, 0x42, 0x50], 8));
  }
}
