import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// 1. Profil Outlet
class Outlets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get taxPercentage => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 2. Akun Pengguna (Kasir & Admin)
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get username => text().withLength(min: 3, max: 50).unique()();
  TextColumn get pinHash => text()(); // Hash PIN lokal (SHA-256)
  TextColumn get role => text().withDefault(const Constant('cashier'))(); // 'admin' / 'cashier'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 3. Kategori Produk
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 4. Merek Produk (Brands)
class Brands extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 5. Produk
@TableIndex(name: 'products_barcode_idx', columns: {#barcode})
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get brandId => integer().nullable().references(Brands, #id, onDelete: KeyAction.setNull)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get sku => text().nullable().unique()();
  TextColumn get barcode => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get imagePath => text().nullable()(); // File path gambar lokal
  TextColumn get productType => text().withDefault(const Constant('goods'))(); // 'goods' / 'service'
  BoolColumn get isStockManaged => boolean().withDefault(const Constant(true))();
  IntColumn get minStockAlert => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 6. Satuan Unit Produk (Pcs, Box, dst.)
class ProductUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  RealColumn get conversionFactor => real().withDefault(const Constant(1.0))();
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
}

// 7. Tingkat Harga (Price Tiers)
class PriceTiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
}

// 8. Matriks Harga Jual Produk
class ProductPrices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  IntColumn get unitId => integer().references(ProductUnits, #id, onDelete: KeyAction.cascade)();
  IntColumn get priceTierId => integer().references(PriceTiers, #id, onDelete: KeyAction.cascade)();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  IntColumn get minQty => integer().withDefault(const Constant(1))();
}

// 9. Pelanggan (Customers)
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
}

// 10. Pemasok (Suppliers)
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
}

// 11. Stok Inventori Aktif
class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  IntColumn get unitId => integer().references(ProductUnits, #id, onDelete: KeyAction.cascade)();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
}

// 12. Mutasi Keluar-Masuk Stok
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()(); // Positif untuk masuk, Negatif untuk keluar
  TextColumn get type => text()(); // 'sale', 'purchase', 'opname', 'void'
  TextColumn get referenceNo => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 13. Sesi Kasir (Shift)
class CashierSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get openTime => dateTime()();
  DateTimeColumn get closeTime => dateTime().nullable()();
  RealColumn get openingCash => real()();
  RealColumn get closingCash => real().nullable()();
  RealColumn get expectedCash => real().nullable()();
  RealColumn get differenceAmount => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('open'))(); // 'open' / 'closed'
}

// 14. Transaksi Penjualan (Orders)
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();
  IntColumn get cashierSessionId => integer().references(CashierSessions, #id)();
  TextColumn get referenceNo => text().unique()(); // TRX-YYYYMMDD-XXXX
  TextColumn get status => text().withDefault(const Constant('completed'))(); // 'completed' / 'void'
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('paid'))(); // 'paid' / 'partial' / 'unpaid'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 15. Item Detail Penjualan
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get subtotal => real()();
}

// 16. Metode Pembayaran Detail
class OrderPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  TextColumn get paymentMethod => text()(); // 'cash', 'qris', 'card', 'transfer'
  RealColumn get amount => real()();
  TextColumn get referenceId => text().nullable()();
}

// 17. Draft Penjualan Ditahan (Hold / Recall)
class PosHeldOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();
  TextColumn get referenceNo => text()();
  TextColumn get cartData => text()(); // JSON string representasi keranjang belanja
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 18. Pengeluaran Toko (Expenses)
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get categoryName => text()(); // e.g., 'Operasional', 'Listrik', 'Lainnya'
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

// 19. Konfigurasi Sistem (Settings)
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text().nullable()();
}

// 20. Pembelian dari Supplier
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  TextColumn get referenceNo => text().unique()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'ordered', 'received'
  TextColumn get paymentType => text().withDefault(const Constant('cash'))(); // 'cash' / 'debt'
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  RealColumn get downPayment => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()();
  RealColumn get costPrice => real()();
  RealColumn get subtotal => real()();
}

// 21. Hak Akses Role (Role Permissions)
class RolePermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text().withLength(min: 3, max: 50).unique()(); // 'admin', 'cashier', etc.
  TextColumn get allowedMenus => text()(); // JSON string array, e.g., '["pos", "history"]'
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// 22. Piutang Pelanggan (Customer Debts / Bon)
class CustomerDebts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderId => integer().nullable().references(Orders, #id, onDelete: KeyAction.setNull)();
  RealColumn get amount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))(); // 'unpaid', 'partial', 'paid'
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CustomerDebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerDebtId => integer().references(CustomerDebts, #id, onDelete: KeyAction.cascade)();
  RealColumn get amountPaid => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))(); // 'cash', 'transfer', etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 23. Hutang ke Supplier (Supplier Debts)
