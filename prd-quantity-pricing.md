# PRD — Harga Bertingkat (Quantity-Based Pricing)

## 1. Konsep

Harga berbeda otomatis berdasarkan jumlah pembelian per item. Bukan manual milih "Harga Umum" / "Harga Grosir" seperti sekarang.

**Contoh: Produk "Kopra" unit "Pcs"**
| Rentang Qty | Harga Satuan |
|-------------|-------------|
| 1 - 9 pcs | Rp 10.000 |
| 10 - 49 pcs | Rp 9.000 |
| 50+ pcs | Rp 8.000 |

Ketika kasir input qty=5 → otomatis pakai Rp 10.000.  
Ketika ubah qty=12 → otomatis berubah ke Rp 9.000.  
Tidak perlu toggle manual.

---

## 2. Kondisi Saat Ini

| Aspek | Sekarang |
|-------|----------|
| **Price Tier** | Manual, cashier pilih "Umum" atau "Grosir" per produk |
| **min_qty** | Kolom ada di DB (`product_prices`) tapi selalu hardcoded `1` dan **tidak pernah dipakai** |
| **Perubahan qty** | Harga satuan tetap, tidak berespon terhadap jumlah beli |
| **Setting harga** | Input di form produk: 1 field harga per tier per unit |
| **Override manual** | Selalu bisa input harga manual, tanpa kontrol |

---

## 2B. Keputusan Desain (Hasil Diskusi)

| Poin | Keputusan |
|------|-----------|
| **1. Price Tier (Umum/Grosir)** | **Dihapus.** Konsep "Harga Grosir" diganti dengan quantity break per rentang qty. `price_tier_id` jadi nullable, tidak dipakai lagi. |
| **2. Override Manual** | **Tetap ada, tapi digate oleh field di produk.** Tambah field `allow_manual_price` (boolean) di tabel `products`. Jika false, field harga manual di POS disembunyikan. Jika true, tampil seperti sekarang. |
| **3. Perubahan qty di keranjang** | **Mengunci seperti sekarang.** Harga ditentukan saat item masuk keranjang (di modal produk). Perubahan qty di keranjang tidak mengubah harga. |
| **4. Multi-unit + quantity break** | **Ya, diimplementasikan.** Jika user beli 15 Pcs dan ada unit Dus (1 Dus = 10 Pcs), sistem akan menawarkan konversi ke 1 Dus + 5 Pcs dengan harga break masing-masing. |

---

## 3. Konsep Baru: Quantity Breaks

### 3.1. Definisi
Setiap produk + unit bisa punya beberapa **Quantity Break**:
- `min_qty`: batas bawah jumlah pembelian
- `price`: harga satuan untuk rentang tsb

Satu baris `product_prices` sekarang adalah: **(product_id, unit_id, min_qty) → price**

`price_tier_id` diabaikan (nullable) — price tier (Umum/Grosir) dihapus, diganti quantity break.

Setiap produk punya field baru:
- `allow_manual_price` (boolean, default false) — mengontrol apakah cashier bisa override harga di POS.

### 3.2. Contoh Data

| product_id | unit_id | min_qty | price |
|-----------|---------|---------|-------|
| 1 | 1 (Pcs) | 1 | 10.000 |
| 1 | 1 (Pcs) | 10 | 9.000 |
| 1 | 1 (Pcs) | 50 | 8.000 |
| 1 | 2 (Dus) | 1 | 130.000 |
| 1 | 2 (Dus) | 5 | 120.000 |

### 3.3. Aturan
- `min_qty` harus unik per (product_id, unit_id)
- Tidak boleh ada gap (setiap qty harus dapat harga)
- Jika qty tidak memenuhi break manapun → pakai break tertinggi (harga termurah)
- Jika tidak ada break → price = 0

---

## 4. Opsi Implementasi

### Opsi A: Pakai Tabel Existing (`product_prices`) — Ubah Makna
Manfaatkan tabel `product_prices` yang sudah ada, ubah makna `price_tier_id` jadi opsional/nullable, pakai `min_qty` sebagai quantity break.

**Pro**: Tidak perlu tabel baru, migrasi minimal.  
**Kontra**: Makna `price_tier_id` jadi ambigu, perlu nullable.

### Opsi B: Tabel Baru `product_quantity_breaks`
Buat tabel terpisah untuk quantity breaks. `product_prices` tetap untuk harga default.

```sql
CREATE TABLE product_quantity_breaks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_id INTEGER NOT NULL REFERENCES product_units(id) ON DELETE CASCADE,
    min_qty INTEGER NOT NULL,
    price REAL NOT NULL,
    UNIQUE(product_id, unit_id, min_qty)
);
```

**Pro**: Pemisahan jelas, tidak mengganggu sistem price tier existing.  
**Kontra**: Tabel baru, query join tambahan.

