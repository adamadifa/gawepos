# Rencana Optimasi Database & Performa — GawePOS

Dokumen ini berisi langkah-langkah optimasi berurutan (dari yang paling penting &
berdampak besar ke yang opsional) untuk memastikan aplikasi tetap aman dan cepat
saat data sudah mencapai ribuan hingga puluhan ribu transaksi.

---

## Ringkasan Masalah

| Masalah | Dampak | Prioritas |
|---------|--------|-----------|
| Foreign key tidak aktif | Data integrity tidak terjamin, cascade delete tidak jalan | 🔴 Critical |
| Hanya 1 index untuk 31 tabel | Full table scan di setiap query foreign key | 🔴 Critical |
| N+1 query pattern | Ribuan query terpisah untuk satu operasi | 🔴 Critical |
| Tidak ada pagination | Boros memori, makin lambat seiring data bertambah | 🟡 High |
| Uang pakai float/double | Rounding error akumulatif | 🟡 High |
| COUNT+1 untuk referensi number | Load seluruh record harian ke memory | 🟡 High |
| Tidak ada WAL mode | Kinerja menurun saat read + write bersamaan | 🟡 High |
| Tidak ada PRAGMA tuning | SQLite memakai konfigurasi default (konservatif) | 🟢 Medium |

---

## Fase 1 — Integritas Data & Keselamatan (Prioritas Tertinggi)

### 1.1 Enable Foreign Key & WAL Mode

**File**: `lib/core/database/app_database.dart`

Ubah `_openConnection()` untuk menyetel PRAGMA yang diperlukan setelah koneksi
dibuka:

```dart
return LazyDatabase(() async {
  final file = File(p.join(dbFolder.path, 'posmobile.db'));
  final db = NativeDatabase.createInBackground(file);
  db.execCustom('PRAGMA foreign_keys = ON');
  db.execCustom('PRAGMA journal_mode = WAL');
  db.execCustom('PRAGMA synchronous = NORMAL');
  db.execCustom('PRAGMA cache_size = -64000');
  db.execCustom('PRAGMA temp_store = MEMORY');
  return db;
});
```

**Verifikasi**: Jalankan `flutter test` — pastikan semua test yang involve
cascade delete masih (atau sekarang) berfungsi.

### 1.2 Hapus `try/catch` Buta di `beforeOpen`

**File**: `lib/core/database/app_database.dart`

Ganti fallback `PRAGMA table_info` yang menelan error di `beforeOpen` dengan
mekanisme migrasi yang terdefinisi dengan baik. Jika kolom `payment_type` dan
`down_payment` sudah ada di skema v2→v3→v4, maka fallback ini sudah tidak
diperlukan lagi (legacy). Cukup dihapus setelah dipastikan semua pengguna sudah
di atas versi 4.

### 1.3 Konversi Uang ke Integer Sen (Opsional tapi Dianjurkan)

Ganti semua `RealColumn` untuk nilai uang menjadi `IntColumn` dengan satuan sen.

Sebelum:
```dart
RealColumn get grandTotal => real()();
```

Sesudah:
```dart
IntColumn get grandTotal => integer()(); // dalam sen (Rupiah * 100)
```

**Tabel yang terdampak**: `orders`, `order_items`, `order_payments`, `purchases`,
`purchase_items`, `customer_debts`, `customer_debt_payments`, `supplier_debts`,
`supplier_debt_payments`, `expenses`, `products` (price), `product_prices`, dll.

**Catatan**: Ini migrasi besar (schema version bump). Lakukan jika sudah siap
dengan proses migrasi data. Alternatif lebih sederhana: tetap pakai `RealColumn`
tapi bulatkan dengan `round()` di Dart sebelum menyimpan.

---

## Fase 2 — Indexing (Dampak Besar, Resiko Rendah)

### 2.1 Index untuk Foreign Key & Filter Umum

