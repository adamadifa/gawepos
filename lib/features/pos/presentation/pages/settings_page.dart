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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengaturan Aplikasi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Konfigurasi toko, kasir, printer, dan sistem',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ─── GRUP 1: PENGGUNA & HAK AKSES ────────────────────────────────
          if (canManageUsers) ...[
            _buildSectionHeader('Akun & Keamanan'),
            const SizedBox(height: 8),
            _buildMenuCard(
              context: context,
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF0D9488), // Teal
              bgColor: const Color(0xFFF0FDFA),
              title: 'Manajemen User',
              subtitle: 'Kelola data kasir, tambah admin baru, ubah status aktif & ganti PIN.',
              destination: const UserManagementPage(),
            ),
            const SizedBox(height: 10),
            _buildMenuCard(
              context: context,
              icon: Icons.admin_panel_settings_rounded,
              iconColor: const Color(0xFF7C3AED), // Violet
              bgColor: const Color(0xFFF5F3FF),
              title: 'Hak Akses Menu (Role)',
              subtitle: 'Atur izin akses menu yang boleh dibuka oleh Kasir vs Admin.',
              destination: const RolePermissionsPage(),
            ),
            const SizedBox(height: 20),
          ],

          // ─── GRUP 2: TOKO & STRUK ─────────────────────────────────────────
          _buildSectionHeader('Toko & Pelanggan'),
          const SizedBox(height: 8),
          _buildMenuCard(
            context: context,
            icon: Icons.storefront_rounded,
            iconColor: const Color(0xFF1A56DB), // Blue
            bgColor: const Color(0xFFEFF6FF),
            title: 'Profil & Header Struk Toko',
            subtitle: 'Nama, telepon, alamat toko, logo, serta teks header & footer struk.',
            destination: const ShopSettingsPage(),
          ),
          const SizedBox(height: 10),
          _buildMenuCard(
            context: context,
            icon: Icons.card_giftcard_rounded,
            iconColor: const Color(0xFFD97706), // Amber
            bgColor: const Color(0xFFFFFBEB),
            title: 'Poin Loyalitas Pelanggan',
            subtitle: 'Aktifkan program perolehan poin dan atur nilai tukar rupiah.',
            destination: const PointsSettingsPage(),
          ),
          const SizedBox(height: 20),

          // ─── GRUP 3: PERANGKAT & HARDWARE ─────────────────────────────────
          _buildSectionHeader('Perangkat & Cetak'),
          const SizedBox(height: 8),
          _buildMenuCard(
            context: context,
            icon: Icons.print_rounded,
            iconColor: const Color(0xFF0284C7), // Sky
            bgColor: const Color(0xFFF0F9FF),
            title: 'Printer Thermal Bluetooth',
            subtitle: 'Pindai printer kasir, hubungkan Bluetooth, dan tes cetak struk.',
            destination: const PrinterSettingsPage(),
          ),
          const SizedBox(height: 20),

          // ─── GRUP 4: DATA & DATABASE ──────────────────────────────────────
          _buildSectionHeader('Data & Pemeliharaan'),
          const SizedBox(height: 8),
          _buildMenuCard(
            context: context,
            icon: Icons.storage_rounded,
            iconColor: const Color(0xFF4F46E5), // Indigo
            bgColor: const Color(0xFFEEF2FF),
            title: 'Backup & Restore Database',
            subtitle: 'Cadangkan database SQLite lokal atau pulihkan dari file luar (ZIP).',
            destination: const DatabaseManagementPage(),
          ),
          if (canManageUsers) ...[
            const SizedBox(height: 10),
            _buildResetDataCard(context),
          ],

          const SizedBox(height: 24),
          // App Version Branding Footer
          Center(
            child: Column(
              children: [
                Text(
                  '${AppConstants.appName} v1.0.0',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aplikasi Kasir Offline-First untuk UMKM Indonesia',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reset Data Aplikasi?',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Text(
                'Tindakan ini akan menghapus seluruh transaksi, produk, kasir, log biaya, dan gambar secara permanen dari perangkat ini.',
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF991B1B)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Ketik kata "RESET" (huruf kapital) untuk konfirmasi:',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: 'RESET',
                hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (controller.text.trim() == 'RESET') {
                  Navigator.pop(ctx);
                  _performReset(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kata konfirmasi salah. Reset dibatalkan.', style: GoogleFonts.poppins()),
                      backgroundColor: AppConstants.errorColor,
                    ),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: Text(
                'RESET DATA SEKARANG',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performReset(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0F172A)),
              const SizedBox(height: 16),
              Text(
                'Sedang mereset data...',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Reset Berhasil',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
            ),
            content: Text(
              'Seluruh data berhasil dihapus. Silakan tutup dan buka kembali aplikasi untuk memulai dari awal.',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => exit(0),
                child: Text('KELUAR APLIKASI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
            content: Text('Gagal mereset data: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildResetDataCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showResetConfirmationDialog(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Data Aplikasi',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hapus permanen database lokal & reset aplikasi.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
