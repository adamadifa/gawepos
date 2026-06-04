# Product Requirements Document (PRD) — posmobile Standalone

Aplikasi **posmobile** adalah aplikasi kasir (Point of Sale) mobile berbasis Android yang berjalan secara mandiri (**standalone / offline-first**) tanpa bergantung pada koneksi internet atau API server eksternal. Konsep fitur, logika bisnis, dan struktur datanya diselaraskan dengan sistem web **mypos**.

---

## 1. Profil & Tujuan Produk
- **Nama Proyek**: posmobile
- **Target Platform**: Android (Handphone & Tablet)
- **Metode Deploy**: Install langsung menggunakan file `.apk` (secara lokal/offline).
- **Tujuan Utama**: Membantu UMKM/toko mengelola transaksi kasir, inventori barang, pencatatan biaya, pencatatan hutang/piutang, serta laporan keuangan harian secara mandiri di satu perangkat tablet atau handphone tanpa memerlukan server internet.

---

## 2. Arsitektur Teknologi (Tech Stack)

| Komponen | Pilihan Teknologi | Deskripsi & Kelebihan |
| :--- | :--- | :--- |
| **Framework UI** | **Flutter (Dart)** | Performa tinggi, native rendering, mempermudah pembuatan UI responsif untuk tablet & smartphone. |
| **Local Database** | **Drift (SQLite)** | Database relasional lokal yang aman, memiliki *compile-time safety*, meminimalkan resiko data inkonsisten, dan mendukung transaksi SQL kompleks. |
| **State Management** | **Flutter BLoC / Cubit** | Pengelolaan state terstruktur, memisahkan logika bisnis (keranjang belanja, validasi stok) dari UI. |
| **Penyimpanan Lokal** | **path_provider** + **shared_preferences** | Menyimpan preferensi aplikasi (opsi printer, lisensi, filter default) dan gambar produk lokal. |
| **Cetak Struk** | **blue_thermal_printer** + **esc_pos_utils_plus** | Integrasi thermal printer Bluetooth (ukuran kertas 58mm / 80mm). |
| **Scanner Barcode** | **mobile_scanner** + **Hardware Keyboard Listener** | Scanner menggunakan kamera perangkat atau scanner fisik Bluetooth/USB OTG. |
| **Laporan & Ekspor** | **pdf** | Membuat cetak dokumen/invoice PDF lokal untuk dibagikan ke WhatsApp / Email. |
| **Backup & Restore** | **JSON / Binary SQLite File** | Ekspor seluruh isi database menjadi file terenkripsi untuk backup eksternal. |

---

## 3. Fitur Utama & Spesifikasi Fungsional

### 1. Registrasi & Onboarding Toko (Pertama Kali Buka App)
- Mendeteksi apakah database lokal kosong. Jika kosong, arahkan ke wizard onboarding.
- Input data toko: Nama Toko, Alamat, No. Telp, Tarif Pajak Default.
- Pembuatan akun admin pertama dengan **PIN login 4-6 digit** (tidak memakai password teks agar kasir mudah login di layar sentuh).

### 2. Autentikasi PIN & Manajemen Sesi Kasir
- Layanan Login Kasir berbasis PIN lokal.
- Menu Buka Shift: Kasir harus menginput nominal **Uang Modal Awal** di laci sebelum mulai transaksi.
- Menu Tutup Shift: Kasir memasukkan nominal **Uang Fisik Akhir** di laci. Sistem akan menghitung otomatis selisih kas (*expected* vs *actual*).

### 3. Manajemen Master Data (Produk, Satuan, Harga & Kontak)
- **Kategori & Brand**: Tambah, ubah, dan hapus data kategori/brand secara lokal.
- **Produk**:
  - SKU (unik), Nama, Deskripsi, Barcode/EAN, Status Aktif.
  - Gambar produk (diambil lewat kamera atau galeri HP, disimpan di folder internal storage aplikasi).
  - Manajemen Multi-Unit (Pcs, Box, Pack, dst.) dengan faktor konversi satuan.
- **Price Tiers**: Mendukung banyak level harga per unit produk (misal: Harga Umum, Grosir, Pelanggan VIP).
- **Kontak**: Pengelolaan data Pelanggan (Customers) dan Pemasok (Suppliers) lokal.

### 4. Sistem Kasir (Point of Sale - POS)
- Tampilan kasir responsif (dioptimalkan untuk tablet lanskap atau handphone potret).
- Pencarian produk cepat dengan: Ketik Nama/SKU, Filter Kategori, atau Scan Barcode (kamera / alat scanner eksternal).
- **Kalkulasi Keranjang**:
  - Menghitung subtotal otomatis berdasarkan unit dan harga tier yang dipilih untuk pelanggan terkait.
  - Diskon per baris item (nominal/persentase) atau diskon global pada keranjang belanja.
  - Perhitungan pajak toko otomatis.
- **Tahan Transaksi (Hold & Recall)**: Menyimpan keranjang belanja sementara (draft) dan memuatnya kembali nanti.
- **Pembayaran**:
  - Cash (input uang bayar, hitung kembalian).
  - QRIS Statis (menampilkan gambar QRIS toko dari penyimpanan untuk di-scan pelanggan).
  - Kartu Debit/Kredit / Transfer Bank.
  - Pembayaran terpisah (Split Payment).
- **Cetak Struk**: Cetak otomatis/manual ke printer Bluetooth setelah bayar sukses.

### 5. Inventori & Audit Trail
- Stok produk diperbarui secara otomatis ketika terjadi:
  - Penjualan kasir (stok berkurang).
  - Restok barang masuk lewat pembelian (stok bertambah).
  - Stock Opname (penyesuaian stok fisik secara manual).
