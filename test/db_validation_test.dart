import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Foreign Key Cascade', () {
    test('Menghapus order otomatis menghapus order_items', () async {
      final now = DateTime.now();

      final userId = await db.into(db.users).insert(UsersCompanion.insert(
        name: 'Test User',
        username: 'test',
        pinHash: 'hash',
        role: const Value('admin'),
      ));
      final sessionId = await db.into(db.cashierSessions).insert(
        CashierSessionsCompanion.insert(
          userId: userId,
          openTime: now,
          openingCash: 0,
          status: const Value('open'),
        ),
      );

      final catId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Test'),
      );
      final prodId = await db.into(db.products).insert(ProductsCompanion.insert(
        name: 'Test Product',
        categoryId: Value(catId),
        isStockManaged: const Value(false),
      ));
      final unitId = await db.into(db.productUnits).insert(
        ProductUnitsCompanion.insert(
          productId: prodId,
          name: 'Pcs',
          conversionFactor: const Value(1.0),
          isBase: const Value(true),
        ),
      );

      await db.transaction(() async {
        final orderId = await db.into(db.orders).insert(OrdersCompanion.insert(
          userId: userId,
          cashierSessionId: sessionId,
          referenceNo: 'TRX-CASCADE-001',
          subtotal: const Value(10000),
          grandTotal: const Value(10000),
          paidAmount: const Value(10000),
          status: const Value('completed'),
          createdAt: Value(now),
        ));
        await db.into(db.orderItems).insert(OrderItemsCompanion.insert(
          orderId: orderId,
          productId: prodId,
          unitId: unitId,
          quantity: 1,
          price: 10000.0,
          subtotal: 10000.0,
        ));
      });

      final itemsBeforeDelete = await db.select(db.orderItems).get();
      expect(itemsBeforeDelete.length, equals(1));

      await db.delete(db.orders).go();

      final itemsAfterDelete = await db.select(db.orderItems).get();
      expect(itemsAfterDelete.length, equals(0));
    });
  });

  group('Index Optimasi', () {
    test('Query orders by cashier_session_id pakai index orders_session_idx', () async {
      final now = DateTime.now();

      final userId = await db.into(db.users).insert(UsersCompanion.insert(
        name: 'Test User',
        username: 'test',
        pinHash: 'hash',
        role: const Value('admin'),
      ));
      final sessionId = await db.into(db.cashierSessions).insert(
        CashierSessionsCompanion.insert(
          userId: userId,
          openTime: now,
          openingCash: 0,
          status: const Value('open'),
        ),
      );

      await db.into(db.orders).insert(OrdersCompanion.insert(
        userId: userId,
        cashierSessionId: sessionId,
        referenceNo: 'TRX-001',
        subtotal: const Value(10000),
        grandTotal: const Value(10000),
        paidAmount: const Value(10000),
        status: const Value('completed'),
        createdAt: Value(now),
      ));

      final result = await db.customSelect(
        'EXPLAIN QUERY PLAN SELECT id FROM orders WHERE cashier_session_id = ?',
        variables: [Variable.withInt(sessionId)],
      ).get();

      final plan = result.first.data['detail'] as String;
      expect(plan, contains('orders_session_idx'));
    });
  });
}
