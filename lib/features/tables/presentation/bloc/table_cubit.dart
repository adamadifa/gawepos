import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/table_repository.dart';

abstract class TableState {}

class TableInitial extends TableState {}

class TableLoading extends TableState {}

class TableLoaded extends TableState {
  final List<RestaurantTable> tables;
  final String selectedSection;

  TableLoaded({
    required this.tables,
    this.selectedSection = 'Semua',
  });

  List<String> get sections {
    final list = tables.map((t) => t.section).toSet().toList();
    list.sort();
    return ['Semua', ...list];
  }

  List<RestaurantTable> get filteredTables {
    if (selectedSection == 'Semua') return tables;
    return tables.where((t) => t.section == selectedSection).toList();
  }

  int get availableCount => tables.where((t) => t.status == 'available').length;
  int get occupiedCount => tables.where((t) => t.status == 'occupied').length;
  int get reservedCount => tables.where((t) => t.status == 'reserved').length;
}

class TableError extends TableState {
  final String message;
  TableError(this.message);
}

class TableCubit extends Cubit<TableState> {
  final TableRepository _repository;

  TableCubit(this._repository) : super(TableInitial());

  Future<void> loadTables() async {
    emit(TableLoading());
    try {
      final tables = await _repository.getAllTables();
      if (tables.isEmpty) {
        await _repository.seedDefaultTables();
        final seeded = await _repository.getAllTables();
        emit(TableLoaded(tables: seeded));
      } else {
        emit(TableLoaded(tables: tables));
      }
    } catch (e) {
      emit(TableError('Gagal memuat data meja: $e'));
    }
  }

  void setSection(String section) {
    if (state is TableLoaded) {
      final current = state as TableLoaded;
      emit(TableLoaded(tables: current.tables, selectedSection: section));
    }
  }

  Future<void> addTable(RestaurantTablesCompanion table) async {
    try {
      await _repository.insertTable(table);
      await loadTables();
    } catch (e) {
      emit(TableError('Gagal menambah meja: $e'));
    }
  }

  Future<void> updateTable(RestaurantTable table) async {
    try {
      await _repository.updateTable(table);
      await loadTables();
    } catch (e) {
      emit(TableError('Gagal mengubah meja: $e'));
    }
  }

  Future<void> updateStatus(int tableId, String status) async {
    try {
      await _repository.updateTableStatus(tableId, status);
      await loadTables();
    } catch (e) {
      emit(TableError('Gagal mengubah status meja: $e'));
    }
  }

  Future<void> deleteTable(int id) async {
    try {
      await _repository.deleteTable(id);
      await loadTables();
    } catch (e) {
      emit(TableError('Gagal menghapus meja: $e'));
    }
  }
}
