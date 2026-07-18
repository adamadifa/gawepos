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
@TableIndex(name: 'products_name_idx', columns: {#name})
@TableIndex(name: 'products_sku_idx', columns: {#sku})
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
  BoolColumn get allowManualPrice => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 6. Satuan Unit Produk (Pcs, Box, dst.)
@TableIndex(name: 'product_units_product_idx', columns: {#productId})
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
@TableIndex(name: 'product_prices_product_unit_tier_idx', columns: {#productId, #unitId, #priceTierId})
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
  IntColumn get pointsBalance => integer().withDefault(const Constant(0))();
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
@TableIndex(name: 'inventory_product_unit_idx', columns: {#productId, #unitId})
class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  IntColumn get unitId => integer().references(ProductUnits, #id, onDelete: KeyAction.cascade)();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
}

// 12. Mutasi Keluar-Masuk Stok
@TableIndex(name: 'stock_movements_product_idx', columns: {#productId})
@TableIndex(name: 'stock_movements_created_idx', columns: {#createdAt})
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
@TableIndex(name: 'cashier_sessions_user_idx', columns: {#userId})
@TableIndex(name: 'cashier_sessions_status_idx', columns: {#status})
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
@TableIndex(name: 'orders_session_idx', columns: {#cashierSessionId})
@TableIndex(name: 'orders_status_idx', columns: {#status})
@TableIndex(name: 'orders_created_idx', columns: {#createdAt})
@TableIndex(name: 'orders_customer_idx', columns: {#customerId})
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
@TableIndex(name: 'order_items_order_idx', columns: {#orderId})
@TableIndex(name: 'order_items_product_idx', columns: {#productId})
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  IntColumn get minQtyApplied => integer().withDefault(const Constant(1))();
  RealColumn get subtotal => real()();
}

// 16. Metode Pembayaran Detail
@TableIndex(name: 'order_payments_order_idx', columns: {#orderId})
class OrderPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  TextColumn get paymentMethod => text()(); // 'cash', 'qris', 'card', 'transfer'
  RealColumn get amount => real()();
  TextColumn get referenceId => text().nullable()();
}

// 17. Draft Penjualan Ditahan (Hold / Recall)
@TableIndex(name: 'pos_held_orders_user_idx', columns: {#userId})
class PosHeldOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();
  TextColumn get referenceNo => text()();
  TextColumn get cartData => text()(); // JSON string representasi keranjang belanja
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 18. Pengeluaran Toko (Expenses)
@TableIndex(name: 'expenses_date_idx', columns: {#date})
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
@TableIndex(name: 'purchases_supplier_idx', columns: {#supplierId})
@TableIndex(name: 'purchases_status_idx', columns: {#status})
@TableIndex(name: 'purchases_created_idx', columns: {#createdAt})
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

@TableIndex(name: 'purchase_items_purchase_idx', columns: {#purchaseId})
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
@TableIndex(name: 'customer_debts_customer_idx', columns: {#customerId})
@TableIndex(name: 'customer_debts_order_idx', columns: {#orderId})
@TableIndex(name: 'customer_debts_status_idx', columns: {#status})
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

@TableIndex(name: 'customer_debt_payments_debt_idx', columns: {#customerDebtId})
class CustomerDebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerDebtId => integer().references(CustomerDebts, #id, onDelete: KeyAction.cascade)();
  RealColumn get amountPaid => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))(); // 'cash', 'transfer', etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 23. Hutang ke Supplier (Supplier Debts)
@TableIndex(name: 'supplier_debts_supplier_idx', columns: {#supplierId})
@TableIndex(name: 'supplier_debts_purchase_idx', columns: {#purchaseId})
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

@TableIndex(name: 'supplier_debt_payments_debt_idx', columns: {#supplierDebtId})
class SupplierDebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierDebtId => integer().references(SupplierDebts, #id, onDelete: KeyAction.cascade)();
  RealColumn get amountPaid => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// 24. Retur Penjualan (Customer Returns)
@TableIndex(name: 'sales_returns_session_idx', columns: {#cashierSessionId})
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

@TableIndex(name: 'sales_return_items_return_idx', columns: {#salesReturnId})
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
@TableIndex(name: 'purchase_returns_session_idx', columns: {#cashierSessionId})
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

@TableIndex(name: 'purchase_return_items_return_idx', columns: {#purchaseReturnId})
class PurchaseReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseReturnId => integer().references(PurchaseReturns, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get unitId => integer().references(ProductUnits, #id)();
  RealColumn get quantity => real()();
  RealColumn get costPrice => real()();
  RealColumn get subtotal => real()();
}

// 26. Riwayat Poin Pelanggan
@TableIndex(name: 'point_transactions_customer_idx', columns: {#customerId})
class PointTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn? get orderId => integer().nullable().references(Orders, #id, onDelete: KeyAction.setNull)();
  TextColumn get type => text()(); // 'earn' / 'redeem' / 'expire' / 'adjust'
  IntColumn get points => integer()(); // positif = earn, negatif = redeem/expire
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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
  PointTransactions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 7;

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
          if (from < 6) {
            await m.addColumn(products, products.allowManualPrice);
            await m.addColumn(orderItems, orderItems.minQtyApplied);
          }
          if (from < 7) {
            await m.addColumn(customers, customers.pointsBalance);
            await m.createTable(pointTransactions);
          }
        },
        beforeOpen: (details) async {
          // PRAGMA tuning — dijalankan setiap koneksi dibuka
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = -64000');
          await customStatement('PRAGMA temp_store = MEMORY');

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
