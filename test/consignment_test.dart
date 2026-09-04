import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/consignment/data/consignment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ConsignmentRepository consignmentRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    consignmentRepo = ConsignmentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Consignment & Settlement Integration Tests', () {
    test('Kalkulasi bagi hasil konsinyasi bertipe commission_percent dan fixed_cost', () async {
      // 1. Insert User & Cashier Session
      final userId = await db.into(db.users).insert(
        UsersCompanion.insert(
          name: 'Kasir Konsinyasi',
          username: 'kasir_konsinyasi',
          pinHash: 'hash',
        ),
      );

      final sessionId = await db.into(db.cashierSessions).insert(
        CashierSessionsCompanion.insert(
          userId: userId,
          openTime: DateTime.now(),
          openingCash: 100000.0,
        ),
      );

      // 2. Insert Supplier / Penitip
      final supplierId = await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(
          name: 'Mitra Bakery Bandung',
          phone: const Value('08123456789'),
        ),
      );

      // 3. Insert Produk Konsinyasi:
      // Product A: Commission 20% (Harga Jual 10.000 -> Hak Toko 2.000, Hak Penitip 8.000)
      final prodAId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          name: 'Roti Coklat Spesial',
          isConsignment: const Value(true),
          supplierId: Value(supplierId),
          consignmentType: const Value('commission_percent'),
          commissionRate: const Value(20.0), // 20%
        ),
      );

      final unitAId = await db.into(db.productUnits).insert(
        ProductUnitsCompanion.insert(
          productId: prodAId,
          name: 'Pcs',
          conversionFactor: const Value(1.0),
          isBase: const Value(true),
        ),
      );

      // Product B: Fixed Setor Rp 12.000 (Harga Jual 15.000 -> Hak Toko 3.000, Hak Penitip 12.000)
      final prodBId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          name: 'Bolu Gulung Keju',
          isConsignment: const Value(true),
          supplierId: Value(supplierId),
          consignmentType: const Value('fixed_cost'),
          commissionRate: const Value(12000.0), // Harga setor Rp 12.000
        ),
      );

      final unitBId = await db.into(db.productUnits).insert(
        ProductUnitsCompanion.insert(
          productId: prodBId,
          name: 'Pcs',
          conversionFactor: const Value(1.0),
          isBase: const Value(true),
        ),
      );

      // 4. Simulasi Transaksi POS:
      // Jual 5 pcs Roti Coklat (@10.000 = 50.000) & 2 pcs Bolu Gulung (@15.000 = 30.000)
      final orderId = await db.into(db.orders).insert(
        OrdersCompanion.insert(
          userId: userId,
          cashierSessionId: sessionId,
          referenceNo: 'TRX-TEST-CSL-001',
          subtotal: const Value(80000.0),
          grandTotal: const Value(80000.0),
          paidAmount: const Value(80000.0),
          status: const Value('completed'),
        ),
      );

      await db.into(db.orderItems).insert(
        OrderItemsCompanion.insert(
          orderId: orderId,
          productId: prodAId,
          unitId: unitAId,
          quantity: 5.0,
          price: 10000.0,
          subtotal: 50000.0,
        ),
      );

      await db.into(db.orderItems).insert(
        OrderItemsCompanion.insert(
          orderId: orderId,
          productId: prodBId,
          unitId: unitBId,
          quantity: 2.0,
          price: 15000.0,
          subtotal: 30000.0,
        ),
      );

      // 5. Verifikasi Unsettled Calculation
      final unsettled = await consignmentRepo.getUnsettledItemsForSupplier(supplierId);
      expect(unsettled.length, equals(2));

      final itemA = unsettled.firstWhere((i) => i.product.id == prodAId);
      expect(itemA.soldQty, equals(5.0));
      expect(itemA.totalSalesAmount, equals(50000.0));
      expect(itemA.supplierPayable, equals(40000.0)); // 5 * 8.000
      expect(itemA.storeCommission, equals(10000.0)); // 5 * 2.000

      final itemB = unsettled.firstWhere((i) => i.product.id == prodBId);
      expect(itemB.soldQty, equals(2.0));
      expect(itemB.totalSalesAmount, equals(30000.0));
      expect(itemB.supplierPayable, equals(24000.0)); // 2 * 12.000
      expect(itemB.storeCommission, equals(6000.0)); // 30.000 - 24.000

      // 6. Buat Settlement Baru (Total Hak Penitip: 40.000 + 24.000 = 64.000)
      final settlementId = await consignmentRepo.createSettlement(
        supplierId: supplierId,
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        items: unsettled,
        paidAmount: 64000.0,
        paymentMethod: 'cash',
        notes: 'Settlement Uji Coba',
      );

      expect(settlementId, greaterThan(0));

      // 7. Verifikasi Settlement Detail
      final detail = await consignmentRepo.getSettlementDetail(settlementId);
      expect(detail, isNotNull);
      final settlement = detail!['settlement'] as ConsignmentSettlement;
      expect(settlement.supplierPayableAmount, equals(64000.0));
      expect(settlement.storeCommissionAmount, equals(16000.0));
      expect(settlement.paymentStatus, equals('paid'));

      // 8. Setelah di-settle, unsettled balance harus menjadi 0
      final unsettledAfter = await consignmentRepo.getUnsettledItemsForSupplier(supplierId);
      expect(unsettledAfter.isEmpty, isTrue);
    });
  });
}
