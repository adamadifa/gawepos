# PRD — HPP (FIFO/Batch) & Manajemen Expired Produk

## 1. Tujuan & Latar Belakang

Saat ini sistem hanya menghitung HPP secara naif (mengambil harga beli terakhir dari `purchase_items`). Tidak ada mekanisme **FIFO**, **batch/lot tracking**, atau **manajemen expired**. Akibatnya:

- Laporan laba rugi tidak akurat jika harga beli berubah-ubah.
- Tidak bisa melacak produk mendekati kadaluarsa.
- Tidak ada audit trail biaya per unit barang terjual.
- Nilai aset stok tidak realistis.

---

## 2. Konsep Solusi

### 2.1. HPP Method Config
Tambah setting global `hpp_method` dengan opsi:
- `fifo` — First In First Out (default)
- `average` — Rata-rata tertimbang
- `last_purchase` — Harga beli terakhir (seperti sekarang)

Disimpan di tabel `settings` dengan key `hpp_method`.

### 2.2. Batch / Lot Tracking
Setiap kali barang diterima dari pembelian, dibuat **batch** dengan informasi:
- Nomor batch/lot (auto-generate atau input manual)
- Tanggal expired (untuk produk yang perishable)
- Harga beli per unit (`cost_price`)
- Quantity awal

Penjualan akan mengambil quantity dari batch tertua (FIFO) terlebih dahulu.

### 2.3. Expired Product Management
- Produk dapat ditandai `has_expiry = true` di master produk.
- Jika `has_expiry`, saat pembelian wajib input tanggal expired.
- Sistem akan memberi peringatan jika produk mendekati expired (30/14/7 hari).
- Produk expired tidak boleh dijual (blokir/peringatan di POS).

---

## 3. Perubahan Database

### 3.1. Tabel Baru: `inventory_batches`

```sql
CREATE TABLE inventory_batches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_id INTEGER NOT NULL REFERENCES product_units(id) ON DELETE CASCADE,
    batch_no TEXT NOT NULL,
    cost_price REAL NOT NULL,
    quantity REAL NOT NULL DEFAULT 0.0,
    expiry_date TIMESTAMP,
    purchase_id INTEGER REFERENCES purchases(id) ON DELETE SET NULL,
    purchase_item_id INTEGER REFERENCES purchase_items(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_batch_product_unit 
    ON inventory_batches(product_id, unit_id, batch_no);
```

### 3.2. Modifikasi Tabel `products`

Tambah kolom:
```sql
ALTER TABLE products ADD COLUMN has_expiry INTEGER DEFAULT 0;
ALTER TABLE products ADD COLUMN expiry_alert_days INTEGER DEFAULT 30;
```

### 3.3. Modifikasi Tabel `purchase_items`

Tambah kolom:
```sql
ALTER TABLE purchase_items ADD COLUMN batch_no TEXT;
ALTER TABLE purchase_items ADD COLUMN expiry_date TIMESTAMP;
```

### 3.4. Modifikasi Tabel `order_items`

Tambah kolom `cost_price` agar HPP tercatat saat transaksi:
```sql
ALTER TABLE order_items ADD COLUMN cost_price REAL;
```

### 3.5. Modifikasi Tabel `stock_movements`

Tambah kolom untuk audit cost:
```sql
ALTER TABLE stock_movements ADD COLUMN batch_id INTEGER REFERENCES inventory_batches(id) ON DELETE SET NULL;
ALTER TABLE stock_movements ADD COLUMN unit_cost REAL;
```

### 3.6. Modifikasi Tabel `inventory`

Tambah kolom opsional:
```sql
ALTER TABLE inventory ADD COLUMN has_expiry INTEGER DEFAULT 0;
```
> **Catatan**: Tabel `inventory` tetap ada sebagai ringkasan stok total per produk/unit. Detail batch ada di `inventory_batches`.

### 3.7. Tabel Baru: `expiry_alerts`

```sql
CREATE TABLE expiry_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id INTEGER NOT NULL REFERENCES inventory_batches(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL, -- 'near_expiry', 'expired'
    alert_days INTEGER NOT NULL,
    is_dismissed INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 3.8. Tabel Baru: `product_expiry_settings` (per produk override)

```sql
-- Tidak perlu tabel terpisah, cukup kolom di products:
-- has_expiry, expiry_alert_days (default 30)
```

---

## 4. Migrasi Data

### 4.1. Migrasi dari sistem lama
Saat upgrade dari schemaVersion 5 ke 6:
1. Tambah semua kolom baru via `ALTER TABLE`.
2. Buat tabel `inventory_batches`.
3. **Backfill batch**: Untuk setiap stok yang ada di `inventory`, buat satu batch default:
   - `batch_no = 'LEGACY-{product_id}-{unit_id}'`
   - `cost_price =` ambil dari `getProductCostPrice()` terakhir, atau 0 jika tidak ada
   - `quantity =` quantity dari inventory
   - `expiry_date = null`
   - `purchase_id = null`
4. Set `has_expiry = 0` untuk semua produk existing.

### 4.2. Dampak pada data existing
- Semua order_items lama tidak punya `cost_price` → laporan historical akan menggunakan lookup HPP saat laporan di-generate.
- Hanya transaksi baru setelah migrasi yang mencatat `cost_price` real-time.

---

## 5. Perubahan Alur Bisnis

### 5.1. Alur Pembelian (Receive)

```
Penerimaan Barang (confirmReceive):
  1. Validate input
  2. Untuk setiap item:
     a. Insert/update inventory (total qty) — existing logic
     b. Generate batch_no (auto: BATCH-{YYYYMMDD}-{seq}) atau manual
     c. Insert inventory_batch dengan cost_price, quantity, expiry_date
     d. Update purchase_items.batch_no dan expiry_date
     e. Simpan stock_movement dengan batch_id dan unit_cost
  3. Handle hutang supplier — existing logic
  4. Hitung ulang HPP average jika method = average
