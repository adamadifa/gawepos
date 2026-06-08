import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import '../../data/return_repository.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';

abstract class ReturnState {}

class ReturnInitial extends ReturnState {}

class ReturnLoading extends ReturnState {}

class ReturnHistoryLoaded extends ReturnState {
  final List<Map<String, dynamic>> salesReturns;
  final List<Map<String, dynamic>> purchaseReturns;
  ReturnHistoryLoaded({required this.salesReturns, required this.purchaseReturns});
}

class ReturnTransactionDetailsLoaded extends ReturnState {
  final bool isSales;
  final dynamic transaction; // Order or Purchase
  final dynamic contact; // Customer or Supplier
  final List<Map<String, dynamic>> items; // List of item details with returned qty
  ReturnTransactionDetailsLoaded({
    required this.isSales,
    required this.transaction,
    required this.contact,
    required this.items,
  });
}

class ReturnSuccess extends ReturnState {
  final String message;
  ReturnSuccess(this.message);
}

class ReturnError extends ReturnState {
  final String message;
  ReturnError(this.message);
}

class ReturnCubit extends Cubit<ReturnState> {
  final ReturnRepository _repository;
  final AppDatabase _db = getIt<AppDatabase>();

  ReturnCubit(this._repository) : super(ReturnInitial());

  // Memuat riwayat retur
  Future<void> loadReturnHistory() async {
    emit(ReturnLoading());
    try {
      final sales = await _repository.getSalesReturns();
      final purchases = await _repository.getPurchaseReturns();
      emit(ReturnHistoryLoaded(salesReturns: sales, purchaseReturns: purchases));
    } catch (e) {
      emit(ReturnError('Gagal memuat riwayat retur: $e'));
    }
  }