Tambahkan definisi index di file tabel masing-masing (dalam
`lib/core/database/app_database.dart`):

```dart
// orders
@Index(columns: {orders.cashierSessionId})
@Index(columns: {orders.status})
@Index(columns: {orders.createdAt})
@Index(columns: {orders.customerId})

// order_items
@Index(columns: {orderItems.orderId})

// order_payments
@Index(columns: {orderPayments.orderId})

// inventory
@Index(columns: {inventory.productId, inventory.unitId}) // composite

// stock_movements
@Index(columns: {stockMovements.productId})
@Index(columns: {stockMovements.createdAt})

// purchases
@Index(columns: {purchases.supplierId})
@Index(columns: {purchases.status})
@Index(columns: {purchases.createdAt})

// purchase_items
@Index(columns: {purchaseItems.purchaseId})

// customer_debts
@Index(columns: {customerDebts.customerId})
@Index(columns: {customerDebts.orderId})
@Index(columns: {customerDebts.status})

// supplier_debts
@Index(columns: {supplierDebts.supplierId})
@Index(columns: {supplierDebts.purchaseId})

// products
@Index(columns: {products.name})           // untuk pencarian
@Index(columns: {products.sku})            // untuk lookup

// cashier_sessions
@Index(columns: {cashierSessions.userId})
@Index(columns: {cashierSessions.status})

// expenses
@Index(columns: {expenses.createdAt})

// sales_returns / purchase_returns
@Index(columns: {salesReturns.cashierSessionId})
@Index(columns: {purchaseReturns.cashierSessionId})

// point_transactions
@Index(columns: {pointTransactions.customerId})
```

**Setelah selesai**: Jalankan `dart run build_runner build --delete-conflicting-outputs`
untuk regenerate Drift code.

**Estimasi dampak**: Query yang tadinya O(n) jadi O(log n). Untuk 50.000
transaksi, query lookup foreign key dari ~50.000 baris yang di-scan jadi
~log₂(50.000) ≈ 16 langkah.

---

## Fase 3 — Optimasi Query (N+1 & Pagination)

### 3.1 Fix N+1 di SalesRepository

**File**: `lib/data/repositories/sales_repository.dart`

**Method `getPosProducts()`**:

Ganti loop N+1 dengan `LEFT OUTER JOIN` menggunakan Drift's join API:

```dart
// SEBELUM: 1 + N + N query
for (var product in products) {
  units = await (db.select(db.productUnits)
    ..where((t) => t.productId.equals(product.id))
  ).get();
  prices = await (db.select(db.productPrices)
    ..where((t) => t.productId.equals(product.id))
  ).get();
}

// SESUDAH: 3 query total
final unitsByProduct = await (db.select(db.productUnits)
  ..where((t) => t.productId.isIn(productIds))
).get();
final pricesByProduct = await (db.select(db.productPrices)
  ..where((t) => t.productId.isIn(productIds))
).get();
// Group by productId di Dart
```

**Method `getOrderDetails()`**:

Ganti loop per item untuk fetch product + unit:

```dart
// Gunakan join query
final query = db.select(db.orderItems)
  .join([
    innerJoin(db.products, db.products.id.equalsExp(db.orderItems.productId)),
    innerJoin(db.productUnits, db.productUnits.id.equalsExp(db.orderItems.unitId)),
  ])
  ..where(db.orderItems.orderId.equals(orderId));
final rows = await query.get();
```

### 3.2 Fix N+1 di PurchaseRepository

**File**: `lib/data/repositories/purchase_repository.dart`

Untuk `getPurchases()` yang fetch supplier per purchase, gunakan batch query:

```dart
final supplierIds = purchases.map((p) => p.supplierId).toSet().toList();
final suppliers = await (db.select(db.suppliers)
  ..where((t) => t.id.isIn(supplierIds))
).get();
final supplierMap = {for (var s in suppliers) s.id: s};
```

