import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../data/master_repository.dart';

abstract class ProductState {}
class ProductInitial extends ProductState {}
class ProductLoading extends ProductState {}
class ProductLoaded extends ProductState {
  final List<Map<String, dynamic>> products;
  ProductLoaded(this.products);
}
class ProductCompleteLoaded extends ProductState {
  final Map<String, dynamic> completeProduct;
  ProductCompleteLoaded(this.completeProduct);
}
class ProductSaved extends ProductState {
  final bool isUpdate;
  ProductSaved({this.isUpdate = false});
}
class ProductDeleted extends ProductState {
  final String productName;
  ProductDeleted({this.productName = ''});
}
class ProductError extends ProductState {
  final String message;
  ProductError(this.message);
}

class ProductCubit extends Cubit<ProductState> {
  final MasterRepository _repository;
  MasterRepository get repository => _repository;

  ProductCubit(this._repository) : super(ProductInitial());

  Future<void> loadProducts() async {
    emit(ProductLoading());
    try {
      final products = await _repository.getProductsWithDetails();
      emit(ProductLoaded(products));
    } catch (e) {
      emit(ProductError('Gagal memuat produk: $e'));
    }
  }

  Future<void> loadProductComplete(int id) async {
    emit(ProductLoading());
    try {
      final details = await _repository.getProductComplete(id);
      if (details != null) {
        emit(ProductCompleteLoaded(details));
      } else {
        emit(ProductError('Produk tidak ditemukan'));
      }
    } catch (e) {
      emit(ProductError('Gagal memuat detail produk: $e'));
    }
  }

  Future<void> saveProduct({
    Product? existingProduct,
    required String name,
    String? sku,
    String? barcode,
    String? description,
    int? categoryId,
    int? brandId,
    String? imagePath,
    required String productType,
    String businessSegment = 'retail',
    required bool isStockManaged,
    required int minStockAlert,
    bool allowManualPrice = false,
    bool isConsignment = false,
    int? supplierId,
    String? consignmentType,
    double commissionRate = 0.0,
    bool hasRecipe = false,
    required List<ProductUnitsCompanion> units,
    required List<ProductPricesCompanion> prices,
    List<ProductRecipesCompanion> recipes = const [],
    File? newImageFile,
  }) async {
    emit(ProductLoading());
    try {
      String? finalImagePath = imagePath;
      if (newImageFile != null) {
        finalImagePath = await _repository.saveProductImage(newImageFile);
      }

      if (existingProduct == null) {
        final productCompanion = ProductsCompanion.insert(
          name: name,
          sku: Value(sku),
          barcode: Value(barcode),
          description: Value(description),
          categoryId: Value(categoryId),
          brandId: Value(brandId),
          imagePath: Value(finalImagePath),
          productType: Value(productType),
          businessSegment: Value(businessSegment),
          isStockManaged: Value(isStockManaged),
          minStockAlert: Value(minStockAlert),
          allowManualPrice: Value(allowManualPrice),
          isConsignment: Value(isConsignment),
          supplierId: Value(supplierId),
          consignmentType: Value(consignmentType),
          commissionRate: Value(commissionRate),
          hasRecipe: Value(hasRecipe),
          isActive: const Value(true),
        );

        await _repository.insertProductComplete(
          product: productCompanion,
          units: units,
          prices: prices,
          recipes: recipes,
        );
      } else {
        final updatedProduct = existingProduct.copyWith(
          name: name,
          sku: Value(sku),
          barcode: Value(barcode),
          description: Value(description),
          categoryId: Value(categoryId),
          brandId: Value(brandId),
          imagePath: Value(finalImagePath),
          productType: productType,
          businessSegment: businessSegment,
          isStockManaged: isStockManaged,
          minStockAlert: minStockAlert,
          allowManualPrice: allowManualPrice,
          isConsignment: isConsignment,
          supplierId: Value(supplierId),
          consignmentType: Value(consignmentType),
          commissionRate: commissionRate,
          hasRecipe: hasRecipe,
        );

        await _repository.updateProductComplete(
          product: updatedProduct,
          units: units,
          prices: prices,
          recipes: recipes,
        );
      }
      emit(ProductSaved(isUpdate: existingProduct != null));
      await loadProducts();
    } catch (e) {
      emit(ProductError('Gagal menyimpan produk: $e'));
    }
  }

  Future<void> deleteProduct(int id, {String productName = ''}) async {
    try {
      await _repository.deleteProduct(id);
      emit(ProductDeleted(productName: productName));
      await loadProducts();
    } catch (e) {
      emit(ProductError('Gagal menghapus produk: $e'));
    }
  }
}
