import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class AuthRepository {
  final AppDatabase _db;

  AuthRepository(this._db);

  // Hash PIN 4-6 digit menggunakan SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Cek apakah data toko sudah disetup pertama kali
  Future<bool> hasOutlet() async {
    final outlets = await _db.select(_db.outlets).get();
    return outlets.isNotEmpty;
  }

  // Dapatkan semua user aktif untuk dipilih di layar login
  Future<List<User>> getActiveUsers() async {
    return await (_db.select(_db.users)
          ..where((tbl) => tbl.isActive.equals(true)))
        .get();
  }

  // Autentikasi user kasir lewat Username & PIN
  Future<User?> authenticate(String username, String pin) async {
    final hashed = _hashPin(pin);
    final query = _db.select(_db.users)
      ..where((tbl) => tbl.username.equals(username) & tbl.pinHash.equals(hashed) & tbl.isActive.equals(true));
    return await query.getSingleOrNull();
  }

  // Setup Onboarding Toko pertama kali
  Future<bool> setupOnboarding({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String adminName,
    required String adminUsername,
    required String adminPin,
  }) async {
    try {
      await _db.transaction(() async {
        // 1. Insert Toko/Outlet
        await _db.into(_db.outlets).insert(
              OutletsCompanion.insert(
                name: shopName,
                address: Value(shopAddress),
                phone: Value(shopPhone),
                taxPercentage: const Value(0.0),
              ),
            );

        // 2. Insert Admin User
        await _db.into(_db.users).insert(
              UsersCompanion.insert(
                name: adminName,
                username: adminUsername,
                pinHash: _hashPin(adminPin),
                role: const Value('admin'),
                isActive: const Value(true),
              ),
            );

        // Seed Default Role Permissions
        await _db.into(_db.rolePermissions).insert(
              RolePermissionsCompanion.insert(
                role: 'admin',
                allowedMenus: jsonEncode([
                  'pos',
                  'products',
                  'expenses',
                  'restock',
                  'opname',
                  'history',
                  'reports',
                  'contacts',
                  'settings',
                  'users'
                ]),
              ),
            );
        await _db.into(_db.rolePermissions).insert(
              RolePermissionsCompanion.insert(
                role: 'cashier',
                allowedMenus: jsonEncode([
                  'pos',
                  'history',
                  'contacts'
                ]),
              ),
            );

        // 3. Seed Default Price Tiers
        await _db.into(_db.priceTiers).insert(
              PriceTiersCompanion.insert(name: 'Harga Umum'),
            );
        await _db.into(_db.priceTiers).insert(
              PriceTiersCompanion.insert(name: 'Harga Grosir'),
            );

        // 4. Seed Default Settings
        final defaultSettings = {
          'shop_name': shopName,
          'shop_phone': shopPhone,
          'shop_address': shopAddress,
          'tax_percentage': '0',
          'printer_address': '',
          'printer_name': '',
          'receipt_header': 'TERIMA KASIH TELAH BERBELANJA',
          'receipt_footer': 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan.',
        };

        for (var entry in defaultSettings.entries) {
          await _db.into(_db.settings).insert(
                SettingsCompanion.insert(
                  key: entry.key,
                  value: Value(entry.value),
                ),
              );
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Ambil menu yang diizinkan untuk role tertentu
  Future<List<String>> getAllowedMenus(String role) async {
    final query = _db.select(_db.rolePermissions)
      ..where((tbl) => tbl.role.equals(role));
    final record = await query.getSingleOrNull();
    if (record == null) return [];
    try {
      final decoded = jsonDecode(record.allowedMenus);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  // Ambil sesi kasir yang sedang aktif (belum ditutup)
  Future<CashierSession?> getActiveSession() async {
    final query = _db.select(_db.cashierSessions)
      ..where((tbl) => tbl.status.equals('open'));
    return await query.getSingleOrNull();
  }

  // Buka sesi kasir baru (Shift Open)
  Future<CashierSession> openSession(int userId, double openingCash) async {
    final companion = CashierSessionsCompanion.insert(
      userId: userId,
      openTime: DateTime.now(),
      openingCash: openingCash,
      status: const Value('open'),
    );
    final id = await _db.into(_db.cashierSessions).insert(companion);
    return await (_db.select(_db.cashierSessions)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  // Tutup sesi kasir (Shift Close)
  Future<void> closeSession({
    required int sessionId,
    required double closingCash,
    required double expectedCash,
    required double differenceAmount,
  }) async {
    final updateQuery = _db.update(_db.cashierSessions)
      ..where((tbl) => tbl.id.equals(sessionId));
    
    await updateQuery.write(
      CashierSessionsCompanion(
        closeTime: Value(DateTime.now()),
        closingCash: Value(closingCash),
        expectedCash: Value(expectedCash),
        differenceAmount: Value(differenceAmount),
        status: const Value('closed'),
      ),
    );
  }

  // Hitung ekspektasi uang kas di laci kasir saat ini
  // expectedCash = openingCash + total Cash Payments - total Expenses
  Future<double> getExpectedCash(int sessionId) async {
    // 1. Ambil modal awal sesi
    final session = await (_db.select(_db.cashierSessions)
          ..where((tbl) => tbl.id.equals(sessionId)))
        .getSingle();
    final modalAwal = session.openingCash;

    // 2. Ambil total pembayaran penjualan tunai (cash) pada sesi ini
    final ordersInSession = await (_db.select(_db.orders)
          ..where((tbl) => tbl.cashierSessionId.equals(sessionId) & tbl.status.equals('completed')))
        .get();

    double totalCashSales = 0;
    if (ordersInSession.isNotEmpty) {
      final orderIds = ordersInSession.map((o) => o.id).toList();
      final payments = await (_db.select(_db.orderPayments)
            ..where((tbl) => tbl.orderId.isIn(orderIds) & tbl.paymentMethod.equals('cash')))
          .get();
      totalCashSales = payments.fold(0.0, (sum, item) => sum + item.amount);
    }

    // 3. Ambil total pengeluaran (expenses) selama sesi ini berlangsung (sejak openTime)
    final expenses = await (_db.select(_db.expenses)
          ..where((tbl) => tbl.date.isBiggerOrEqualValue(session.openTime)))
        .get();
    final totalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

    return modalAwal + totalCashSales - totalExpenses;
  }
}
