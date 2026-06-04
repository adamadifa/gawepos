# Tahapan Pengembangan & Checklist Tugas — posmobile

Dokumen ini berisi panduan langkah-demi-langkah (step-by-step) untuk memandu proses pembuatan aplikasi **posmobile** menggunakan Flutter dan Drift (SQLite) secara offline-first.

---

## 📅 Ringkasan Garis Waktu Pengembangan

```mermaid
gantt
    title Peta Jalan Pengembangan posmobile (Offline)
    dateFormat  YYYY-MM-DD
    axisFormat  %d %b

    section Tahap Dasar & DB
    Tahap 1: Setup Proyek & Struktur     :active, t1, 2026-06-03, 2d
    Tahap 2: Database Drift & Migrasi   :t2, after t1, 3d
    Tahap 3: Logika Autentikasi & Sesi   :t3, after t2, 2d

    section CRUD Master Data
    Tahap 4: UI & CRUD Master Data       :t4, after t3, 4d
    Tahap 5: Inventori & Mutasi Stok    :t5, after t4, 3d

    section Layanan POS & Cetak
    Tahap 6: Kasir (POS) & Hitung Diskon :t6, after t5, 5d
    Tahap 7: Integrasi Bluetooth Thermal :t7, after t6, 3d

    section Fitur Tambahan & Rilis
    Tahap 8: Keuangan & Pembelian        :t8, after t7, 4d
    Tahap 9: Laporan, PDF & Dashboard    :t9, after t8, 3d
    Tahap 10: Backup, Uji Coba & Rilis APK :t10, after t9, 3d
```

---

## 🛠️ Detail Tahapan & Checklist Tugas

### Tahap 1: Setup Proyek & Fondasi Aplikasi
*Fokus: Inisialisasi proyek Flutter, konfigurasi pustaka (dependencies), dan pengaturan folder arsitektur.*
- [x] 1.1 Buat proyek Flutter baru di direktori `posmobile` menggunakan command: `flutter create --org com.mypos.posmobile --project-name posmobile ./`
- [x] 1.2 Edit berkas `pubspec.yaml` untuk mengimpor paket-paket utama:
  - **Database & Model**: `drift`, `sqlite3_flutter_libs`, `path_provider`, `path` (dependensi dev: `drift_dev`, `build_runner`).
  - **State Management**: `flutter_bloc` atau `flutter_riverpod`, `get_it` (Dependency Injection).
  - **Utilitas**: `intl` (format uang/tanggal), `uuid`, `crypto` (enkripsi PIN kasir), `share_plus` (bagikan PDF).
  - **Hardware & UI**: `blue_thermal_printer`, `esc_pos_utils_plus`, `mobile_scanner`, `pdf`, `fl_chart`.
- [x] 1.3 Setup struktur folder Clean Architecture sederhana:
  - `lib/core/` (database, tema warna, utilitas cetak, konstanta).
  - `lib/features/auth/` (login PIN, sesi kasir).
  - `lib/features/pos/` (keranjang belanja, layar kasir, pembayaran).
  - `lib/features/master/` (produk, kategori, supplier, pelanggan).
  - `lib/features/inventory/` (stok barang, riwayat mutasi stok).
  - `lib/features/reports/` (dashboard owner, ekspor PDF).

---

### Tahap 2: Database Drift & Migrasi
*Fokus: Mendefinisikan tabel-tabel lokal dengan Drift dan men-generate berkas kode Dart.*
- [x] 2.1 Buat berkas database Drift di `lib/core/database/app_database.dart`.
- [x] 2.2 Tulis kelas skema tabel Drift untuk:
  - `Outlets`, `Users`
  - `Categories`, `Brands`, `Products`, `ProductUnits`, `ProductPrices`, `PriceTiers`
  - `Customers`, `Suppliers`
  - `Inventory`, `StockMovements`
  - `CashierSessions`
  - `Orders`, `OrderItems`, `OrderPayments`, `PosHeldOrders`
  - `Expenses`, `Settings`