### Opsi C: Reuse `product_prices` Sepenuhnya
Hapus dependensi `price_tier_id`, jadikan `(product_id, unit_id, min_qty)` sebagai key.

**Pro**: Bersih, tanpa tabel baru.  
**Kontra**: Perlu migrasi data price tier existing → quantity break.

---

## 5. Alur Bisnis

### 5.1. Input Quantity di POS
```
User input qty = 12 di modal produk:
  1. Cari quantity break dengan min_qty <= 12
  2. Ambil yang min_qty terbesar (misal min_qty=10, price=9.000)
  3. Tampilkan harga otomatis Rp 9.000
  4. Jika user ubah qty = 6 → re-calculate ke break min_qty=1 (Rp 10.000)
```

### 5.2. Tampilan di Modal Produk
- Harga otomatis berubah saat qty diubah
- Ada indikasi: "Harga @ Rp 9.000 (min. 10 pcs)"
- Cashier bisa input harga manual **hanya jika** produk memiliki `allow_manual_price = true`
- Jika `allow_manual_price = false`, harga otomatis tidak bisa diubah

### 5.3. Multi-Unit Auto-Conversion
- Jika user pilih unit Pcs dan input qty yang setara dengan unit lebih besar (misal 15 Pcs, 1 Dus = 10 Pcs):
  - Tampilkan saran: "15 Pcs bisa dikonversi ke 1 Dus + 5 Pcs"
  - Jika user setuju → qty diubah jadi 1 Dus + 5 Pcs, harga dihitung per unit masing-masing
  - Jika tidak → tetap 15 Pcs dengan harga break Pcs

### 5.4. Tampilan di Form Produk
Per unit, input beberapa baris quantity break:
```
[Unit: Pcs]
  Qty ≥ 1  : Rp ______
  Qty ≥ 10 : Rp ______
  Qty ≥ 50 : Rp ______
  [+ Tambah Break]
```

### 5.5. Keranjang
- Setiap item menyimpan `appliedMinQty` (break yang dipakai) untuk referensi
- Harga mengunci saat item masuk keranjang (tidak berubah jika qty diubah di keranjang)
- Subtotal = qty * price (sesuai break saat item ditambahkan)

---

## 6. Perubahan Database

### Jika Pilih Opsi C (reuse product_prices):

6.1. **`product_prices` — Ubah constraint**
```sql
-- Hapus foreign key ke price_tiers
-- Ubah price_tier_id jadi nullable
ALTER TABLE product_prices RENAME TO product_prices_old;

CREATE TABLE product_prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_id INTEGER NOT NULL REFERENCES product_units(id) ON DELETE CASCADE,
    price_tier_id INTEGER REFERENCES price_tiers(id) ON DELETE SET NULL,
    price REAL DEFAULT 0.0,
    min_qty INTEGER DEFAULT 1
);

CREATE UNIQUE INDEX idx_product_unit_qty 
    ON product_prices(product_id, unit_id, min_qty);
```

6.2. **Migrasi data**
```sql
-- Harga existing dimasukkan sebagai break dengan min_qty=1
INSERT INTO product_prices (product_id, unit_id, price_tier_id, price, min_qty)
SELECT product_id, unit_id, price_tier_id, price, 1 
FROM product_prices_old;
```

6.3. **`products` — Add column**
```sql
ALTER TABLE products ADD COLUMN allow_manual_price INTEGER DEFAULT 0;
```

6.4. **`price_tiers` — Dibiarkan (tidak di-drop)**
- Tabel dibiarkan ada untuk kompatibilitas, tidak dipakai lagi
- Migrasi data existing: harga grosir jadi quantity break dengan `min_qty` tertentu (default 1)

6.5. **`order_items` — Add column**
```sql
ALTER TABLE order_items ADD COLUMN min_qty_applied INTEGER DEFAULT 1;
```
- Mencatat quantity break (`min_qty`) yang dipakai saat item dijual
- Berguna untuk analisa pola pembelian per break

---

## 7. Perubahan UI

### 7.1. Master Produk — Halaman Form
Tambah field baru:
- **Toggle "Izinkan Input Harga Manual"** (`allow_manual_price`) — default off

