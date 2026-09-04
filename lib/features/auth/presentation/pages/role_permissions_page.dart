import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/role_permissions_cubit.dart';

class RolePermissionsPage extends StatefulWidget {
  const RolePermissionsPage({super.key});

  @override
  State<RolePermissionsPage> createState() => _RolePermissionsPageState();
}

class _RolePermissionsPageState extends State<RolePermissionsPage> {
  String _selectedRole = 'cashier';

  final List<Map<String, dynamic>> _availableMenus = [
    {
      'key': 'pos',
      'title': 'POS Kasir',
      'icon': Icons.point_of_sale_rounded,
      'color': const Color(0xFF2563EB), // Blue
      'category': 'Transaksi & Kasir',
      'desc': 'Melakukan transaksi penjualan kasir, pembayaran, split bill, cetak struk.',
    },
    {
      'key': 'history',
      'title': 'Riwayat Transaksi',
      'icon': Icons.query_stats_rounded,
      'color': const Color(0xFF7C3AED), // Violet
      'category': 'Transaksi & Kasir',
      'desc': 'Melihat faktur penjualan terdahulu, cetak ulang struk, dan status pembayaran.',
    },
    {
      'key': 'products',
      'title': 'Master Produk & Katalog',
      'icon': Icons.inventory_2_rounded,
      'color': const Color(0xFF10B981), // Emerald
      'category': 'Inventori & Barang',
      'desc': 'Menambah/mengedit produk, harga bertingkat, satuan, dan barcode.',
    },
    {
      'key': 'restock',
      'title': 'Restok / Pembelian',
      'icon': Icons.local_shipping_rounded,
      'color': const Color(0xFF0D9488), // Teal
      'category': 'Inventori & Barang',
      'desc': 'Input faktur belanja masuk dari supplier dan penerimaan stok baru.',
    },
    {
      'key': 'opname',
      'title': 'Opname & Penyesuaian Stok',
      'icon': Icons.assessment_rounded,
      'color': const Color(0xFF0284C7), // Sky
      'category': 'Inventori & Barang',
      'desc': 'Pencocokan stok fisik rak toko vs database dan koreksi selisih.',
    },
    {
      'key': 'returns',
      'title': 'Retur Barang',
      'icon': Icons.assignment_return_rounded,
      'color': const Color(0xFFE11D48), // Rose
      'category': 'Inventori & Barang',
      'desc': 'Proses pengembalian barang dari pelanggan atau retur ke suplier.',
    },
    {
      'key': 'consignment',
      'title': 'Barang Konsinyasi',
      'icon': Icons.handshake_rounded,
      'color': const Color(0xFF16A34A), // Green
      'category': 'Inventori & Barang',
      'desc': 'Manajemen produk titipan pihak ketiga dan settlement bagi hasil.',
    },
    {
      'key': 'expenses',
      'title': 'Biaya Operasional',
      'icon': Icons.payments_rounded,
      'color': const Color(0xFFD97706), // Amber
      'category': 'Keuangan & Laporan',
      'desc': 'Pencatatan pengeluaran kas harian toko (listrik, gaji, bensin, dll).',
    },
    {
      'key': 'debts_receivables',
      'title': 'Hutang & Piutang',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFFEA580C), // Orange
      'category': 'Keuangan & Laporan',
      'desc': 'Pencatatan bon piutang pelanggan dan saldo hutang tempo ke pemasok.',
    },
    {
      'key': 'reports',
      'title': 'Laporan & Analitik',
      'icon': Icons.analytics_rounded,
      'color': const Color(0xFFDB2777), // Pink
      'category': 'Keuangan & Laporan',
      'desc': 'Akses ke dashboard eksekutif, laba rugi (P&L), dan ekspor laporan.',
    },
    {
      'key': 'contacts',
      'title': 'Kontak Pelanggan & Suplier',
      'icon': Icons.people_alt_rounded,
      'color': const Color(0xFF475569), // Slate
      'category': 'Pengaturan & Sistem',
      'desc': 'Kelola database data pelanggan, nomor telepon, dan data supplier.',
    },
    {
      'key': 'settings',
      'title': 'Pengaturan Sistem',
      'icon': Icons.settings_rounded,
      'color': const Color(0xFF334155),
      'category': 'Pengaturan & Sistem',
      'desc': 'Konfigurasi printer thermal bluetooth, profil toko, struk, dan backup DB.',
    },
    {
      'key': 'users',
      'title': 'Manajemen Akun Pengguna',
      'icon': Icons.admin_panel_settings_rounded,
      'color': const Color(0xFFDC2626), // Red
      'category': 'Pengaturan & Sistem',
      'desc': 'Tambah kasir, ganti PIN keamanan, dan atur izin buka menu.',
    },
  ];

  @override
  void initState() {
    super.initState();
    context.read<RolePermissionsCubit>().loadPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _selectedRole == 'admin';

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
              'Hak Akses Menu',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17, color: const Color(0xFF0F172A)),
            ),
            Text(
              'Otoritas & Batasan Menu per Peran',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP ROLE SELECTOR BANNER ──────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildRoleTabButton(
                        roleId: 'cashier',
                        title: 'Role Kasir',
                        subtitle: 'Operator Harian Toko',
                        icon: Icons.person_rounded,
                        isSelected: _selectedRole == 'cashier',
                        activeColor: const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 10),
                      _buildRoleTabButton(
                        roleId: 'admin',
                        title: 'Role Admin',
                        subtitle: 'Pemilik / Supervisor',
                        icon: Icons.security_rounded,
                        isSelected: _selectedRole == 'admin',
                        activeColor: const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAdmin ? const Color(0xFFBFDBFE) : const Color(0xFF99F6E4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAdmin ? Icons.shield_rounded : Icons.info_outline_rounded,
                          size: 16,
                          color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isAdmin
                                ? 'Admin selalu memiliki hak akses penuh ke menu Manajemen User & Pengaturan untuk mencegah terkunci.'
                                : 'Aktifkan menu yang diizinkan untuk dioperasikan oleh Kasir saat bertugas.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isAdmin ? const Color(0xFF1E40AF) : const Color(0xFF115E59),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // ── MENU PERMISSIONS LIST ─────────────────────────
            Expanded(
              child: BlocConsumer<RolePermissionsCubit, RolePermissionsState>(
                listener: (context, state) {
                  if (state is RolePermissionsError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is RolePermissionsLoading) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                  }

                  if (state is RolePermissionsLoaded) {
                    final permissions = state.permissions;
                    final rolePerm = permissions.firstWhere(
                      (p) => p.role == _selectedRole,
                      orElse: () => RolePermission(
                        id: 0,
                        role: _selectedRole,
                        allowedMenus: '[]',
                        updatedAt: DateTime.now(),
                      ),
                    );

                    List<String> allowedList = [];
                    try {
                      final decoded = jsonDecode(rolePerm.allowedMenus);
                      if (decoded is List) {
                        allowedList = decoded.map((e) => e.toString()).toList();
                      }
                    } catch (_) {}

                    // Group menus by category
                    final categories = ['Transaksi & Kasir', 'Inventori & Barang', 'Keuangan & Laporan', 'Pengaturan & Sistem'];

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: categories.length,
                      itemBuilder: (context, catIdx) {
                        final catName = categories[catIdx];
                        final catMenus = _availableMenus.where((m) => m['category'] == catName).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8, top: catIdx > 0 ? 12.0 : 0.0),
                              child: Text(
                                catName.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            ...catMenus.map((menu) {
                              final menuKey = menu['key'] as String;
                              final isAllowed = isAdmin || allowedList.contains(menuKey);
                              final isLocked = isAdmin && (menuKey == 'users' || menuKey == 'settings');
                              final Color iconColor = menu['color'] as Color;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isAllowed
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFFF1F5F9),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: isAllowed
                                              ? iconColor.withValues(alpha: 0.1)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            menu['icon'] as IconData,
                                            color: isAllowed ? iconColor : const Color(0xFF94A3B8),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    menu['title'] as String,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: isAllowed
                                                          ? const Color(0xFF0F172A)
                                                          : const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                ),
                                                if (isLocked)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Wajib Admin',
                                                      style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              menu['desc'] as String,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: isAllowed
                                                    ? const Color(0xFF64748B)
                                                    : const Color(0xFFCBD5E1),
                                                height: 1.25,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Switch.adaptive(
                                        value: isAllowed,
                                        activeTrackColor: (isAdmin
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF0D9488))
                                            .withValues(alpha: 0.5),
                                        activeThumbColor: isAdmin
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF0D9488),
                                        onChanged: isLocked
                                            ? null
                                            : (val) {
                                                final newList = List<String>.from(allowedList);
                                                if (val) {
                                                  if (!newList.contains(menuKey)) newList.add(menuKey);
                                                } else {
                                                  newList.remove(menuKey);
                                                }
                                                context.read<RolePermissionsCubit>().updatePermissions(_selectedRole, newList);
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTabButton({
    required String roleId,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRole = roleId),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