### 3.3 Fix N+1 di ReportsRepository

**File**: `lib/data/repositories/reports_repository.dart`

Ini yang terberat. Semua method laporan perlu di-refactor. Strategi umum:

1. Gunakan **raw SQL** untuk laporan komples (aggregate query) — Drift bisa
   pakai `customSelect()` atau `customRead()`.
2. Darjah loopping orders → items → products, buat query dengan JOIN.

Contoh untuk `getDashboardData()`:

```sql
SELECT
  COUNT(DISTINCT o.id) as totalTransactions,
  COALESCE(SUM(o.grand_total), 0) as totalRevenue,
  COALESCE(SUM(o.discount_amount), 0) as totalDiscount
FROM orders o
WHERE o.status = 'completed'
  AND o.created_at >= ? AND o.created_at <= ?;
```

### 3.4 Implementasi Pagination

Buat pattern pagination untuk semua list screen:

```dart
Future<List<Order>> getOrders({
  required int page,
  int pageSize = 20,
  String? status,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final query = db.select(db.orders)
    ..limit(pageSize, offset: (page - 1) * pageSize)
    ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

  if (status != null) query.where((t) => t.status.equals(status));
  if (startDate != null) query.where((t) => t.createdAt.isBiggerThanValue(startDate));
  if (endDate != null) query.where((t) => t.createdAt.isSmallerThanValue(endDate));

  return await query.get();
}
```

**Screen yang perlu pagination**:
- Daftar produk
- Daftar transaksi/orders
- Daftar pelanggan
- Daftar pembelian
- Daftar stok
- Daftar laporan (semua jenis)

**Di Cubit**: Tambah state `page`, `hasMore`, `isLoadingMore`. Panggil method
paginated saat scroll ke bawah.

### 3.5 Optimasi Referensi Number

**File**: Masing-masing repository (`SalesRepository`, `PurchaseRepository`, dll.)

Ganti `countQuery.get().length` dengan `COUNT(*)`:

```dart
final countQuery = db.selectOnly(db.orders)
  ..addColumns([db.orders.id.count()])
  ..where(db.orders.referenceNo.like('TRX-YYYYMMDD-%'));
final count = await countQuery.getSingle();
final countValue = count.read(db.orders.id.count()) ?? 0;
```

Atau lebih efisien: `MAX()` jika format referensi numerik:

```dart
final maxQuery = db.selectOnly(db.orders)
  ..addColumns([db.orders.referenceNo.max()])
  ..where(db.orders.referenceNo.like('TRX-YYYYMMDD-%'));
```

---

## Fase 4 — Tuning Database Connection

### 4.1 Migration Strategy yang Lebih Aman

**File**: `lib/core/database/app_database.dart`

Hapus fallback `PRAGMA table_info` di `beforeOpen` setelah semua pengguna
di-migrasi melewati v4. Ganti dengan unit test yang memverifikasi skema.

Tambah logging di migrasi:
```dart
onUpgrade: (m, from, to) async {
  debugPrint('[DB] Migrating from v$from to v$to');
  if (from < 2) await m.addTable(rolePermissions);
  // ... etc
},
```

### 4.2 Read-Only Connection untuk Report

Untuk laporan berat, buat koneksi read-only terpisah (WAL mode memungkinkan
read concurrent):

```dart
// Di injection.dart
GetIt.I.registerLazySingleton<AppDatabase>(() => AppDatabase());
GetIt.I.registerLazySingleton<AppDatabase>(() {
  return AppDatabase.connectReadOnly();
}, instanceName: 'readonlyDb');
```

**Catatan**: Ini opsional. Dengan WAL mode, read tidak blocking write. Hanya
perlu jika dashboard/laporan masih lambat setelah optimasi query.

### 4.3 Batch Insert untuk Seed Data

**File**: `lib/data/repositories/master_repository.dart`