- [x] 2.3 Jalankan kode generator dengan command: `dart run build_runner build --delete-conflicting-outputs` untuk menghasilkan berkas `app_database.g.dart`.
- [x] 2.4 Tulis kelas data seed awal (default Admin User, default Outlet, default Price Tier, default Expense Category) untuk dimasukkan ke database saat pertama kali diinisialisasi.

---

### Tahap 3: Logika Autentikasi PIN & Manajemen Shift
*Fokus: Mengamankan akses kasir lokal dan memastikan laci kas terpantau sebelum bertransaksi.*
- [x] 3.1 Buat sistem enkripsi/hash sederhana untuk mengamankan PIN kasir (menggunakan `SHA-256` dari paket `crypto`).
- [x] 3.2 Implementasikan layar Onboarding (hanya muncul saat data Outlet masih kosong) untuk mengisi profil toko awal dan membuat PIN administrator pertama kali.
- [x] 3.3 Buat halaman Login PIN yang memverifikasi kecocokan input dengan database lokal.
- [x] 3.4 Buat dialog/layar "Buka Shift Kasir" untuk menginput kas awal di laci.
- [x] 3.5 Buat layar status shift saat ini (menampilkan detail kasir aktif dan jumlah uang tunai teoretis).

---

### Tahap 4: UI & CRUD Master Data
*Fokus: Membangun halaman pengelolaan barang, kategori, satuan, harga tier, dan kontak pelanggan.*
- [x] 4.1 CRUD Kategori & Brand: Layar daftar, tambah, dan ubah data.
- [x] 4.2 CRUD Produk:
  - Form input detail produk (SKU, Nama, Kategori, Brand).
  - Mengambil foto produk dengan kamera perangkat atau memilih dari galeri menggunakan `image_picker`, lalu menyimpan berkas gambar ke folder dokumen aplikasi dan mencatat jalurnya di field `image_path` database.
- [x] 4.3 Setup Multi-Satuan (Units) pada produk dengan repeater form (contoh: Pcs sebagai base unit, Box berisi 24 Pcs).
- [x] 4.4 Setup Pricing Matrix: Layar input harga jual berdasarkan kombinasi Satuan Unit × Price Tiers.
- [x] 4.5 CRUD Pelanggan (Customers) & Pemasok (Suppliers).

---

### Tahap 5: Inventori & Audit Trail
*Fokus: Mengaktifkan pemantauan stok barang dan mencatat setiap pergerakan.*
- [x] 5.1 Buat repositori inventori untuk mengambil data stok berjalan per produk/unit.
- [x] 5.2 Hubungkan logika mutasi stok: setiap ada transaksi penjualan atau pembelian barang, buat record baru di tabel `stock_movements`.
- [x] 5.3 Buat layar kartu stok barang (menampilkan riwayat masuk/keluar produk terpilih).
- [x] 5.4 Buat fitur Stock Opname (Penyesuaian stok): Halaman untuk menginput jumlah fisik barang riil, menghitung selisih, dan menyimpannya sebagai mutasi opname.

---

### Tahap 6: Modul Penjualan Kasir (POS)
*Fokus: Membuat antarmuka kasir yang responsif, cepat, reaktif, dan andal.*
- [x] 6.1 Desain antarmuka POS (bisa berganti layout otomatis: Tablet Lanskap dual-panel, Handphone Potret multi-langkah).
- [x] 6.2 Buat pencarian produk berdasarkan nama, kategori, serta pemindaian barcode dengan paket `mobile_scanner`.
- [x] 6.3 Implementasikan Logika Keranjang Belanja (Cart) reaktif menggunakan BLoC:
  - Menghitung diskon item dan diskon global.
  - Menyesuaikan harga produk berdasarkan level harga pelanggan terpilih (*Price Tier*).
- [x] 6.4 Buat fitur Tahan Transaksi (*Hold & Recall*) menggunakan JSON serialization ke tabel `pos_held_orders`.
- [x] 6.5 Buat halaman Pembayaran:
  - Menampilkan total tagihan, input pembayaran tunai dengan tombol nominal instan (e.g. uang pas, 50rb, 100rb).
  - Pilihan metode non-tunai (Kartu EDC, Transfer, QRIS Statis).
  - Mendukung metode pembayaran terpisah (*Split Payment*).