Per unit, input beberapa baris quantity break (menggantikan field price tier):
```
┌──────────────────────────────────────┐
│  Unit: Pcs                          │
│  ┌────────────────────────────────┐  │
│  │ Qty ≥ 1    │ Rp [___________] │  │
│  │ Qty ≥ 10   │ Rp [___________] │  │
│  │ Qty ≥ 50   │ Rp [___________] │  │
│  │ [+ Tambah Break]              │  │
│  └────────────────────────────────┘  │
│                                      │
│  Unit: Dus                           │
│  ┌────────────────────────────────┐  │
│  │ Qty ≥ 1    │ Rp [___________] │  │
│  │ Qty ≥ 5    │ Rp [___________] │  │
│  │ [+ Tambah Break]              │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 7.2. POS — Tampilan Harga di Modal Produk

**Jika `allow_manual_price = true`:**
```
┌──────────────────────────────┐
│  Harga: Rp 9.000 / pcs       │
│  (berlaku untuk min. 10 pcs) │
│                              │
│  Qty: [12] ➕                │
│  Subtotal: Rp 108.000       │
│                              │
│  [Harga Manual: Rp _______]  │
└──────────────────────────────┘
```

**Jika `allow_manual_price = false`:**
```
┌──────────────────────────────┐
│  Harga: Rp 9.000 / pcs       │
│  (berlaku untuk min. 10 pcs) │
│                              │
│  Qty: [12] ➕                │
│  Subtotal: Rp 108.000       │
│                              │
│  (Harga otomatis)            │
└──────────────────────────────┘
```

### 7.3. POS — Konversi Multi-Unit
Jika user input qty di modal produk Pcs yang cukup untuk dikonversi:
```
┌──────────────────────────────┐
│  Qty: [15] Pcs ➕            │
│                              │
│  ⚠ 15 Pcs = 1 Dus + 5 Pcs  │
│  Harga: Rp 130rb + Rp 45rb  │
│  = Rp 175.000               │
│                              │
│  [Konversi] [Tetap 15 Pcs]  │
└──────────────────────────────┘
```

### 7.4. POS — Tampilan di Keranjang
```
┌──────────────────────────────────┐
│  Kopra                    x 12   │
│  Rp 9.000 × 12 = Rp 108.000     │
│  ─────────────────────────       │
│  (Harga berdasar qty, min. 10)  │
└──────────────────────────────────┘
```

---

## 8. Perubahan Logic (Cubit/Repository)

### 8.1. `cart_cubit.dart`

| Method | Perubahan |
|--------|-----------|
| `_getPriceForUnit()` | Tambah parameter `quantity`. Cari break dengan `min_qty <= quantity`, ambil `min_qty` terbesar. Fallback ke harga dengan `min_qty` terkecil. |
| `addToCart()` | Pass `quantity` ke `_getPriceForUnit()` |
| `updateQuantity()` | Method baru: saat qty diubah, re-calculate price berdasarkan break. Jika ada, update item. |
| `changePriceTier()` | **Dihapus** — tidak ada lagi price tier global |

### 8.2. `master_repository.dart`

| Method | Perubahan |
|--------|-----------|
| `insertProductComplete()` | Simpan quantity breaks sebagai multiple rows di `product_prices` |
| `updateProductComplete()` | Hapus semua `product_prices` lama, insert ulang dengan breaks baru |

### 8.3. `pos_page.dart`

| Method | Perubahan |
|--------|-----------|
| `updatePricesForTier()` | Ubah jadi `updatePriceForQuantity()` — hitung harga berdasarkan qty |
| Tampilan di modal | Tampilkan keterangan break yang aktif |

---

## 9. Keputusan Desain Lanjutan

### 9.1. Perlakuan Harga 0
**Keputusan: Diabaikan (tidak valid).**
- Quantity break dengan `price = 0` dianggap tidak diisi / tidak aktif.
- Saat lookup harga, break dengan `price = 0` dilewati.
- Jika semua break bernilai 0 → price = 0 (gratis, tapi perlu konfirmasi).
- Untuk kasus gratis, kasir bisa override manual jika `allow_manual_price = true`.

### 9.2. History Transaksi
**Keputusan: Dicatat.**
- Tambah kolom `min_qty_applied` (INTEGER) di `order_items`.
- Menyimpan `min_qty` dari quantity break yang dipakai saat item dijual.
- Berguna untuk analisa: "produk X sering dibeli di break berapa?"

---

## 10. Prioritas

| Priority | Item | Complexity |
|----------|------|------------|
| P0 | Migrasi DB: `allow_manual_price` di products, ubah `product_prices` pakai `min_qty` | Medium |
| P0 | Form produk: input quantity breaks + toggle manual price | Medium |
| P0 | Ubah `_getPriceForUnit()` di cart_cubit agar terima parameter qty | Low |
| P1 | Re-calculate price saat qty berubah di modal produk | Low |
| P1 | Sembunyikan/tampilkan field harga manual di modal produk sesuai `allow_manual_price` | Low |
| P1 | Tampilkan keterangan break aktif di modal ("min. X qty") | Low |
| P2 | Hapus UI price tier toggle (Harga Umum/Grosir) dari POS | Low |
| P2 | Multi-unit auto-conversion di modal produk | Medium |
| P3 | Tambah kolom `min_qty_applied` di order_items (untuk analisa) | Low |
