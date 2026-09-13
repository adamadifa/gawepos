import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class TableRepository {
  final AppDatabase _db;

  TableRepository(this._db);

  // ─── GET ALL TABLES ────────────────────────────────────────────────
  Future<List<RestaurantTable>> getAllTables() async {
    return await (_db.select(_db.restaurantTables)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.section),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .get();
  }

  // ─── GET TABLE BY ID ──────────────────────────────────────────────
  Future<RestaurantTable?> getTableById(int id) async {
    return await (_db.select(_db.restaurantTables)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  // ─── WATCH TABLES (STREAM) ─────────────────────────────────────────
  Stream<List<RestaurantTable>> watchTables() {
    return (_db.select(_db.restaurantTables)
          ..where((tbl) => tbl.isActive.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.section),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  // ─── INSERT TABLE ──────────────────────────────────────────────────
  Future<int> insertTable(RestaurantTablesCompanion table) async {
    return await _db.into(_db.restaurantTables).insert(table);
  }

  // ─── UPDATE TABLE ──────────────────────────────────────────────────
  Future<bool> updateTable(RestaurantTable table) async {
    return await _db.update(_db.restaurantTables).replace(table);
  }

  // ─── UPDATE STATUS MEJA ───────────────────────────────────────────
  Future<int> updateTableStatus(int tableId, String status) async {
    return await (_db.update(_db.restaurantTables)..where((tbl) => tbl.id.equals(tableId))).write(
      RestaurantTablesCompanion(status: Value(status)),
    );
  }

  // ─── DELETE / SOFT-DELETE TABLE ───────────────────────────────────
  Future<int> deleteTable(int id) async {
    return await (_db.update(_db.restaurantTables)..where((tbl) => tbl.id.equals(id))).write(
      const RestaurantTablesCompanion(isActive: Value(false)),
    );
  }

  // ─── QUICK SEED DUMMY TABLES (MEJA 01 - MEJA 12) ───────────────────
  Future<int> seedDefaultTables() async {
    final existing = await _db.select(_db.restaurantTables).get();
    if (existing.isNotEmpty) return 0;

    final defaultList = [
      // Area Utama (Indoor AC)
      RestaurantTablesCompanion.insert(name: 'Meja 01', section: const Value('Indoor AC'), capacity: const Value(2)),
      RestaurantTablesCompanion.insert(name: 'Meja 02', section: const Value('Indoor AC'), capacity: const Value(4)),
      RestaurantTablesCompanion.insert(name: 'Meja 03', section: const Value('Indoor AC'), capacity: const Value(4)),
      RestaurantTablesCompanion.insert(name: 'Meja 04', section: const Value('Indoor AC'), capacity: const Value(6)),
      RestaurantTablesCompanion.insert(name: 'Meja 05', section: const Value('Indoor AC'), capacity: const Value(6)),
      
      // Area Outdoor / Smoking
      RestaurantTablesCompanion.insert(name: 'Outdoor 01', section: const Value('Outdoor'), capacity: const Value(4)),
      RestaurantTablesCompanion.insert(name: 'Outdoor 02', section: const Value('Outdoor'), capacity: const Value(4)),
      RestaurantTablesCompanion.insert(name: 'Outdoor 03', section: const Value('Outdoor'), capacity: const Value(6)),
      
      // Lantai 2 / Lesehan
      RestaurantTablesCompanion.insert(name: 'Lesehan 01', section: const Value('Lantai 2'), capacity: const Value(4)),
      RestaurantTablesCompanion.insert(name: 'Lesehan 02', section: const Value('Lantai 2'), capacity: const Value(4)),
      RestaurantTablesCompanion.insert(name: 'VIP Room', section: const Value('VIP'), capacity: const Value(10)),
      RestaurantTablesCompanion.insert(name: 'Bar Counter', section: const Value('Bar'), capacity: const Value(2)),
    ];

    int count = 0;
    for (final t in defaultList) {
      await _db.into(_db.restaurantTables).insert(t);
      count++;
    }
    return count;
  }
}