Ganti `seedDummyData()` yang insert satu-satu dengan batch:

```dart
await _db.batch((batch) {
  for (var product in dummyProducts) {
    batch.insert(db.products, product);
  }
  for (var category in dummyCategories) {
    batch.insert(db.categories, category);
  }
});
```

---

## Fase 5 — Testing & Validasi

### 5.1 Test Index Bekerja

```sql
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE cashier_session_id = ?;
```
Jalankan via `db.customSelect('EXPLAIN QUERY PLAN ...')` di test untuk
memastikan query memakai index (muncul "SEARCH TABLE orders USING INDEX ...").

### 5.2 Test Foreign Key Bekerja

```dart
test('foreign key cascade delete works', () async {
  // Insert order, insert item, delete order
  // Item harus otomatis terhapus
  final db = AppDatabase();
  // ... setup
  await db.delete(db.orders).go();
  final items = await db.select(db.orderItems).get();
  expect(items.length, equals(0)); // harus 0 karena cascade delete
});
```

### 5.3 Benchmark Query

Buat test yang mengukur waktu query dengan dummy data dalam jumlah besar
(misal 10.000 order, 50.000 item). Jalankan sebelum dan sesudah optimasi
untuk memastikan improvement.

---

## Fase 6 — Opsional / Jangka Panjang

### 6.1 Database Compaction

SQLite tidak otomatis mengembalikan ruang ke OS. Jadwalkan `PRAGMA auto_vacuum = INCREMENTAL`
atau `VACUUM` periodik (misal seminggu sekali atau setelah migrasi besar).

Di `beforeOpen`:
```dart
db.execCustom('PRAGMA auto_vacuum = INCREMENTAL');
db.execCustom('PRAGMA incremental_vacuum(100)'); // free 100 pages
```

### 6.2 Backup Otomatis

Buat mekanisme backup database secara periodik:

```dart
Future<void> backupDatabase() async {
  final dbPath = p.join(dbFolder.path, 'posmobile.db');
  final backupPath = p.join(dbFolder.path, 'backups',
    'posmobile_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db');
  await File(dbPath).copy(backupPath);
}
```

### 6.3 Archiving Data Lama

Untuk toko dengan >50.000 transaksi, pertimbangkan archiv data lama ke tabel
terpisah atau file database terpisah, dengan tombol "restore" jika diperlukan.

---

## Urutan Eksekusi yang Direkomendasikan

| Step | Estimasi Waktu | Resiko | Catatan |
|------|---------------|--------|---------|
| Fase 1.1 (PRAGMA) | 30 menit | Rendah | Langsung aman, tes cepat |
| Fase 2 (Index) | 1-2 jam | Rendah | Hanya tambah index, tidak ubah logika |
| Fase 1.3 (Uang) | 4-8 jam | Tinggi | Migrasi data, perlu test menyeluruh |
| Fase 3.1-3.3 (N+1) | 4-6 jam | Sedang | Ubah logika query, perlu regression test |
| Fase 3.4 (Pagination) | 4-8 jam | Sedang | Ubah cubit + UI |
| Fase 3.5 (Reference No) | 30 menit | Rendah | Penggantian langsung |
| Fase 4.1 (Migrasi) | 30 menit | Rendah | Bersihkan legacy code |
| Fase 5 (Testing) | 2-4 jam | - | Validasi semua perubahan |

**Total**: ~2-5 hari kerja tergantung kompleksitas dan test coverage.

---

## Cara Menggunakan Dokumen Ini

1. **Untuk setiap Fase**, buat branch baru: `git checkout -b optimasi/fase-1`
2. Implementasi perubahan
3. Jalankan `flutter test && flutter analyze`
4. Jalankan `dart run build_runner build --delete-conflicting-outputs` jika ada
   perubahan schema
5. Commit dengan pesan sesuai konvensi project
6. Merge ke main setelah review
7. Lanjut ke fase berikutnya
