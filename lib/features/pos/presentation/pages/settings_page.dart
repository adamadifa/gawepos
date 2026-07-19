import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/pages/user_management_page.dart';
import '../../../auth/presentation/pages/role_permissions_page.dart';
import 'database_management_page.dart';
import 'points_settings_page.dart';
import 'printer_settings_page.dart';
import 'shop_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final canManageUsers = authCubit.isMenuAllowed('users');

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Pengaturan Aplikasi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canManageUsers) ...[
            _buildMenuCard(
              context: context,
              icon: Icons.people_outline_rounded,
              iconColor: Colors.teal.shade600,
              bgColor: Colors.teal.shade50,
              title: 'Manajemen User',
              subtitle: 'Tambah kasir baru, ubah nama, ganti PIN, atau ubah status aktif.',
              destination: const UserManagementPage(),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context: context,
              icon: Icons.security_rounded,
              iconColor: Colors.red.shade600,
              bgColor: Colors.red.shade50,
              title: 'Hak Akses Menu',
              subtitle: 'Batasi menu apa saja yang boleh dibuka oleh Kasir atau Admin.',
              destination: const RolePermissionsPage(),
            ),
            const SizedBox(height: 12),
          ],
          _buildMenuCard(
            context: context,
            icon: Icons.store_rounded,
            iconColor: Colors.blue.shade600,
            bgColor: Colors.blue.shade50,
            title: 'Profil & Struk Toko',
            subtitle: 'Nama, telepon, alamat toko, header & footer cetakan struk.',
            destination: const ShopSettingsPage(),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context: context,
            icon: Icons.print_rounded,
            iconColor: Colors.purple.shade600,
            bgColor: Colors.purple.shade50,
            title: 'Printer Bluetooth',
            subtitle: 'Hubungkan printer thermal kasir dan lakukan uji test print.',
            destination: const PrinterSettingsPage(),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context: context,
            icon: Icons.card_giftcard_rounded,
            iconColor: Colors.orange.shade600,
            bgColor: Colors.orange.shade50,
            title: 'Poin Pelanggan',
            subtitle: 'Aktifkan/nonaktifkan poin, atur nilai tukar & penukaran poin.',
            destination: const PointsSettingsPage(),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context: context,
            icon: Icons.storage_rounded,
            iconColor: Colors.indigo.shade600,
            bgColor: Colors.indigo.shade50,
            title: 'Backup & Restore Data',
            subtitle: 'Cadangkan data database lokal atau pulihkan dari file luar.',
            destination: const DatabaseManagementPage(),
          ),
          if (canManageUsers) ...[
            const SizedBox(height: 12),
            _buildResetDataCard(context),
          ],
        ],
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Reset Data Aplikasi?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppConstants.errorColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tindakan ini akan menghapus seluruh data transaksi, produk, kasir, biaya, dan semua gambar secara permanen dari perangkat ini.\n\nKetik kata "RESET" (huruf kapital) untuk melanjutkan:',
              style: TextStyle(fontSize: 13, color: AppConstants.textDarkColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'RESET',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim() == 'RESET') {
                Navigator.pop(ctx);
                _performReset(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kata konfirmasi salah. Reset dibatalkan.'),
                    backgroundColor: AppConstants.errorColor,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: const Text('RESET SEKARANG'),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sedang mereset data...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Close database
      final db = getIt<AppDatabase>();
      await db.close();

      // 2. Delete database files
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFiles = [
        'posmobile.db',
        'posmobile.db-journal',
        'posmobile.db-wal',
        'posmobile.db-shm',
      ];
      for (final fName in dbFiles) {
        final file = File(p.join(dbFolder.path, fName));
        if (await file.exists()) {
          await file.delete();
        }
      }

      // 3. Delete product images & logos
      final assetFolders = ['products', 'images', 'logos'];
      for (final folderName in assetFolders) {
        final dir = Directory(p.join(dbFolder.path, folderName));
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }

      // 4. Show success & exit
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Reset Berhasil',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppConstants.successColor),
            ),
            content: const Text(
              'Seluruh data berhasil dihapus. Aplikasi harus ditutup untuk menerapkan perubahan ini. Silakan buka kembali aplikasi setelah keluar.',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => exit(0),
                child: const Text('KELUAR APLIKASI'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mereset data: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildResetDataCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: InkWell(
        onTap: () => _showResetConfirmationDialog(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever_rounded, color: AppConstants.errorColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Data Aplikasi',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.errorColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hapus permanen semua produk, transaksi, biaya, dan database lokal.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
