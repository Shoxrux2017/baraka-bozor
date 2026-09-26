import '../../../core/catalog/catalog_values.dart';
import '../../../core/localization/app_language.dart';

/// A category as the Customer sees it (`docs/09-api-contracts.md`
/// section 14).
final class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.nameUz,
    required this.nameRu,
    required this.descriptionUz,
    required this.descriptionRu,
    required this.sortOrder,
  });

  final String id;
  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final int sortOrder;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;
}

/// A product as the Customer sees it: the customer price, never the market
/// price (`BR-PRICE-001`).
final class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.categoryId,
    required this.nameUz,
    required this.nameRu,
    required this.descriptionUz,
    required this.descriptionRu,
    required this.unitCode,
    required this.priceMode,
    required this.customerUnitPriceUzs,
    required this.imageUrl,
  });

  final String id;
  final String categoryId;
  final String nameUz;
  final String nameRu;
  final String? descriptionUz;
  final String? descriptionRu;
  final UnitCode unitCode;
  final PriceMode priceMode;
  final int customerUnitPriceUzs;
  final String? imageUrl;

  String name(AppLanguage language) =>
      language == AppLanguage.ru ? nameRu : nameUz;

  /// The name in the other language, shown under the first.
  String otherName(AppLanguage language) =>
      language == AppLanguage.ru ? nameUz : nameRu;

  String? description(AppLanguage language) =>
      language == AppLanguage.ru ? descriptionRu : descriptionUz;
}

/// Which products a list shows: those of one category, those matching a
/// search, or both.
final class ProductListQuery {
  const ProductListQuery({this.categoryId, this.search = ''});

  /// The longest search the server takes, in code points
  /// (`CatalogSearch::MAX_TERM_LENGTH`).
  static const int searchMaxLength = 100;

  /// [text] as a search: trimmed, and cut to what the server takes — the
  /// field counts what the Customer sees, the server counts code points.
  static String searchOf(String text) =>
      String.fromCharCodes(text.trim().runes.take(searchMaxLength)).trim();

  final String? categoryId;
  final String search;

  @override
  bool operator ==(Object other) =>
      other is ProductListQuery &&
      other.categoryId == categoryId &&
      other.search == search;

  @override
  int get hashCode => Object.hash(categoryId, search);
}