```

### 5.2. Alur Penjualan (Checkout)

```
Proses saveOrder:
  1. Generate ref + insert Order — existing
  2. Handle debt — existing
  3. Untuk setiap item keranjang:
     a. Tentukan HPP berdasarkan method:
        - FIFO: Ambil dari batch tertua (created_at ASC) yang masih punya qty
        - Average: Hitung rata-rata cost dari semua batch aktif
        - Last Purchase: Ambil cost_price dari purchase_items terakhir
     b. Kurangi quantity dari batch (FIFO) atau dari total (average/last)
     c. Catat cost_price di order_items
     d. Kurangi inventory — existing
     e. Simpan stock_movement dengan batch_id, unit_cost — existing extended
```

### 5.3. Alur Stock Opname

```
Penyesuaian Stok:
  1. Jika ada selisih (+) → Insert batch baru dengan cost_price = rata-rata existing
  2. Jika ada selisih (-) → Kurangi dari batch tertua (FIFO)
  3. Catat stock_movement dengan batch_id, unit_cost, type='opname'
```

### 5.4. Alur Retur Penjualan

```
Sales Return:
  1. Kembalikan quantity ke batch asal (jika masih bisa diidentifikasi)
  2. Jika batch sudah habis/expired → buat batch baru dengan cost_price original
  3. Catat stock_movement dengan batch_id, unit_cost, type='sales_return'
```

### 5.5. Alur Retur Pembelian

```
Purchase Return:
  1. Kurangi quantity dari batch spesifik (berdasarkan purchase_item_id)
  2. Jika quantity batch menjadi 0 → batch tetap ada untuk history
  3. Catat stock_movement dengan batch_id, unit_cost, type='purchase_return'
```

### 5.6. Alur Void Transaksi

```
Void Order:
  1. Kembalikan quantity ke batch asal (berdasarkan batch_id di stock_movement)
  2. Jika batch original sudah tidak ada → buat batch baru dengan cost_price original
  3. Catat stock_movement type='void_revert'
