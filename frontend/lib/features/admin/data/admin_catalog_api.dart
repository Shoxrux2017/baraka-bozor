import 'package:dio/dio.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/paged.dart';
import '../../../core/storage/token_store.dart';
import '../domain/admin_catalog.dart';
import 'admin_catalog_dto.dart';

/// The data source for `docs/09-api-contracts.md` sections 15 and 16, on the
/// staff session. Transport failures leave as `DioException` and are mapped
/// by the repository.
class AdminCatalogApi {
  AdminCatalogApi(this._dio);

  final Dio _dio;

  static final Options _staff = RequestSlot.of(SessionSlot.staff);

  Future<Paged<AdminCategory>> categories(
    CategoryQuery query, {
    required int perPage,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/categories',
      queryParameters: <String, Object>{
        'page': query.page,
        'per_page': perPage,
        if (query.includeArchived) 'include_archived': 'true',
      },
      options: _staff,
    );
    return Paged.parse(response.data, AdminCatalogDto.parseCategory);
  }

  Future<AdminCategory> createCategory(CategoryDraft draft) => _category(
    _dio.post<dynamic>(
      '/admin/categories',
      data: AdminCatalogDto.categoryBody(draft),
      options: _staff,
    ),
  );

  /// Sends what [draft] changed from [category]. With nothing changed there
  /// is nothing to send — the server refuses an empty edit (`docs/09`
  /// section 3) — and the category is answered as it is.
  Future<AdminCategory> updateCategory(
    AdminCategory category,
    CategoryDraft draft,
  ) async {
    final Map<String, Object?> body = AdminCatalogDto.categoryBody(
      draft,
      base: category,
    );
    if (body.isEmpty) {
      return category;
    }
    return _category(
      _dio.patch<dynamic>(
        '/admin/categories/${Uri.encodeComponent(category.id)}',
        data: body,
        options: _staff,
      ),
    );
  }

  Future<AdminCategory> archiveCategory(String id) => _category(
    _dio.post<dynamic>(
      '/admin/categories/${Uri.encodeComponent(id)}/archive',
      options: _staff,
    ),
  );

  Future<AdminCategory> restoreCategory(String id) => _category(
    _dio.post<dynamic>(
      '/admin/categories/${Uri.encodeComponent(id)}/restore',
      options: _staff,
    ),
  );

  Future<Paged<AdminProduct>> products(ProductQuery query) async {
    final String search = query.search.trim();
    final Response<dynamic> response = await _dio.get<dynamic>(
      '/admin/products',
      queryParameters: <String, Object>{
        'page': query.page,
        if (query.includeArchived) 'include_archived': 'true',
        if (query.categoryId != null) 'category_id': query.categoryId!,
        if (search.isNotEmpty) 'search': search,
      },
      options: _staff,
    );
    return Paged.parse(response.data, AdminCatalogDto.parseProduct);
  }

  Future<AdminProduct> product(String id) => _product(
    _dio.get<dynamic>(
      '/admin/products/${Uri.encodeComponent(id)}',
      options: _staff,
    ),
  );

  Future<AdminProduct> createProduct(ProductDraft draft) => _product(
    _dio.post<dynamic>(
      '/admin/products',
      data: AdminCatalogDto.productBody(draft),
      options: _staff,
    ),
  );

  /// As [updateCategory], for a product.
  Future<AdminProduct> updateProduct(
    AdminProduct product,
    ProductDraft draft,
  ) async {
    final Map<String, Object?> body = AdminCatalogDto.productBody(
      draft,
      base: product,
    );
    if (body.isEmpty) {
      return product;
    }
    return _product(
      _dio.patch<dynamic>(
        '/admin/products/${Uri.encodeComponent(product.id)}',
        data: body,
        options: _staff,
      ),
    );
  }

  Future<AdminProduct> archiveProduct(String id) => _product(
    _dio.post<dynamic>(
      '/admin/products/${Uri.encodeComponent(id)}/archive',
      options: _staff,
    ),
  );

  Future<AdminProduct> restoreProduct(String id) => _product(
    _dio.post<dynamic>(
      '/admin/products/${Uri.encodeComponent(id)}/restore',
      options: _staff,
    ),
  );

  /// The multipart upload of `docs/09` section 16: one file field, `image`.
  Future<AdminProduct> uploadImage(String productId, PickedImage image) =>
      _product(
        _dio.post<dynamic>(
          '/admin/products/${Uri.encodeComponent(productId)}/image',
          data: FormData.fromMap(<String, Object>{
            'image': MultipartFile.fromBytes(image.bytes, filename: image.name),
          }),
          options: _staff,
        ),
      );

  Future<AdminProduct> removeImage(String productId) => _product(
    _dio.delete<dynamic>(
      '/admin/products/${Uri.encodeComponent(productId)}/image',
      options: _staff,
    ),
  );

  static Future<AdminCategory> _category(
    Future<Response<dynamic>> request,
  ) async =>
      AdminCatalogDto.parseCategory(ApiEnvelope.unwrap((await request).data));

  static Future<AdminProduct> _product(
    Future<Response<dynamic>> request,
  ) async =>
      AdminCatalogDto.parseProduct(ApiEnvelope.unwrap((await request).data));
}
