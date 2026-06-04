import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/expenses_repository.dart';
import '../../../../core/database/app_database.dart';

abstract class ExpensesState {}

class ExpensesInitial extends ExpensesState {}

class ExpensesLoading extends ExpensesState {}

class ExpensesLoaded extends ExpensesState {
  final List<Expense> expenses;
  ExpensesLoaded(this.expenses);
}

class ExpensesSuccess extends ExpensesState {}

class ExpensesError extends ExpensesState {
  final String message;
  ExpensesError(this.message);
}

class ExpensesCubit extends Cubit<ExpensesState> {
  final ExpensesRepository _repository;

  ExpensesCubit(this._repository) : super(ExpensesInitial());

  Future<void> loadExpenses() async {
    emit(ExpensesLoading());
    try {
      final list = await _repository.getExpenses();
      emit(ExpensesLoaded(list));
    } catch (e) {
      emit(ExpensesError('Gagal memuat daftar biaya: $e'));
    }
  }

  Future<void> addExpense({
    required String categoryName,
    required double amount,
    required String? description,
  }) async {
    emit(ExpensesLoading());
    try {
      await _repository.addExpense(
        categoryName: categoryName,
        amount: amount,
        description: description,
      );
      final list = await _repository.getExpenses();
      emit(ExpensesLoaded(list));
    } catch (e) {
      emit(ExpensesError('Gagal menambahkan biaya: $e'));
    }
  }

  Future<void> deleteExpense(int id) async {
    emit(ExpensesLoading());
    try {
      await _repository.deleteExpense(id);
      final list = await _repository.getExpenses();
      emit(ExpensesLoaded(list));
    } catch (e) {
      emit(ExpensesError('Gagal menghapus biaya: $e'));
    }
  }
}
