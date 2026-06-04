import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/auth/data/auth_repository.dart';

void main() {
  late AppDatabase database;
  late AuthRepository authRepository;

  setUp(() {
    // Gunakan in-memory database SQLite untuk testing terisolasi
    database = AppDatabase(NativeDatabase.memory());
    authRepository = AuthRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Pengujian Autentikasi & Sesi Shift Kasir Standalone', () {
    test('Aplikasi mendeteksi database kosong (onboarding diperlukan)', () async {
      final isConfigured = await authRepository.hasOutlet();
      expect(isConfigured, isFalse);
    });

    test('Proses setup onboarding toko berhasil menyimpan data outlet dan admin', () async {
      final success = await authRepository.setupOnboarding(
        shopName: 'Toko Kopi Kenangan',
        shopAddress: 'Sudirman, Jakarta',
        shopPhone: '0812345678',
        adminName: 'Adam Adifa',
        adminUsername: 'adam',
        adminPin: '123456',
      );

      expect(success, isTrue);

      final hasOutlet = await authRepository.hasOutlet();
      expect(hasOutlet, isTrue);

      final users = await authRepository.getActiveUsers();
      expect(users.length, equals(1));
      expect(users.first.name, equals('Adam Adifa'));
      expect(users.first.username, equals('adam'));
      expect(users.first.role, equals('admin'));
    });

    test('Verifikasi login PIN benar dan salah', () async {
      // Setup onboarding terlebih dahulu
      await authRepository.setupOnboarding(
        shopName: 'Toko Test',
        shopAddress: 'Alamat Test',
        shopPhone: '021',
        adminName: 'Kasir Utama',
        adminUsername: 'kasir',
        adminPin: '8888',
      );

      // Skenario 1: Login dengan PIN salah (harus gagal/null)
      final failedUser = await authRepository.authenticate('kasir', '1111');
      expect(failedUser, isNull);

      // Skenario 2: Login dengan PIN benar (harus sukses dan mengembalikan User)
      final successUser = await authRepository.authenticate('kasir', '8888');
      expect(successUser, isNotNull);
      expect(successUser!.username, equals('kasir'));
    });

    test('Alur buka dan tutup shift kasir (Cashier Session)', () async {
      await authRepository.setupOnboarding(
        shopName: 'Toko Test Shift',
        shopAddress: 'Alamat Test',
        shopPhone: '021',
        adminName: 'Owner',
        adminUsername: 'admin',
        adminPin: '1234',
      );

      final user = (await authRepository.getActiveUsers()).first;

      // Pastikan belum ada sesi shift kasir yang aktif
      var activeSession = await authRepository.getActiveSession();
      expect(activeSession, isNull);

      // Buka shift baru dengan kas modal awal Rp 150.000
      final newSession = await authRepository.openSession(user.id, 150000.0);
      expect(newSession.status, equals('open'));
      expect(newSession.openingCash, equals(150000.0));

      // Verifikasi sesi kasir aktif sekarang terdeteksi
      activeSession = await authRepository.getActiveSession();
      expect(activeSession, isNotNull);
      expect(activeSession!.id, equals(newSession.id));

      // Estimasi kas teoritis (karena tidak ada transaksi, nilainya harus sama dengan modal awal)
      final expectedCash = await authRepository.getExpectedCash(activeSession.id);
      expect(expectedCash, equals(150000.0));

      // Tutup shift kasir dengan uang fisik aktual Rp 150.000 (selisih harus Rp 0)
      await authRepository.closeSession(
        sessionId: activeSession.id,
        closingCash: 150000.0,
        expectedCash: expectedCash,
        differenceAmount: 0.0,
      );

      // Verifikasi sesi aktif sudah tertutup
      activeSession = await authRepository.getActiveSession();
      expect(activeSession, isNull);
    });
  });
}
