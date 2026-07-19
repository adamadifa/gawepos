import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/purchase_repository.dart';
import '../../../../core/database/app_database.dart';

abstract class PurchaseState {}

class PurchaseInitial extends PurchaseState {}

class PurchaseLoading extends PurchaseState {}

class PurchaseLoaded extends PurchaseState {
  final List<Map<String, dynamic>> purchases;
  PurchaseLoaded(this.purchases);
}

class PurchaseSuccess extends PurchaseState {}

class PurchaseError extends PurchaseState {
  final String message;
  PurchaseError(this.message);
}

class PurchaseCubit extends Cubit<PurchaseState> {
  final PurchaseRepository _repository;

  PurchaseCubit(this._repository) : super(PurchaseInitial());

  Future<void> loadPurchases() async {
    emit(PurchaseLoading());
    try {
      final list = await _repository.getPurchases();
      emit(PurchaseLoaded(list));
    } catch (e) {
      emit(PurchaseError('Gagal memuat restok pembelian: $e'));
    }
  }

  Future<void> createPurchase({
    required int supplierId,
    required List<Map<String, dynamic>> items,
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    String paymentType = 'cash',
    double downPayment = 0.0,
  }) async {
    emit(PurchaseLoading());
    try {
      await _repository.savePurchase(
        supplierId: supplierId,
        items: items,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        paymentType: paymentType,
        downPayment: downPayment,
      );
      final list = await _repository.getPurchases();
      emit(PurchaseLoaded(list));
    } catch (e) {
      emit(PurchaseError('Gagal menyimpan pesanan pembelian: $e'));
    }
  }

  Future<void> confirmReceive(int purchaseId) async {
    emit(PurchaseLoading());
    try {
      await _repository.confirmReceive(purchaseId);
      final list = await _repository.getPurchases();
      emit(PurchaseLoaded(list));
    } catch (e) {
      emit(PurchaseError('Gagal konfirmasi penerimaan barang: $e'));
    }
  }

  Future<void> deletePurchase(int purchaseId) async {
    emit(PurchaseLoading());
    try {
      await _repository.deletePurchase(purchaseId);
      final list = await _repository.getPurchases();
      emit(PurchaseLoaded(list));
    } catch (e) {
      emit(PurchaseError('Gagal menghapus pesanan pembelian: $e'));
    }
  }

  Future<List<ProductUnit>> getProductUnits(int productId) async {
    return await _repository.getProductUnits(productId);
  }
}
