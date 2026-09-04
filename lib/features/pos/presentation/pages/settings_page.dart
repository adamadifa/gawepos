import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/print_service.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/pages/user_management_page.dart';
import '../../../auth/presentation/pages/role_permissions_page.dart';
import '../../data/sales_repository.dart';
import 'database_management_page.dart';
import 'points_settings_page.dart';
import 'printer_settings_page.dart';
import 'shop_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _shopName = 'GawePOS';
  String? _printerName;
  bool _isPrinterConnected = false;
  bool _isPointsActive = false;
  String _dbSize = '0 KB';

  @override
  void initState() {
    super.initState();
    _loadSystemOverview();
  }

  Future<void> _loadSystemOverview() async {
    try {
      final salesRepo = getIt<SalesRepository>();
      final name = await salesRepo.getSetting('shop_name');
      final printer = await salesRepo.getSetting('printer_name');
      final pointsEnabled = await salesRepo.getSetting('points_enabled');

      final printService = getIt<PrintService>();
      final isConn = await printService.isConnected();

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'posmobile.db'));
      String sizeStr = '0 KB';
      if (await dbFile.exists()) {
        final bytes = await dbFile.length();
        if (bytes >= 1024 * 1024) {
          sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        } else {
          sizeStr = '${(bytes / 1024).toStringAsFixed(0)} KB';
        }
      }

      if (mounted) {
        setState(() {
          if (name != null && name.trim().isNotEmpty) _shopName = name.trim();
          _printerName = printer;
          _isPrinterConnected = isConn;
          _isPointsActive = pointsEnabled == '1';
          _dbSize = sizeStr;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final currentUser = authCubit.currentUser;
    final canManageUsers = authCubit.isMenuAllowed('users');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengaturan Sistem',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Konfigurasi Toko, Akun & Perangkat Kasir',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: currentUser.role == 'admin'
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: currentUser.role == 'admin'
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        currentUser.role == 'admin'
                            ? Icons.admin_panel_settings_rounded
                            : Icons.badge_outlined,
                        size: 14,
                        color: currentUser.role == 'admin'
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        currentUser.role.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: currentUser.role == 'admin'
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF334155),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F172A),
        onRefresh: () async {
          await _loadSystemOverview();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── TOP OVERVIEW BANNER CARD ────────────────────────
            _buildSystemOverviewBanner(),
            const SizedBox(height: 20),

            // ── SECTION 1: KEAMANAN & PENGGUNA ───────────────────
            if (canManageUsers) ...[
              _buildSectionHeader(
                title: 'Pengguna & Otoritas',
                subtitle: 'Kelola akun kasir, admin, dan batasan akses menu',
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 10),
              _buildSettingsCard(
                icon: Icons.people_outline_rounded,
                iconColor: const Color(0xFF0D9488), // Teal
                bgColor: const Color(0xFFF0FDFA),
                title: 'Manajemen Pengguna',
                subtitle: 'Tambah kasir, ganti PIN, ubah status & data operator',
                badgeText: 'Akun Kasir',
                badgeColor: const Color(0xFFCCFBF1),
                badgeTextColor: const Color(0xFF0F766E),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserManagementPage()),
                  );
                  _loadSystemOverview();
                },
              ),
              const SizedBox(height: 10),
              _buildSettingsCard(
                icon: Icons.lock_person_outlined,
                iconColor: const Color(0xFF7C3AED), // Violet
                bgColor: const Color(0xFFF5F3FF),
                title: 'Hak Akses Menu & Peran',
                subtitle: 'Atur izin buka menu operasional untuk role kasir/admin',
                badgeText: 'Keamanan',
                badgeColor: const Color(0xFFEDE9FE),
                badgeTextColor: const Color(0xFF6D28D9),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RolePermissionsPage()),
                  );
                  _loadSystemOverview();
                },
              ),
              const SizedBox(height: 24),
            ],

            // ── SECTION 2: OPERASIONAL & PERANGKAT ───────────────
            _buildSectionHeader(
              title: 'Operasional & Perangkat',
              subtitle: 'Pengaturan cetak struk, profil usaha, dan loyalitas pelanggan',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 10),
            _buildSettingsCard(
              icon: Icons.store_mall_directory_outlined,
              iconColor: const Color(0xFF2563EB), // Blue
              bgColor: const Color(0xFFEFF6FF),
              title: 'Profil & Format Struk Toko',
              subtitle: 'Nama gerai, alamat, logo toko, teks header & footer bon belanja',
              badgeText: _shopName,
              badgeColor: const Color(0xFFDBEAFE),
              badgeTextColor: const Color(0xFF1D4ED8),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ShopSettingsPage()),
                );
                _loadSystemOverview();
              },
            ),
            const SizedBox(height: 10),
            _buildSettingsCard(
              icon: Icons.print_outlined,
              iconColor: const Color(0xFF0284C7), // Sky
              bgColor: const Color(0xFFF0F9FF),
              title: 'Printer Thermal Bluetooth',
              subtitle: _printerName != null && _printerName!.isNotEmpty
                  ? 'Terhubung ke: $_printerName'
                  : 'Pilih & sambungkan perangkat printer kasir (58mm/80mm)',
              badgeText: _isPrinterConnected ? 'Tersambung' : (_printerName != null ? 'Tersimpan' : 'Belum Ada'),
              badgeColor: _isPrinterConnected
                  ? const Color(0xFFDCFCE7)
                  : (_printerName != null ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9)),
              badgeTextColor: _isPrinterConnected
                  ? const Color(0xFF15803D)
                  : (_printerName != null ? const Color(0xFF0369A1) : const Color(0xFF64748B)),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrinterSettingsPage()),
                );
                _loadSystemOverview();
              },
            ),
            const SizedBox(height: 10),
            _buildSettingsCard(
              icon: Icons.card_giftcard_rounded,
              iconColor: const Color(0xFFD97706), // Amber
              bgColor: const Color(0xFFFFFBEB),
              title: 'Poin Loyalitas Pelanggan',
              subtitle: 'Atur rasio perolehan poin dan konversi diskon belanja',
              badgeText: _isPointsActive ? 'Aktif' : 'Nonaktif',
              badgeColor: _isPointsActive ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
              badgeTextColor: _isPointsActive ? const Color(0xFFB45309) : const Color(0xFF64748B),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PointsSettingsPage()),
                );
                _loadSystemOverview();
              },
            ),
            const SizedBox(height: 24),

            // ── SECTION 3: DATABASE & PEMELIHARAAN ───────────────
            _buildSectionHeader(
              title: 'Penyimpanan & Database',
              subtitle: 'Pencadangan database SQLite lokal dan pemulihan data',
              icon: Icons.storage_outlined,
            ),
            const SizedBox(height: 10),
            _buildSettingsCard(
              icon: Icons.cloud_sync_outlined,
              iconColor: const Color(0xFF4F46E5), // Indigo
              bgColor: const Color(0xFFEEF2FF),
              title: 'Backup & Restore Database',
              subtitle: 'Ekspor file zip database SQLite atau pulihkan dari cadangan luar',
              badgeText: 'Ukuran DB: $_dbSize',
              badgeColor: const Color(0xFFE0E7FF),
              badgeTextColor: const Color(0xFF4338CA),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DatabaseManagementPage()),
                );
                _loadSystemOverview();
              },
            ),
            if (canManageUsers) ...[
              const SizedBox(height: 10),
              _buildDestructiveResetCard(),
            ],
            const SizedBox(height: 28),

            // ── APP FOOTER INFO ──────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'GawePOS Enterprise v1.2.0 • Offline First',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistem Kasir & Manajemen Bisnis UMKM Indonesia',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── WIDGET: TOP SYSTEM OVERVIEW BANNER ────────────────────────
  Widget _buildSystemOverviewBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Deep Slate
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings_suggest_rounded,
                  color: Color(0xFF38BDF8), // Light Sky
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shopName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981), // Emerald online
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sistem Siap Operasional',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildOverviewMiniStat(
                label: 'Printer Thermal',
                value: _printerName ?? 'Belum Diatur',
                icon: Icons.print_rounded,
                iconColor: _isPrinterConnected ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
              ),
              Container(
                height: 28,
                width: 1,
                color: Colors.white.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              _buildOverviewMiniStat(
                label: 'Poin Belanja',
                value: _isPointsActive ? 'Aktif' : 'Nonaktif',
                icon: Icons.loyalty_rounded,
                iconColor: _isPointsActive ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
              ),
              Container(
                height: 28,
                width: 1,
                color: Colors.white.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              _buildOverviewMiniStat(
                label: 'Ukuran DB',
                value: _dbSize,
                icon: Icons.folder_zip_rounded,
                iconColor: const Color(0xFF818CF8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── WIDGET: SECTION HEADER ──────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── WIDGET: SETTINGS INTERACTIVE CARD ────────────────────────
  Widget _buildSettingsCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.18)),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: badgeTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── WIDGET: RESET DATA DESTRUCTIVE CARD ──────────────────────
  Widget _buildDestructiveResetCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _showResetConfirmationDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Reset Database & Data Aplikasi',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Zona Bahaya',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hapus permanen semua produk, transaksi, biaya & file gambar',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFB91C1C),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFF87171),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── DIALOG: KONFIRMASI RESET DATA DENGAN VERIFIKASI KATA ─────
  void _showResetConfirmationDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reset Seluruh Data?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tindakan ini akan menghapus seluruh database transaksi, produk, akun kasir, data biaya, dan semua foto produk secara permanen dari perangkat ini.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                'Ketik kata "RESET" (huruf kapital) di bawah untuk konfirmasi:',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'RESET',
                hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim() == 'RESET') {
                Navigator.pop(ctx);
                _performReset(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Kata konfirmasi salah. Reset dibatalkan.',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'RESET SEKARANG',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── LOGIKA RESET DATA APLIKASI ──────────────────────────────
  Future<void> _performReset(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFDC2626)),
              const SizedBox(height: 16),
              Text(
                'Sedang mereset database...',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Reset Berhasil',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Text(
              'Seluruh data berhasil dibersihkan. Aplikasi akan ditutup untuk menerapkan perubahan. Silakan buka kembali aplikasi setelah keluar.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569), height: 1.4),
            ),
            actions: [
              FilledButton(
                onPressed: () => exit(0),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('KELUAR APLIKASI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
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
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

