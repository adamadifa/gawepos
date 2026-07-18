# Checklist Fase 1 — Integritas Data & Keselamatan

## 1.1 Enable Foreign Key, WAL & PRAGMA Tuning

- [ ] Tambah `PRAGMA foreign_keys = ON` di `beforeOpen`
- [ ] Tambah `PRAGMA journal_mode = WAL` di `_openConnection()`
- [ ] Tambah `PRAGMA synchronous = NORMAL`
- [ ] Tambah `PRAGMA cache_size = -64000` (64MB cache)
- [ ] Tambah `PRAGMA temp_store = MEMORY`
- [ ] Jalankan `flutter test` — verifikasi cascade delete bekerja
- [ ] Jalankan `flutter analyze`

## 1.2 Hapus `try/catch` Buta di `beforeOpen`

- [ ] Verifikasi kolom `payment_type` dan `down_payment` sudah ada di migrasi v3→v4
- [ ] Hapus blok `try/catch` legacy yang pakai `PRAGMA table_info`
- [ ] Jalankan `flutter test` — pastikan migrasi dari versi lama tetap jalan
- [ ] Jalankan `flutter analyze`

## 1.3 Konversi Uang ke Integer Sen (Tanya User)

> **Catatan**: Ini migrasi besar (schema v7 → v8). Alternatif: tetap real column
> tapi rounding manual di Dart.

- [ ] Tanya user apakah mau lanjut atau skip
- [ ] Jika lanjut:
  - [ ] Ubah semua `RealColumn` untuk uang → `IntColumn`
  - [ ] Bump `schemaVersion` ke 8
  - [ ] Tambah migrasi v7→v8: konversi data dari real ke sen
  - [ ] Ubah semua kode Dart yang membaca/menulis nilai uang ÷100
  - [ ] `flutter test` — verifikasi semua kalkulasi
  - [ ] `flutter analyze`

## Final Verifikasi

- [ ] `flutter test` — semua lulus
- [ ] `flutter analyze` — 0 error, 0 warning
- [ ] `dart run build_runner build --delete-conflicting-outputs` — regenerasi sukses