- **Stock Movement Log**: Setiap perubahan stok wajib mencatat alasan, nomor referensi dokumen, jumlah mutasi, dan waktu kejadian.

### 6. Pembelian ke Supplier (Purchasing)
- Membuat dokumen Pembelian (Purchase Order) lokal.
- Pencatatan harga modal beli per produk/unit.
- Penerimaan barang untuk memperbarui stok lokal dan memperbarui estimasi HPP barang.

### 7. Pengeluaran Biaya (Expenses) & Keuangan
- Pencatatan pengeluaran uang laci kasir untuk pengeluaran operasional (seperti beli bensin, plastik, perlengkapan toko).
- Laporan arus kas harian (*Cash Flow*).

### 8. Laporan & Dashboard Owner
- Ringkasan harian di dashboard: Total Penjualan, Keuntungan Bersih (Grand Total - Modal HPP - Beban Biaya), Jumlah Transaksi, dan Barang Terlaris.
- Laporan Penjualan per Periode (Hari, Minggu, Bulan).
- Laporan Stok & Estimasi Nilai Aset.
- Laporan Laba Rugi sederhana.
- Ekspor laporan dalam bentuk dokumen PDF.

---

## 4. Desain Skema Database (SQLite / Drift)

Skema database SQLite lokal dirancang relasional untuk menjamin integritas data (Foreign Key, Cascade Delete, Transaksi Aman).

```sql
-- 1. Tabel Profil Outlet
CREATE TABLE outlets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    tax_percentage REAL DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabel Users (Kasir / Admin)
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    username TEXT NOT NULL UNIQUE,
    pin_hash TEXT NOT NULL, -- PIN terenkripsi/hash secara lokal
    role TEXT NOT NULL, -- 'admin', 'cashier'
    is_active INTEGER DEFAULT 1, -- Boolean
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabel Kategori & Brand
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE brands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Tabel Produk Utama
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_id INTEGER REFERENCES brands(id) ON DELETE SET NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    sku TEXT UNIQUE,
    barcode TEXT,
    description TEXT,
    image_path TEXT, -- Path ke file lokal di storage aplikasi
    product_type TEXT DEFAULT 'goods', -- 'goods', 'service'
    is_stock_managed INTEGER DEFAULT 1,
    min_stock_alert INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabel Satuan Unit Produk
CREATE TABLE product_units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- e.g. "Pcs", "Box"
    conversion_factor REAL DEFAULT 1.0, -- 1.0 untuk satuan terkecil
    is_base INTEGER DEFAULT 0 -- 1 jika unit terkecil/dasar
);

-- 6. Tabel Price Tiers & Product Prices
CREATE TABLE price_tiers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL
);

CREATE TABLE product_prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_id INTEGER NOT NULL REFERENCES product_units(id) ON DELETE CASCADE,
    price_tier_id INTEGER NOT NULL REFERENCES price_tiers(id) ON DELETE CASCADE,
    price REAL DEFAULT 0.0,
    min_qty INTEGER DEFAULT 1
);

-- 7. Tabel Kontak (Pelanggan & Supplier)
CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT
);

CREATE TABLE suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT
);

-- 8. Tabel Inventori & Mutasi Stok
CREATE TABLE inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    unit_id INTEGER NOT NULL REFERENCES product_units(id) ON DELETE CASCADE,
    quantity REAL DEFAULT 0.0
);

CREATE TABLE stock_movements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id),
    unit_id INTEGER NOT NULL REFERENCES product_units(id),
    quantity REAL NOT NULL, -- Positif masuk, Negatif keluar
    type TEXT NOT NULL, -- 'sale', 'purchase', 'opname', 'void'
    reference_no TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Tabel Sesi Kasir (Shift)
CREATE TABLE cashier_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    open_time TIMESTAMP NOT NULL,
    close_time TIMESTAMP,
    opening_cash REAL NOT NULL,
    closing_cash REAL,
    expected_cash REAL,
    difference_amount REAL,
    status TEXT DEFAULT 'open' -- 'open', 'closed'
);

-- 10. Tabel Penjualan (Orders, Items, Payments)
CREATE TABLE orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
    cashier_session_id INTEGER NOT NULL REFERENCES cashier_sessions(id),
    reference_no TEXT NOT NULL UNIQUE,
    status TEXT DEFAULT 'completed', -- 'completed', 'void'
    subtotal REAL DEFAULT 0.0,
    discount_amount REAL DEFAULT 0.0,
    tax_amount REAL DEFAULT 0.0,
    grand_total REAL DEFAULT 0.0,
    paid_amount REAL DEFAULT 0.0,
    change_amount REAL DEFAULT 0.0,
    payment_status TEXT DEFAULT 'paid', -- 'paid', 'partial', 'unpaid'
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    unit_id INTEGER NOT NULL REFERENCES product_units(id),
    quantity REAL NOT NULL,
    price REAL NOT NULL,
    discount_amount REAL DEFAULT 0.0,
    subtotal REAL NOT NULL
);

CREATE TABLE order_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL, -- 'cash', 'qris', 'card', 'transfer'
    amount REAL NOT NULL,
    reference_id TEXT
);

-- 11. Tabel Tahan Transaksi (Hold Orders)
CREATE TABLE pos_held_orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
    reference_no TEXT NOT NULL,
    cart_data TEXT NOT NULL, -- Format JSON berisi data barang belanjaan
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 12. Tabel Pengeluaran Operasional (Expenses)
CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_name TEXT NOT NULL,
    amount REAL NOT NULL,
    description TEXT,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 13. Tabel Pengaturan (Settings)
CREATE TABLE settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    value TEXT
);
```
