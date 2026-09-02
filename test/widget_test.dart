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

  group('Hutang & Piutang Database Logic Test', () {
    test('Pencatatan dan pelunasan piutang pelanggan (Customer Debt)', () async {
      final now = DateTime.now();

      // 1. Buat data master
      final custId = await db.into(db.customers).insert(
            CustomersCompanion.insert(
              name: 'Pelanggan Uji',
              phone: const Value('081234567890'),
            ),
          );

      // 2. Catat Piutang Rp 100.000
      final debtId = await db.into(db.customerDebts).insert(
            CustomerDebtsCompanion.insert(
              customerId: custId,
              amount: 100000.0,
              paidAmount: const Value(0.0),
              status: const Value('unpaid'),
              createdAt: Value(now),
            ),
          );

      var debt = await (db.select(db.customerDebts)..where((tbl) => tbl.id.equals(debtId))).getSingle();
      expect(debt.amount, equals(100000.0));
      expect(debt.paidAmount, equals(0.0));
      expect(debt.status, equals('unpaid'));

      // 3. Cicil bayar Rp 40.000
      await db.into(db.customerDebtPayments).insert(
            CustomerDebtPaymentsCompanion.insert(
              customerDebtId: debtId,
              amountPaid: 40000.0,
              paymentMethod: const Value('cash'),
              createdAt: Value(now),
            ),
          );
      await db.update(db.customerDebts).replace(
            debt.copyWith(
              paidAmount: 40000.0,
              status: 'partial',
            ),
          );

      debt = await (db.select(db.customerDebts)..where((tbl) => tbl.id.equals(debtId))).getSingle();
      expect(debt.paidAmount, equals(40000.0));
      expect(debt.status, equals('partial'));
      expect(debt.amount - debt.paidAmount, equals(60000.0));

      // 4. Lunasi sisa Rp 60.000
      await db.into(db.customerDebtPayments).insert(
            CustomerDebtPaymentsCompanion.insert(
              customerDebtId: debtId,
              amountPaid: 60000.0,
              paymentMethod: const Value('transfer'),
              createdAt: Value(now),
            ),
          );
      await db.update(db.customerDebts).replace(
            debt.copyWith(
              paidAmount: 100000.0,
              status: 'paid',
            ),
          );

      debt = await (db.select(db.customerDebts)..where((tbl) => tbl.id.equals(debtId))).getSingle();
      expect(debt.paidAmount, equals(100000.0));
      expect(debt.status, equals('paid'));
      expect(debt.amount - debt.paidAmount, equals(0.0));

      // 5. Cek riwayat pembayaran cicilan
      final payments = await (db.select(db.customerDebtPayments)..where((tbl) => tbl.customerDebtId.equals(debtId))).get();
      expect(payments.length, equals(2));
      expect(payments[0].amountPaid, equals(40000.0));
      expect(payments[1].amountPaid, equals(60000.0));
    });

    test('Pencatatan dan pelunasan hutang supplier (Supplier Debt)', () async {
      final now = DateTime.now();

      final suppId = await db.into(db.suppliers).insert(
            SuppliersCompanion.insert(
              name: 'Supplier Utama',
              phone: const Value('089876543210'),
            ),
          );

      final debtId = await db.into(db.supplierDebts).insert(
            SupplierDebtsCompanion.insert(
              supplierId: suppId,
              amount: 500000.0,
              paidAmount: const Value(0.0),
              status: const Value('unpaid'),
              createdAt: Value(now),
            ),
          );

      var debt = await (db.select(db.supplierDebts)..where((tbl) => tbl.id.equals(debtId))).getSingle();
      expect(debt.amount, equals(500000.0));
      expect(debt.status, equals('unpaid'));

      // Bayar Rp 500.000 (Lunas)
      await db.into(db.supplierDebtPayments).insert(
            SupplierDebtPaymentsCompanion.insert(
              supplierDebtId: debtId,
              amountPaid: 500000.0,
              paymentMethod: const Value('transfer'),
              createdAt: Value(now),
            ),
          );
      await db.update(db.supplierDebts).replace(
            debt.copyWith(
              paidAmount: 500000.0,
              status: 'paid',
            ),
          );

      debt = await (db.select(db.supplierDebts)..where((tbl) => tbl.id.equals(debtId))).getSingle();
      expect(debt.paidAmount, equals(500000.0));
      expect(debt.status, equals('paid'));
    });
  });
}