- [x] 6.6 Validasi akhir checkout dalam transaksi database: menyimpan order, item order, payment order, dan melakukan pengurangan stok di tabel inventori secara bersamaan (*atomic transaction*).

---

### Tahap 7: Integrasi Bluetooth Thermal Printer & Struk
*Fokus: Mencetak bukti transaksi langsung dari perangkat Android ke printer kertas mini.*
- [x] 7.1 Layar Pengaturan Printer: Cari perangkat Bluetooth, pasangkan (pair), hubungkan, dan simpan alamat MAC printer terpilih ke tabel `settings`.
- [x] 7.2 Implementasikan pustaka `esc_pos_utils_plus` untuk mendesain format struk belanja:
  - Header: Nama Toko, Alamat, Telepon, Tanggal, No. Nota, Nama Kasir.
  - Body: List item belanja (Nama barang, kuantitas × harga, total).
  - Footer: Subtotal, Diskon, Pajak, Grand Total, Nominal Bayar, Kembalian, kalimat terima kasih.
- [x] 7.3 Tambahkan tombol untuk mencetak struk secara otomatis saat pembayaran selesai, serta tombol cetak ulang (*re-print*) pada riwayat pesanan.

---

### Tahap 8: Keuangan & Restok Pembelian
*Fokus: Mencatat kas keluar dan mengelola supply barang masuk secara terstruktur.*
- [x] 8.1 Modul Pengeluaran (Expenses): Form input pengeluaran uang kas kasir harian (memilih jenis beban operasional, jumlah uang, dan catatan keterangan).
- [x] 8.2 Modul Pembelian (Purchases):
  - [x] Form pembuatan pemesanan barang ke Pemasok (Supplier).
  - [x] Input kuantitas dan harga beli/modal per unit.
  - [x] Konfirmasi penerimaan barang untuk otomatis menambah stok di tabel `inventory` dan menulis pergerakan di `stock_movements`.

---

### Tahap 9: Laporan, PDF & Dashboard
*Fokus: Menyajikan data operasional menjadi laporan keuangan sederhana yang mudah dipahami.*
- [ ] 9.1 Dashboard Owner:
  - Statistik ringkasan penjualan, profit kotor, profit bersih, jumlah struk hari ini.
  - Grafik tren penjualan harian menggunakan pustaka `fl_chart`.
  - Daftar produk paling laris dan produk yang stoknya menipis (di bawah `min_stock_alert`).
- [ ] 9.2 Laporan Kasir / Shift: Laporan sisa uang laci dan riwayat selisih kas per shift.
- [ ] 9.3 Laporan Laba Rugi sederhana (*P&L Report*): Penjualan Kotor - Diskon/Pajak - Harga Pokok Penjualan (HPP) - Biaya Operasional.
- [ ] 9.4 Fitur Ekspor Laporan: Konversi laporan ke format dokumen PDF menggunakan paket `pdf` dan bagikan langsung ke aplikasi lain dengan `share_plus`.

---

### Tahap 10: Backup-Restore, Uji Coba & Rilis APK
*Fokus: Menjamin keamanan cadangan data, kestabilan aplikasi, dan kompilasi final.*
- [x] 10.1 Fitur Backup Data: Mengubah isi seluruh tabel database menjadi file JSON terenkripsi (atau copy langsung file biner `.db` SQLite) dan menyimpannya ke folder publik eksternal (Unduhan) agar bisa disalin user.
- [x] 10.2 Fitur Restore Data: Membaca file cadangan, mendekripsinya, memvalidasi integritas struktur, dan menimpa database lokal yang aktif.
- [x] 10.3 Jalankan automated testing untuk memvalidasi engine perhitungan diskon, perpajakan, dan transaksi database.
- [x] 10.4 Bangun aplikasi final (Release APK) menggunakan perintah:
  `flutter build apk --release` atau `flutter build appbundle --release` (jika ingin diunggah ke Google Play Store).
