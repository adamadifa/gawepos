import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/tables/data/table_repository.dart';

void main() {
  late AppDatabase db;
  late TableRepository tableRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tableRepo = TableRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Alur Siklus Status Meja F&B', () {
    test('Meja default available -> diubah ke occupied saat ditahan -> diubah kembali ke available', () async {
      final tableId = await tableRepo.insertTable(
        RestaurantTablesCompanion.insert(
          name: 'Meja 01',
          section: const drift.Value('Indoor AC'),
          capacity: const drift.Value(4),
        ),
      );

      // Status awal harus available
      var table = await tableRepo.getTableById(tableId);
      expect(table, isNotNull);
      expect(table!.status, 'available');

      // Saat kasir menahan transaksi (Hold), ubah status menjadi occupied
      await tableRepo.updateTableStatus(tableId, 'occupied');
      table = await tableRepo.getTableById(tableId);
      expect(table!.status, 'occupied');

      // Saat transaksi diselesaikan / checkout / dibatalkan, ubah kembali ke available
      await tableRepo.updateTableStatus(tableId, 'available');
      table = await tableRepo.getTableById(tableId);
      expect(table!.status, 'available');
    });
  });
}
