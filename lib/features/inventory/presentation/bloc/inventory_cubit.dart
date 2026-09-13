import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/inventory_repository.dart';
import '../../../../core/database/app_database.dart';

abstract class InventoryState {}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<Map<String, dynamic>> items;
  InventoryLoaded(this.items);
}

class StockCardLoaded extends InventoryState {
  final List<Map<String, dynamic>> movements;
  final List<ProductUnit> units;
  StockCardLoaded(this.movements, this.units);
}

class AdjustmentHistoryLoaded extends InventoryState {
  final List<Map<String, dynamic>> history;
  AdjustmentHistoryLoaded(this.history);
}

class InventorySuccess extends InventoryState {
  final String? message;
  InventorySuccess([this.message]);
}

class InventoryError extends InventoryState {
  final String message;
  InventoryError(this.message);
}

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository _repository;

  InventoryCubit(this._repository) : super(InventoryInitial());

  Future<void> loadInventory() async {
    emit(InventoryLoading());
    try {
      final items = await _repository.getProductUnitsWithStock();
      emit(InventoryLoaded(items));
    } catch (e) {
      emit(InventoryError('Gagal memuat data stok: $e'));
    }
  }

  Future<void> loadStockCard(int productId, {DateTime? start, DateTime? end}) async {
    emit(InventoryLoading());
    try {
      final movements = await _repository.getStockMovements(productId, start: start, end: end);
      final units = await _repository.getProductUnits(productId);
      emit(StockCardLoaded(movements, units));
    } catch (e) {
      emit(InventoryError('Gagal memuat kartu stok: $e'));
    }
  }

  Future<void> loadAdjustmentHistory({DateTime? start, DateTime? end, String? search}) async {
    emit(InventoryLoading());
    try {
      final history = await _repository.getAdjustmentHistory(start: start, end: end, search: search);
      emit(AdjustmentHistoryLoaded(history));
    } catch (e) {
      emit(InventoryError('Gagal memuat riwayat penyesuaian: $e'));
    }
  }

  Future<void> deleteAdjustmentMovement(int movementId, {DateTime? start, DateTime? end, String? search}) async {
    emit(InventoryLoading());
    try {
      await _repository.deleteAdjustmentMovement(movementId);
      emit(InventorySuccess('Penyesuaian stok berhasil dibatalkan & stok dikembalikan.'));
      await loadAdjustmentHistory(start: start, end: end, search: search);
    } catch (e) {
      emit(InventoryError('Gagal membatalkan penyesuaian stok: $e'));
    }
  }

  Future<void> adjustStock({
    required int productId,
    required int unitId,
    required double theoreticalQty,
    required double physicalQty,
    String? notes,
  }) async {
    emit(InventoryLoading());
    try {
      await _repository.adjustStock(
        productId: productId,
        unitId: unitId,
        theoreticalQty: theoreticalQty,
        physicalQty: physicalQty,
        notes: notes,
      );
      emit(InventorySuccess('Penyesuaian stok opname berhasil disimpan.'));
      await loadInventory();
    } catch (e) {
      emit(InventoryError('Gagal melakukan penyesuaian stok: $e'));
    }
  }

  Future<void> adjustStockMultiple({
    required int productId,
    required List<Map<String, dynamic>> adjustments,
    String? notes,
  }) async {
    emit(InventoryLoading());
    try {
      for (var adj in adjustments) {
        await _repository.adjustStock(
          productId: productId,
          unitId: adj['unitId'] as int,
          theoreticalQty: adj['theoreticalQty'] as double,
          physicalQty: adj['physicalQty'] as double,
          notes: notes,
        );
      }
      emit(InventorySuccess('Penyesuaian stok opname berhasil disimpan.'));
      await loadInventory();
    } catch (e) {
      emit(InventoryError('Gagal melakukan penyesuaian stok: $e'));
    }
  }

  Future<void> adjustStockManual({
    required int productId,
    required int unitId,
    required double quantity,
    required bool isAddition,
    String? notes,
  }) async {
    emit(InventoryLoading());
    try {
      await _repository.adjustStockManual(
        productId: productId,
        unitId: unitId,
        quantity: quantity,
        isAddition: isAddition,
        notes: notes,
      );
      emit(InventorySuccess('Penyesuaian stok manual berhasil disimpan.'));
      await loadInventory();
    } catch (e) {
      emit(InventoryError('Gagal melakukan penyesuaian stok manual: $e'));
    }
  }
}