  // Mencari transaksi asli (TRX atau PUR) untuk dimuat item-itemnya
  Future<void> searchOriginalTransaction(String refNo, bool isSales) async {
    emit(ReturnLoading());
    try {
      if (isSales) {
        // 1. Cari Order
        final order = await (_db.select(_db.orders)..where((tbl) => tbl.referenceNo.equals(refNo))).getSingleOrNull();
        if (order == null) {
          emit(ReturnError('Transaksi penjualan dengan referensi $refNo tidak ditemukan.'));
          return;
        }

        // 2. Ambil Customer
        Customer? customer;
        if (order.customerId != null) {
          customer = await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(order.customerId!))).getSingleOrNull();
        }

        // 3. Ambil Order Items
        final items = await (_db.select(_db.orderItems)..where((tbl) => tbl.orderId.equals(order.id))).get();

        // 4. Hitung kuantitas yang sudah pernah diretur sebelumnya
        final List<Map<String, dynamic>> itemDetails = [];
        for (var item in items) {
          final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
          final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();

          // Query returned items for this order/product/unit
          final returnQuery = _db.select(_db.salesReturnItems).join([
            innerJoin(_db.salesReturns, _db.salesReturns.id.equalsExp(_db.salesReturnItems.salesReturnId)),
          ])..where(_db.salesReturns.orderId.equals(order.id) & _db.salesReturnItems.productId.equals(item.productId) & _db.salesReturnItems.unitId.equals(item.unitId));

          final returnRows = await returnQuery.get();
          double returnedQty = 0.0;
          for (var row in returnRows) {
            returnedQty += row.readTable(_db.salesReturnItems).quantity;
          }

          itemDetails.add({
            'orderItem': item,
            'product': product,
            'unit': unit,
            'alreadyReturnedQty': returnedQty,
          });
        }

        emit(ReturnTransactionDetailsLoaded(
          isSales: true,
          transaction: order,
          contact: customer,
          items: itemDetails,
        ));
      } else {
        // 1. Cari Purchase
        final purchase = await (_db.select(_db.purchases)..where((tbl) => tbl.referenceNo.equals(refNo))).getSingleOrNull();
        if (purchase == null) {
          emit(ReturnError('Transaksi pembelian dengan referensi $refNo tidak ditemukan.'));
          return;
        }

        // 2. Ambil Supplier
        final supplier = await (_db.select(_db.suppliers)..where((tbl) => tbl.id.equals(purchase.supplierId))).getSingleOrNull();

        // 3. Ambil Purchase Items
        final items = await (_db.select(_db.purchaseItems)..where((tbl) => tbl.purchaseId.equals(purchase.id))).get();

        // 4. Hitung kuantitas yang sudah pernah diretur sebelumnya
        final List<Map<String, dynamic>> itemDetails = [];
        for (var item in items) {
          final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
          final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();

          // Query returned items for this purchase/product/unit
          final returnQuery = _db.select(_db.purchaseReturnItems).join([
            innerJoin(_db.purchaseReturns, _db.purchaseReturns.id.equalsExp(_db.purchaseReturnItems.purchaseReturnId)),
          ])..where(_db.purchaseReturns.purchaseId.equals(purchase.id) & _db.purchaseReturnItems.productId.equals(item.productId) & _db.purchaseReturnItems.unitId.equals(item.unitId));

          final returnRows = await returnQuery.get();
          double returnedQty = 0.0;
          for (var row in returnRows) {
            returnedQty += row.readTable(_db.purchaseReturnItems).quantity;
          }

          itemDetails.add({
            'purchaseItem': item,
            'product': product,
            'unit': unit,
            'alreadyReturnedQty': returnedQty,
          });
        }

        emit(ReturnTransactionDetailsLoaded(
          isSales: false,
          transaction: purchase,
          contact: supplier,
          items: itemDetails,
        ));
      }
    } catch (e) {
      emit(ReturnError('Gagal mencari referensi transaksi: $e'));
    }
  }

  // Submit Retur Penjualan (Customer)
  Future<void> submitSalesReturn({
    int? orderId,
    int? customerId,
    required int cashierSessionId,
    required List<Map<String, dynamic>> items,
    required double refundAmount,
    required String refundMethod,
    String? notes,
  }) async {
    emit(ReturnLoading());
    try {
      await _repository.saveSalesReturn(
        orderId: orderId,
        customerId: customerId,
        cashierSessionId: cashierSessionId,
        items: items,
        refundAmount: refundAmount,
        refundMethod: refundMethod,
        notes: notes,
      );
      emit(ReturnSuccess('Retur Penjualan berhasil disimpan.'));
    } catch (e) {
      emit(ReturnError('Gagal menyimpan retur: $e'));
    }
  }

  // Submit Retur Pembelian (Supplier)
  Future<void> submitPurchaseReturn({
    int? purchaseId,
    required int supplierId,
    required int cashierSessionId,
    required List<Map<String, dynamic>> items,
    required double refundAmount,
    required String refundMethod,
    String? notes,
  }) async {
    emit(ReturnLoading());
    try {
      await _repository.savePurchaseReturn(
        purchaseId: purchaseId,
        supplierId: supplierId,
        cashierSessionId: cashierSessionId,
        items: items,
        refundAmount: refundAmount,
        refundMethod: refundMethod,
        notes: notes,
      );
      emit(ReturnSuccess('Retur Pembelian berhasil disimpan.'));
    } catch (e) {
      emit(ReturnError('Gagal menyimpan retur: $e'));
    }
  }

  // Batalkan/Hapus Retur Penjualan
  Future<void> voidSalesReturn(int returnId) async {
    emit(ReturnLoading());
    try {
      await _repository.deleteSalesReturn(returnId);
      emit(ReturnSuccess('Retur Penjualan berhasil dibatalkan.'));
      loadReturnHistory(); // Refresh history
    } catch (e) {
      emit(ReturnError('Gagal membatalkan retur penjualan: $e'));
    }
  }

  // Batalkan/Hapus Retur Pembelian
  Future<void> voidPurchaseReturn(int returnId) async {
    emit(ReturnLoading());
    try {
      await _repository.deletePurchaseReturn(returnId);
      emit(ReturnSuccess('Retur Pembelian berhasil dibatalkan.'));
      loadReturnHistory(); // Refresh history
    } catch (e) {
      emit(ReturnError('Gagal membatalkan retur pembelian: $e'));
    }
  }

  // Reset to initial state
  void resetState() {
    emit(ReturnInitial());
  }
}
