import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../data/master_repository.dart';

abstract class SupplierState {}
class SupplierInitial extends SupplierState {}
class SupplierLoading extends SupplierState {}
class SupplierLoaded extends SupplierState {
  final List<Supplier> suppliers;
  SupplierLoaded(this.suppliers);
}
class SupplierError extends SupplierState {
  final String message;
  SupplierError(this.message);
}

class SupplierCubit extends Cubit<SupplierState> {
  final MasterRepository _repository;

  SupplierCubit(this._repository) : super(SupplierInitial());

  Future<void> loadSuppliers() async {
    emit(SupplierLoading());
    try {
      final suppliers = await _repository.getSuppliers();
      emit(SupplierLoaded(suppliers));
    } catch (e) {
      emit(SupplierError('Gagal memuat pemasok: $e'));
    }
  }

  Future<void> addSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      await _repository.insertSupplier(
        SuppliersCompanion.insert(
          name: name,
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
        ),
      );
      await loadSuppliers();
    } catch (e) {
      emit(SupplierError('Gagal menambah pemasok: $e'));
    }
  }

  Future<void> editSupplier(
    Supplier supplier, {
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      await _repository.updateSupplier(
        supplier.copyWith(
          name: name,
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
        ),
      );
      await loadSuppliers();
    } catch (e) {
      emit(SupplierError('Gagal mengubah pemasok: $e'));
    }
  }

  Future<void> deleteSupplier(int id) async {
    try {
      await _repository.deleteSupplier(id);
      await loadSuppliers();
    } catch (e) {
      emit(SupplierError('Gagal menghapus pemasok: $e'));
    }
  }
}
