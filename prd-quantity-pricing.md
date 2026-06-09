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

---

## 3. Konsep Baru: Quantity Breaks

### 3.1. Definisi
Setiap produk + unit bisa punya beberapa **Quantity Break**:
- `min_qty`: batas bawah jumlah pembelian
- `price`: harga satuan untuk rentang tsb

Satu baris `product_prices` sekarang adalah: **(product_id, unit_id, min_qty) → price**

Tidak ada lagi `price_tier_id` (bisa dihapus/diabaikan bertahap).

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
- Cashier tetap bisa manual override harga jika perlu (custom price)

### 5.3. Tampilan di Form Produk
Per unit, input beberapa baris quantity break:
```
[Unit: Pcs]
  Qty ≥ 1  : Rp ______
  Qty ≥ 10 : Rp ______
  Qty ≥ 50 : Rp ______
  [+ Tambah Break]
```

### 5.4. Keranjang
- Setiap item menyimpan `appliedMinQty` (break yang dipakai) untuk referensi
- Jika quantity diubah di keranjang → re-calculate harga berdasarkan break
- Subtotal = qty * price (sesuai break yang aktif)

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

6.3. **`price_tiers` — Opsional dihapus atau dibiarkan**
- Jika tidak dipakai lagi, bisa di-drop di migrasi berikutnya
- Atau dibiarkan untuk kompatibilitas

6.4. **`order_items` — Tidak perlu perubahan**
- `price` sudah menyimpan harga satuan saat transaksi
- Tidak perlu追溯 quantity break yang dipakai (kecuali untuk analisa)

---

## 7. Perubahan UI

### 7.1. Master Produk — Halaman Form
```
┌──────────────────────────────────────┐
│  Unit: Pcs                          │
│  ┌────────────────────────────────┐  │
│  │ Qty ≥ 1    │ Rp [___________] │  │
│  │ Qty ≥ 10   │ Rp [___________] │  │
│  │ Qty ≥ 50   │ Rp [___________] │  │
│  │ [+ Tambah Baris]              │  │
│  └────────────────────────────────┘  │
│                                      │
│  Unit: Dus                           │
│  ┌────────────────────────────────┐  │
│  │ Qty ≥ 1    │ Rp [___________] │  │
│  │ Qty ≥ 5    │ Rp [___________] │  │
│  │ [+ Tambah Baris]              │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 7.2. POS — Tampilan Harga di Modal Produk
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

### 7.3. POS — Tampilan di Keranjang
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
| `changePriceTier()` | Bisa dihapus atau diubah jadi override global (jika price_tier masih dipakai) |

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

## 9. Poin Diskusi

1. **Price tier existing mau diapakan?**
   - Harga Umum / Grosir yang sekarang: dihapus, diubah jadi quantity break, atau dipertahankan sebagai kategori?
   - Contoh: "Harga Grosir" bisa direpresentasikan sebagai break min_qty tertentu.

2. **Override manual tetap ada?**
   - Cashier tetap bisa input harga manual untuk situasi khusus (misal harga deal khusus)?
   - Jika iya, tampilkan peringatan "Harga berbeda dari standar" saat override.

3. **Quantity break di keranjang?**
   - Jika user tambah qty di keranjang (bukan di modal), apakah harga ikut berubah otomatis?
   - Atau harga mengunci saat item pertama masuk keranjang?

4. **Multi-unit dengan quantity break?**
   - Harga per unit dihitung terpisah.
   - Tapi jika user punya 15 Pcs, apa boleh dikonversi ke 1 Dus + 5 Pcs dengan harga break masing-masing?

5. **Perlakuan harga 0?**
   - Jika quantity break dengan harga 0 → diabaikan (tidak valid).
   - Atau harga 0 dianggap gratis?

6. **History transaksi lama?**
   - `order_items` sudah menyimpan `price` final — tidak masalah.
   - Tapi tidak ada info quantity break mana yang dipakai → mungkin perlu tambah kolom `min_qty_applied`?

---

## 10. Prioritas

| Priority | Item | Complexity |
|----------|------|------------|
| P0 | Ubah `_getPriceForUnit()` di cart_cubit agar terima parameter qty | Low |
| P0 | Update form produk: input quantity breaks | Medium |
| P1 | Re-calculate price saat qty berubah di modal produk | Low |
| P1 | Tampilkan keterangan break aktif di modal | Low |
| P2 | Re-calculate price saat qty berubah di keranjang | Medium |
| P2 | Hapus/deprecate price tier UI (Harga Umum/Grosir toggle) | Low |
| P3 | Tambah kolom `min_qty_applied` di order_items (untuk analisa) | Low |
