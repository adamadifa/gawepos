# 🚀 Roadmap Fitur Unggulan UMKM — GawePOS

Dokumen ini berisi rencana spesifikasi teknis dan analisis kebutuhan fitur-fitur lanjutan untuk memperkuat kapabilitas **GawePOS** sebagai aplikasi POS & Inventori offline-first terbaik bagi UMKM Indonesia (Retail, Grosir, F&B, dan Jasa).

---

## 📋 Daftar Rencana Fitur

### 1. 📲 Struk Digital via WhatsApp (Paperless POS)
* **Kategori**: Transaksi & Loyalitas Pelanggan
* **Urgensi**: ⭐⭐⭐⭐⭐ (Sangat Tinggi)
* **Deskripsi**:
  Fitur pengiriman struk belanja digital langsung ke nomor WhatsApp pelanggan tanpa memerlukan langganan API berbayar (menggunakan WhatsApp URL Scheme `https://wa.me/`).
* **Fitur Utama**:
  - Tombol **"Kirim Struk WA"** pada halaman `PaymentSuccessPage` dan detail riwayat transaksi.
  - Template pesan terstruktur: nama toko, alamat, no. nota, rincian barang, diskon, pajak, total, metode bayar, dan catatan toko.
  - Opsi auto-detect nomor telepon jika pelanggan sudah dipilih dari database kontak.

---

### 2. 🧮 Resep & Bahan Baku (Bill of Materials / BOM untuk F&B) `[SELESAI]`
* **Kategori**: Inventori & Manufaktur Sederhana
* **Urgensi**: ⭐⭐⭐⭐⭐ (Tinggi)
* **Deskripsi**:
  Memungkinkan satu produk jadi (contoh: *Es Kopi Susu Aren*) tersusun dari beberapa bahan baku (misal: *Biji Kopi*, *Susu UHT*, *Gula Aren*, *Cup 16oz*, *Sedotan*).
* **Fitur Utama**:
  - Penanda tipe produk: `Barang Jadi`, `Bahan Baku (Raw Material)`, atau `Jasa (Service)`.
  - Matriks racikan komposisi resep per produk dengan takaran kuantitas dan satuan (gr, ml, pcs).
  - Auto-deduct: Stok bahan baku otomatis berkurang di gudang saat kasir menyelesaikan penjualan menu racikan di POS.
  - Perhitungan HPP otomatis secara realtime berdasarkan akumulasi modal bahan baku yang digunakan.

---

### 3. 💳 Multi-Pembayaran & Split Bill `[SELESAI]`
* **Kategori**: Kasir & Pembayaran
* **Urgensi**: ⭐⭐⭐⭐ (Tinggi)
* **Deskripsi**:
  Mendukung skenario pembayaran fleksibel yang sering terjadi di restoran, kafe, dan retail.
* **Fitur Utama**:
  - **Split Payment (Campur Metode Bayar)**: Pembayaran satu nota dengan kombinasi beberapa metode bayar (contoh: Rp 50.000 Tunai + Rp 75.000 QRIS/Kartu) di [`payment_page.dart`](lib/features/pos/presentation/pages/payment_page.dart).
  - **Split Bill (Pisah Tagihan)**: Memisahkan satu pesanan meja menjadi 2 atau lebih tagihan terpisah untuk pelanggan yang ingin bayar masing-masing di [`split_bill_page.dart`](lib/features/pos/presentation/pages/split_bill_page.dart).

---

### 4. 🏷️ Paket Promo Bundling & Grosir Bertingkat (Tiered Pricing)
* **Kategori**: Penjualan & Promosi
* **Urgensi**: ⭐⭐⭐⭐ (Sedang-Tinggi)
* **Deskripsi**:
  Meningkatkan omzet penjualan melalui strategi promosi paket hemat dan harga khusus kuantitas banyak.
* **Fitur Utama**:
  - **Paket Combo/Bundling**: Beli Produk A + Produk B dengan harga spesial paket.
  - **Harga Grosir Otomatis**: Penyesuaian harga otomatis di kasir berdasarkan jumlah belanjaan (contoh: Beli 1 pcs Rp 10.000, beli ≥ 12 pcs Rp 8.500).

---

### 5. ⏳ Pengingat Jatuh Tempo Hutang & Piutang (Due Date Alert)
* **Kategori**: Manajemen Keuangan
* **Urgensi**: ⭐⭐⭐⭐ (Sedang)
* **Deskripsi**:
  Membantu pelaku UMKM memantau dan menagih piutang pelanggan serta melunasi hutang supplier tepat waktu.
* **Fitur Utama**:
  - Input tanggal jatuh tempo pada saat transaksi hutang/piutang dicatat.
  - Indikator status: *Belum Jatuh Tempo*, *Jatuh Tempo Hari Ini*, *Terlambat/Overdue*.
  - Tombol aksi cepat: *Kirim Pesan Tagihan Sopan via WhatsApp*.

---

### 6. 📴 Backup & Restore Cloud / Google Drive
* **Kategori**: Keamanan Sistem & Database
* **Urgensi**: ⭐⭐⭐⭐⭐ (Sangat Penting)
* **Deskripsi**:
  Menghilangkan kekhawatiran UMKM terhadap kehilangan data transaksi lokal saat perangkat rusak, hilang, atau ganti perangkat baru.
* **Fitur Utama**:
  - Ekspor terenkripsi database SQLite ke penyimpanan internal / Google Drive.
  - Restore data dengan verifikasi integritas file.
  - Opsi auto-backup mingguan saat aplikasi ditutup.

---

## 🎯 Rekomendasi Urutan Implementasi

| Fase | Fitur | Perkiraan Kompleksitas | Dampak ke Pengguna |
|---|---|---|---|
| **Fase 1** | 📲 Struk WhatsApp & 📴 Backup Cloud | Rendah - Sedang | ⭐⭐⭐⭐⭐ Sangat Tinggi |
| **Fase 2** | 🏷️ Grosir Bertingkat & 💳 Split Payment | Sedang | ⭐⭐⭐⭐ Tinggi |
| **Fase 3** | 🧮 Manajemen Resep / BOM (F&B) | Sedang - Kompleks | ⭐⭐⭐⭐⭐ Sangat Tinggi |
