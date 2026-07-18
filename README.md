# GawePOS (posmobile) - Offline-First Flutter POS App

Aplikasi Kasir (Point of Sale) mobile berbasis Flutter dengan pendekatan *offline-first* yang dirancang khusus untuk UMKM Indonesia. Aplikasi ini mengintegrasikan basis data lokal SQLite (menggunakan Drift), pemindaian barcode cepat, pencetakan struk via bluetooth thermal printer, serta pengelolaan stok dan laporan keuangan secara mandiri.

---

## 🛠️ Prasyarat Instalasi (Prerequisites)

Sebelum menjalankan atau membangun proyek ini di komputer baru, pastikan Anda telah memasang alat-alat berikut:

### 1. Git
Digunakan untuk mengunduh kode dari repositori dan mengelola versi kode.
* [Unduh Git](https://git-scm.com/downloads)

### 2. Flutter SDK
Gunakan Flutter SDK versi stabil (*stable channel*). Direkomendasikan versi **3.11.0** atau yang lebih baru (misal: versi saat ini di project menggunakan `3.22.x` hingga `3.27.x` / `3.41.x`).
* [Panduan Instalasi Flutter](https://docs.flutter.dev/get-started/install)
* Setelah dipasang, jalankan perintah ini di terminal untuk memastikan tidak ada komponen yang kurang:
  ```bash
  flutter doctor
  ```

### 3. Java Development Kit (JDK)
Proyek ini dikonfigurasi menggunakan Gradle 8.14, sehingga membutuhkan **JDK 17**. Pastikan variabel lingkungan `JAVA_HOME` mengarah ke JDK 17.
* [Unduh JDK 17 (Eclipse Temurin / Oracle)](https://adoptium.net/temurin/releases/?version=17)

### 4. Android Studio & SDK
Digunakan untuk kompilasi aplikasi Android dan menyediakan emulator.
* [Unduh Android Studio](https://developer.android.com/studio)
* Di dalam Android Studio, pasang komponen tambahan ini melalui **SDK Manager**:
  * **Android SDK Platform** (API 34/35 direkomendasikan)
  * **Android SDK Command-line Tools (latest)** (Penting agar perintah CLI Flutter dapat berjalan)
  * **Android SDK Build-Tools**
  * **Android Emulator** (jika ingin mencoba di emulator komputer)

### 5. Editor Kode (IDE)
* **VS Code** (Direkomendasikan): Pasang ekstensi **Flutter** dan **Dart**.
* **Android Studio**: Pasang plugin **Flutter** dan **Dart** dari marketplace plugin.

---

## 🚀 Langkah-Langkah Menjalankan Proyek (Setup & Run)

Ikuti langkah-langkah di bawah ini setelah menarik (*pull/clone*) repositori Git ini ke komputer baru:

### Langkah 1: Buka Terminal di Folder Proyek
Buka VS Code atau terminal favorit Anda, lalu pastikan direktori kerja Anda berada di folder utama proyek `posmobile`.

### Langkah 2: Unduh Dependensi (Library)
Unduh seluruh pustaka yang digunakan dalam proyek ini dengan menjalankan:
```bash
flutter pub get
```

### Langkah 3: Regenerasi Kode Database (Drift ORM)
Aplikasi ini menggunakan Drift (SQLite) untuk pengelolaan database lokal. Berkas generator database harus dibangun terlebih dahulu agar kode model database terbentuk secara utuh. Jalankan perintah berikut:
```bash
dart run build_runner build --delete-conflicting-outputs
```
*Catatan: Pastikan langkah ini berhasil tanpa error agar berkas `app_database.g.dart` terbentuk.*

### Langkah 4: Hubungkan Perangkat (Device/Emulator)
* Hubungkan HP Android asli Anda dengan mengaktifkan opsi **Developer Options** dan **USB Debugging**.
* Atau, jalankan **Android Emulator** dari Android Studio / VS Code.
* Ketik perintah berikut untuk memastikan perangkat Anda terdeteksi oleh Flutter:
  ```bash
  flutter devices
  ```

### Langkah 5: Jalankan Aplikasi (Debug Mode)
Untuk menjalankan aplikasi dalam mode pengembangan, gunakan perintah:
```bash
flutter run
```

---

## 📦 Membangun File Rilis (Build Release APK)

Untuk menghasilkan file installer APK rilis yang siap dipasang langsung di HP Android (tanpa koneksi ke komputer):

Jalankan perintah berikut:
```bash
flutter build apk --release
```
Hasil file APK rilis dapat Anda temukan di direktori:
📁 `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔑 Informasi Akses Masuk Aplikasi (Default Auth)

Aplikasi menggunakan PIN yang di-hash dengan SHA-256 untuk keamanan.
* **Username Default**: `admin`
* **PIN Default**: `1234`

---

## 📝 Catatan Tambahan Pengembangan (Development Notes)
1. **Bahasa Komentar**: Seluruh dokumentasi kode dan komentar di dalam kode menggunakan **Bahasa Indonesia**.
2. **Arsitektur**: Menggunakan 2-layer per fitur (`data/` -> Drift DAO, dan `presentation/` -> Cubit + UI) dengan manajemen state menggunakan `flutter_bloc` (Cubit).
3. **Cetak Struk**: Menggunakan Bluetooth thermal printer dengan modul `blue_thermal_printer`. Pastikan bluetooth HP Anda aktif saat menguji fitur cetak struk kasir.
