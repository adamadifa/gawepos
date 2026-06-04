import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:crypto/crypto.dart';
import '../../../core/database/app_database.dart';

class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  // Hash PIN 4-6 digit menggunakan SHA-256
  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── USER MANAGEMENT ───────────────────────────────────────────────
  Future<List<User>> getUsers() async {
    return await _db.select(_db.users).get();
  }

  Future<int> insertUser({
    required String name,
    required String username,
    required String pin,
    required String role,
    bool isActive = true,
  }) async {
    final companion = UsersCompanion.insert(
      name: name,
      username: username,
      pinHash: hashPin(pin),
      role: Value(role),
      isActive: Value(isActive),
    );
    return await _db.into(_db.users).insert(companion);
  }

  Future<bool> updateUser(User user, {String? newPin}) async {
    var companion = UsersCompanion(
      id: Value(user.id),
      name: Value(user.name),
      username: Value(user.username),
      role: Value(user.role),
      isActive: Value(user.isActive),
    );

    if (newPin != null && newPin.isNotEmpty) {
      companion = companion.copyWith(pinHash: Value(hashPin(newPin)));
    }

    return await _db.update(_db.users).replace(companion);
  }

  Future<int> deleteUser(int id) async {
    return await (_db.delete(_db.users)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ─── ROLE PERMISSIONS ──────────────────────────────────────────────
  Future<List<RolePermission>> getRolePermissions() async {
    return await _db.select(_db.rolePermissions).get();
  }

  Future<RolePermission?> getPermissionsForRole(String role) async {
    final query = _db.select(_db.rolePermissions)
      ..where((tbl) => tbl.role.equals(role));
    return await query.getSingleOrNull();
  }

  Future<void> updateRolePermissions(String role, List<String> allowedMenus) async {
    final query = _db.select(_db.rolePermissions)
      ..where((tbl) => tbl.role.equals(role));
    final existing = await query.getSingleOrNull();

    final allowedMenusJson = jsonEncode(allowedMenus);

    if (existing != null) {
      final companion = RolePermissionsCompanion(
        id: Value(existing.id),
        role: Value(role),
        allowedMenus: Value(allowedMenusJson),
        updatedAt: Value(DateTime.now()),
      );
      await _db.update(_db.rolePermissions).replace(companion);
    } else {
      final companion = RolePermissionsCompanion.insert(
        role: role,
        allowedMenus: allowedMenusJson,
      );
      await _db.into(_db.rolePermissions).insert(companion);
    }
  }
}
