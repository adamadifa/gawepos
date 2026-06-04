import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ExpensesRepository {
  final AppDatabase _db;

  ExpensesRepository(this._db);

  Future<List<Expense>> getExpenses() async {
    return await (_db.select(_db.expenses)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> addExpense({
    required String categoryName,
    required double amount,
    required String? description,
  }) async {
    return await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            categoryName: categoryName,
            amount: amount,
            description: Value(description),
            date: Value(DateTime.now()),
          ),
        );
  }

  Future<void> deleteExpense(int id) async {
    await (_db.delete(_db.expenses)..where((tbl) => tbl.id.equals(id))).go();
  }
}