```

---

## 6. Perubahan UI

### 6.1. Master Produk — Form Produk
Tambah field:
- **Toggle "Produk Kadaluarsa"** (`has_expiry`)
- **Alert sebelum expired (hari)** (`expiry_alert_days`) — muncul jika toggle ON

### 6.2. Form Pembelian
Tambah field per item (opsional, muncul jika produk `has_expiry`):
- **Batch No** (auto-fill, bisa diedit)
- **Tanggal Expired** (date picker)
- Tampilkan sisa batch sebelumnya untuk referensi

### 6.3. Halaman Inventory — Detail Batch
- List semua batch per produk/unit
- Kolom: Batch No, Qty, Cost Price, Expiry Date, Sisa Hari
- Sorting: FIFO (expired terdekat/tanggal masuk terlama)

### 6.4. Halaman Inventory — Peringatan Expired
- **Tab/Warning Banner**: "X produk mendekati expired" dan "Y produk sudah expired"
- List produk dengan sisa hari < alert_days
- Tombol "Dismiss" per peringatan

### 6.5. Settings
Tambah halaman **Pengaturan HPP**:
- Pilihan method: FIFO / Average / Last Purchase Price

### 6.6. POS — Saat Transaksi
- Jika produk `has_expiry` dan batch terdekat akan expired dalam < alert_days → tampilkan warning kecil di modal produk
- Jika produk sudah expired total → blokir penjualan dengan pesan "Produk sudah kadaluarsa"

### 6.7. Laporan
- **Laporan Nilai Stok**: Nilai = sum(qty * cost_price per batch)
- **Laporan Produk Expired**: Filter produk expired / near-expiry
- **Detail HPP per Transaksi**: Di laporan penjualan, tampilkan HPP dan laba per item

---

## 7. Perubahan Business Logic (Cubit/Repository)

### 7.1. `InventoryRepository`

| Method | Perubahan |
|--------|-----------|
| `getStockByProduct()` | Join dengan `inventory_batches` untuk detail batch |
| `adjustStock()` | Update batch-batch terkait, simpan stock_movement dengan batch_id |
| Method baru `getBatchesByProduct()` | Ambil semua batch aktif per produk/unit, urut FIFO |
| Method baru `getExpiringProducts()` | Produk dengan expiry_date antara now dan now + alert_days |
| Method baru `getExpiredProducts()` | Produk dengan expiry_date < now dan qty > 0 |

### 7.2. `PurchaseRepository`

| Method | Perubahan |
|--------|-----------|
| `confirmReceive()` | Setelah insert inventory, buat `inventory_batches` untuk setiap item. Simpan batch_no & expiry_date ke purchase_items. |

### 7.3. `SalesRepository`

| Method | Perubahan |
|--------|-----------|
| `saveOrder()` | Setelah hitung HPP (FIFO/average/last), kurangi batch, catat `cost_price` di `order_items` |
| `voidOrder()` | Kembalikan quantity ke batch asal berdasarkan batch_id di stock_movements |
| Method baru `calculateHppFifo()` | Ambil dari batch tertua (min created_at) dengan qty > 0, potong sesuai kebutuhan |
| Method baru `calculateHppAverage()` | SELECT avg(cost_price) dari inventory_batches dengan qty > 0 |

### 7.4. `ReportsRepository`

| Method | Perubahan |
|--------|-----------|
| `getProductCostPrice()` | Gunakan method sesuai pengaturan, bukan last purchase price |
| `getDashboardData()` | Tidak perlu lookup cost lagi karena `order_items.cost_price` sudah terisi |
| `getPnLReport()` | Sama, pakai `order_items.cost_price` langsung |
| Method baru `getStockValueReport()` | Nilai stok = Σ(qty × cost_price) per batch |

### 7.5. Cubit Baru: `ExpiryCubit`

- State: `ExpiryInitial`, `ExpiryLoaded(List<ExpiryAlert>)`, `ExpiryError`
- Methods:
  - `loadAlerts()` — Ambil semua batch dengan expiry_date mendekat/sudah lewat
  - `dismissAlert(int alertId)` — Tandai alert sebagai dismissed
  - `checkAndGenerateAlerts()` — Cron-job tiap buka app untuk generate alert baru

---

## 8. Daftar Tabel Lengkap (Perubahan)

### Tabel Baru
| Tabel | Tujuan |
|-------|--------|
| `inventory_batches` | Tracking batch/lot per produk + unit, dengan cost_price dan expiry_date |
| `expiry_alerts` | Riwayat peringatan expired yang sudah/sudah di-dismiss |

### Tabel Dimodifikasi (Add Column)
| Tabel | Kolom Baru |
|-------|------------|
| `products` | `has_expiry`, `expiry_alert_days` |
| `purchase_items` | `batch_no`, `expiry_date` |
| `order_items` | `cost_price` |
| `stock_movements` | `batch_id`, `unit_cost` |
| `inventory` | `has_expiry` (opsional, untuk filtering cepat) |

---

## 9. Prioritas & Estimasi

| Priority | Feature | Complexity | Depends On |
|----------|---------|------------|------------|
| P0 | Schema: tabel `inventory_batches` + migrasi | Medium | — |
| P0 | Schema: add column `cost_price` ke `order_items` | Low | — |
| P0 | Alur FIFO di `saveOrder()` | High | inventory_batches |
| P0 | Alur FIFO di `confirmReceive()` (create batch) | Medium | — |
| P1 | UI Form Pembelian: batch_no, expiry_date | Medium | Form purchase existing |
| P1 | UI Master Produk: toggle has_expiry | Low | Form produk existing |
| P1 | Settings: hpp_method picker | Low | — |
| P2 | Alur Void/FIFO revert | Medium | inventory_batches |
| P2 | Alur Retur/FIFO | Medium | inventory_batches |
| P2 | Stock Opname dengan batch | Medium | inventory_batches |
| P2 | Halaman detail batch inventory | Medium | — |
| P3 | Peringatan expired produk | Medium | ExpiryCubit |
| P3 | Laporan nilai stok | Low | inventory_batches |
| P3 | Warning expired di POS | Low | ExpiryCubit |

### Estimasi Total: ~3-4 sprint (2 minggu per sprint)
- Sprint 1: Schema migration + backend FIFO di purchase & sales
- Sprint 2: UI Form Purchase + Product + Settings + Halaman Batch
- Sprint 3: Void/Return dengan batch + Stock Opname
- Sprint 4: Expiry alerts + Reports + POS warning

---

## 10. Risiko & Mitigasi

| Risiko | Mitigasi |
|--------|----------|
| Performa menurun karena query batch di setiap transaksi | Batch query dioptimasi dengan index (product_id, unit_id, created_at). Jumlah batch per produk umumnya < 50. |
| Data `cost_price` null di `order_items` lama | Fallback ke method lookup existing untuk historical data |
| Kompleksitas FIFO dengan multi-unit | Cost selalu dalam base unit. Konversi via `conversion_factor` saat transaksi. |
| Expired date tidak diisi saat pembelian | Buat field required hanya jika `has_expiry = true`. Jika tidak diisi, set null (dianggap tidak expired). |
| Rollback jika transaksi gagal di tengah alur FIFO | Semua operasi batch dibungkus dalam `_db.transaction()` |
