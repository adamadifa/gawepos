import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/inventory_repository.dart';

abstract class InventoryState {}

class InventoryInitial extends InventoryState {}

class InventoryLoading extends InventoryState {}

class InventoryLoaded extends InventoryState {
  final List<Map<String, dynamic>> items;
  InventoryLoaded(this.items);
}

class StockCardLoaded extends InventoryState {
  final List<Map<String, dynamic>> movements;
  StockCardLoaded(this.movements);
}

class InventorySuccess extends InventoryState {}

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

  Future<void> loadStockCard(int productId) async {
    emit(InventoryLoading());
    try {
      final movements = await _repository.getStockMovements(productId);
      emit(StockCardLoaded(movements));
    } catch (e) {
      emit(InventoryError('Gagal memuat kartu stok: $e'));
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
      emit(InventorySuccess());
      await loadInventory();
    } catch (e) {
      emit(InventoryError('Gagal melakukan penyesuaian stok: $e'));
    }
  }
}
