import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sales_repository.dart';

abstract class SalesState {}

class SalesInitial extends SalesState {}

class SalesLoading extends SalesState {}

class SalesProductsLoaded extends SalesState {
  final List<Map<String, dynamic>> products;
  SalesProductsLoaded(this.products);
}

class SalesSuccess extends SalesState {
  final int orderId;
  SalesSuccess(this.orderId);
}

class SalesError extends SalesState {
  final String message;
  SalesError(this.message);
}

class SalesCubit extends Cubit<SalesState> {
  final SalesRepository _repository;

  SalesCubit(this._repository) : super(SalesInitial());

  // Memuat produk katalog kasir
  Future<void> loadProducts() async {
    emit(SalesLoading());
    try {
      final products = await _repository.getPosProducts();
      emit(SalesProductsLoaded(products));
    } catch (e) {
      emit(SalesError('Gagal memuat katalog produk: $e'));
    }
  }

  // Menyelesaikan pesanan (Checkout & Pembayaran)
  Future<void> checkout({
    required int userId,
    required int cashierSessionId,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required List<Map<String, dynamic>> cartItems,
    required List<Map<String, dynamic>> payments,
    double downPayment = 0.0,
    int? customerId,
    String? notes,
  }) async {
    emit(SalesLoading());
    try {
      final orderId = await _repository.saveOrder(
        userId: userId,
        cashierSessionId: cashierSessionId,
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        changeAmount: changeAmount,
        downPayment: downPayment,
        cartItems: cartItems,
        payments: payments,
        customerId: customerId,
        notes: notes,
      );
      emit(SalesSuccess(orderId));
    } catch (e) {
      emit(SalesError('Gagal memproses transaksi: $e'));
    }
  }
}