class SupplierDebts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  IntColumn get purchaseId => integer().nullable().references(Purchases, #id, onDelete: KeyAction.setNull)();
  RealColumn get amount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))(); // 'unpaid', 'partial', 'paid'
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SupplierDebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierDebtId => integer().references(SupplierDebts, #id, onDelete: KeyAction.cascade)();
  RealColumn get amountPaid => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 24. Retur Penjualan (Customer Returns)
class SalesReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().nullable().references(Orders, #id, onDelete: KeyAction.setNull)();
  IntColumn get customerId => integer().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();
  IntColumn get cashierSessionId => integer().references(CashierSessions, #id)();
  TextColumn get referenceNo => text().unique()(); // RET-SLS-YYYYMMDD-XXXX
  RealColumn get refundAmount => real().withDefault(const Constant(0.0))();
  TextColumn get refundMethod => text().withDefault(const Constant('cash'))(); // 'cash' / 'debt_reduction'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SalesReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get salesReturnId => integer().references(SalesReturns, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get subtotal => real()();
}

// 25. Retur Pembelian (Supplier Returns)
class PurchaseReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().nullable().references(Purchases, #id, onDelete: KeyAction.setNull)();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  IntColumn get cashierSessionId => integer().references(CashierSessions, #id)();
  TextColumn get referenceNo => text().unique()(); // RET-PUR-YYYYMMDD-XXXX
  RealColumn get refundAmount => real().withDefault(const Constant(0.0))();
  TextColumn get refundMethod => text().withDefault(const Constant('cash'))(); // 'cash' / 'debt_reduction'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseReturnId => integer().references(PurchaseReturns, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()();
  RealColumn get costPrice => real()();
  RealColumn get subtotal => real()();
}

@DriftDatabase(tables: [
  Outlets,
  Users,
  Categories,
  Brands,
  Products,
  ProductUnits,
  PriceTiers,
  ProductPrices,
  Customers,
  Suppliers,
  Inventory,
  StockMovements,
  CashierSessions,
  Orders,
  OrderItems,
  OrderPayments,
  PosHeldOrders,
  Expenses,
  Settings,
  Purchases,
  PurchaseItems,
  RolePermissions,
  CustomerDebts,
  CustomerDebtPayments,
  SupplierDebts,
  SupplierDebtPayments,
  SalesReturns,
  SalesReturnItems,
  PurchaseReturns,
  PurchaseReturnItems,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(rolePermissions);
          }
          if (from < 3) {
            await m.createTable(customerDebts);
            await m.createTable(customerDebtPayments);
            await m.createTable(supplierDebts);
            await m.createTable(supplierDebtPayments);
            await m.addColumn(purchases, purchases.paymentType);
          }
          if (from < 4) {
            await m.addColumn(purchases, purchases.downPayment);
          }
          if (from < 5) {
            await m.createTable(salesReturns);
            await m.createTable(salesReturnItems);
            await m.createTable(purchaseReturns);
            await m.createTable(purchaseReturnItems);
          }
        },
        beforeOpen: (details) async {
          // Fix any missing payment_type column or null values in purchases
          try {
            final columns = await customSelect("PRAGMA table_info(purchases);").get();
            final hasPaymentType = columns.any((row) => row.read<String>('name') == 'payment_type');
            if (!hasPaymentType) {
              await customStatement("ALTER TABLE purchases ADD COLUMN payment_type TEXT DEFAULT 'cash';");
            }
            await customStatement("UPDATE purchases SET payment_type = 'cash' WHERE payment_type IS NULL;");

            final hasDownPayment = columns.any((row) => row.read<String>('name') == 'down_payment');
            if (!hasDownPayment) {
              await customStatement("ALTER TABLE purchases ADD COLUMN down_payment REAL DEFAULT 0.0;");
            }
            await customStatement("UPDATE purchases SET down_payment = 0.0 WHERE down_payment IS NULL;");
          } catch (_) {}

          if (details.wasCreated || (details.hadUpgrade && (details.versionBefore ?? 0) < 2)) {
            final adminExists = await (select(rolePermissions)..where((tbl) => tbl.role.equals('admin'))).getSingleOrNull();
            if (adminExists == null) {
              await into(rolePermissions).insert(
                RolePermissionsCompanion.insert(
                  role: 'admin',
                  allowedMenus: '["pos","products","expenses","restock","opname","history","reports","contacts","settings","users","returns"]',
                ),
              );
            }
            final cashierExists = await (select(rolePermissions)..where((tbl) => tbl.role.equals('cashier'))).getSingleOrNull();
            if (cashierExists == null) {
              await into(rolePermissions).insert(
                RolePermissionsCompanion.insert(
                  role: 'cashier',
                  allowedMenus: '["pos","history","contacts","returns"]',
                ),
              );
            }
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'posmobile.db'));
    return NativeDatabase.createInBackground(file);
  });
}
