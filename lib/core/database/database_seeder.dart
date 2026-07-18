import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  // Hash PIN "1234" menggunakan SHA-256
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<void> seed(AppDatabase db) async {
    await db.transaction(() async {
      // 1. Seed Default Outlet
      await db.into(db.outlets).insert(
        OutletsCompanion.insert(
          name: 'Toko Kasir Utama',
          phone: const Value('08123456789'),
          address: const Value('Jl. Utama No. 1, Kota'),
          taxPercentage: const Value(0.0),
        ),
      );

      // 2. Seed Default User (Administrator)
      // Default PIN: 1234
      await db.into(db.users).insert(
        UsersCompanion.insert(
          name: 'Owner / Admin',
          username: 'admin',
          pinHash: hashPin('1234'),
          role: const Value('admin'),
          isActive: const Value(true),
        ),
      );

      // Seed Default Role Permissions
      await db.into(db.rolePermissions).insert(
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
      await db.into(db.rolePermissions).insert(
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
      await db.into(db.priceTiers).insert(
        PriceTiersCompanion.insert(name: 'Harga Umum'),
      );
      await db.into(db.priceTiers).insert(
        PriceTiersCompanion.insert(name: 'Harga Grosir'),
      );

      // 4. Seed Default Settings (batch)
      final defaultSettings = {
        'shop_name': 'Toko Kasir Utama',
        'shop_phone': '08123456789',
        'shop_address': 'Jl. Utama No. 1, Kota',
        'tax_percentage': '0',
        'printer_address': '',
        'printer_name': '',
        'receipt_header': 'TERIMA KASIH TELAH BERBELANJA',
        'receipt_footer': 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan.',
      };
      await db.batch((batch) {
        for (var entry in defaultSettings.entries) {
          batch.insert(db.settings, SettingsCompanion.insert(
            key: entry.key,
            value: Value(entry.value),
          ));
        }
      });
    });
  }
}
