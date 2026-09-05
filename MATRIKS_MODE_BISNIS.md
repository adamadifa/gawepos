# Matriks Mode Operasional Bisnis — GawePOS

Dokumen ini menjelaskan perbedaan perilaku fitur, antarmuka, dan alur kerja aplikasi **GawePOS** berdasarkan mode bisnis yang dipilih oleh pengguna pada menu **Pengaturan > Profil & Mode Operasional Bisnis**.

---

## 📊 Tabel Matriks Perbedaan Fitur

| Modul / Fitur | 🏪 Mode Retail & Minimarket | ☕ Mode F&B, Kafe & Restoran | ⚡ Mode Campuran (All-in-One) |
| :--- | :--- | :--- | :--- |
| **Target Usaha** | Toko Kelontong, Minimarket, Sembako, Counter Pulsa/HP, Toko Pakaian, Toko Bangunan & Alat Tulis. | Kedai Kopi (Coffee Shop), Restoran, Cafe, Bakery, Booth Minuman & Snack Makanan. | Usaha Kombinasi (Restoran + Pusat Oleh-oleh, Minimarket + Coffee Corner, dsb). |
| **Katalog Master Produk** | **Daftar Produk** (Barang jadi / kemasan pabrik). | **Katalog Menu F&B** (Makanan, Minuman & Varian). | **Semua Jenis Produk** (Barang Jadi, Jasa & Bahan Baku). |
| **Menu Bahan Baku & Mentah** | ❌ **Disembunyikan** dari menu utama agar navigasi tetap ringkas dan fokus. | ✅ **Aktif Penuh** (Biji kopi, susu, sirup, gula cair, cup, sedotan, dsb). | ✅ **Aktif Penuh** |
| **Form Produk — Komposisi Resep (BOM)** | ❌ **Disembunyikan** pada form produk sehingga input barang lebih cepat. | ✅ **Aktif** (Otomatis menghitung estimasi HPP porsi dari harga modal bahan baku). | ✅ **Aktif** (Bisa dipilih jika produk memerlukan racikan). |
| **Mekanisme Pemotongan Stok POS** | Memotong stok fisik **barang jadi** langsung saat checkout kasir. | Memotong stok **bahan baku racikan** secara otomatis berdasarkan komposisi resep menu. | Mendukung kedua metode pemotongan stok (stok barang langsung maupun pemotongan bahan baku). |
| **Laporan Kartu Stok & Persediaan** | Fokus monitoring mutasi barang dagangan jadi. | Tersedia tab filter pemisah (*Barang Jadi* vs *Bahan Baku*). | Tersedia tab filter lengkap (*Semua*, *Barang Jadi*, *Bahan Baku*). |
| **Barcode & QR Scanner** | ✅ **Prioritas Utama** (Scan cepat kode batang barcode EAN-13 / UPC pabrik). | ⚡ **Opsional** (Pemilihan menu kasir lebih sering melalui grid kategori / foto produk). | ✅ **Prioritas & Aktif Penuh** |
| **Multi-Satuan & Harga Grosir** | ✅ **Aktif Penuh** (Pcs, Renceng, Lusin, Slop, Dus, Karton) dengan harga bertingkat kuantitas. | ⚡ **Sederhana** (Cup, Botol, Porsi, Pack). | ✅ **Aktif Penuh** |
| **Titip Jual (Konsinyasi)** | ✅ **Aktif** (Titipan aneka keripik, roti keliling, rokok vendor). | ✅ **Aktif** (Titipan pastry/cake mitra luar). | ✅ **Aktif Penuh** |
| **Generator Data Dummy (Seeder)** | Menyediakan seeder **100 Produk Retail** (Sembako, snack, sabun, multi-satuan & grosir). | Menyediakan seeder **15 Menu Kedai Kopi** + **23 Bahan Baku** lengkap dengan komposisi resep BOM. | Tersedia kedua opsi generator data dummy. |

---

## 💡 Keuntungan Pemisahan Mode Bisnis

1. **User Experience Bersih & Cepat**:
   - Toko kelontong/retail tidak dibingungkan oleh input gramasi resep, bahan mentah, atau istilah racikan F&B yang tidak relevan.
   - Usaha kafe/resto langsung disuguhkan alur pembuatan menu dengan perhitungan modal HPP dan pemotongan stok bahan baku mentah.
2. **Fleksibilitas Tanpa Batas**:
   - Mode dapat diganti kapan saja tanpa kehilangan data transaksi, stok, maupun pelanggan yang sudah ada di database lokal SQLite.
3. **Penyimpanan Lokal (Offline-First)**:
   - Status mode disimpan langsung di tabel `settings` lokal dengan key `business_mode` (`'all'`, `'retail'`, `'fnb'`).

---

## 🛠️ Cara Mengubah Mode Bisnis di Aplikasi

1. Buka menu **Pengaturan** di pojok kanan atas aplikasi.
2. Pilih kartu **Profil & Mode Operasional Bisnis**.
3. Pada bagian **Mode Operasional Bisnis**, pilih salah satu mode yang sesuai dengan jenis toko Anda.
4. Tekan tombol **SIMPAN PROFIL TOKO**. Tampilan menu master data dan formulir produk akan otomatis menyesuaikan dengan mode yang dipilih.
