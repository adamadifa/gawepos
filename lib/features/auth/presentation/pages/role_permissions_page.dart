import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
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
      'color': const Color(0xFF1A56DB),
      'desc': 'Melakukan transaksi penjualan kasir langsung ke pembeli.'
    },
    {
      'key': 'products',
      'title': 'Produk (Master)',
      'icon': Icons.inventory_2_rounded,
      'color': const Color(0xFF059669),
      'desc': 'Mengelola katalog produk, barcode, dan kategori/merk.'
    },
    {
      'key': 'expenses',
      'title': 'Biaya Operasional',
      'icon': Icons.payments_rounded,
      'color': const Color(0xFFD97706),
      'desc': 'Mencatat pengeluaran harian dan operasional toko.'
    },
    {
      'key': 'restock',
      'title': 'Restok (Pembelian)',
      'icon': Icons.local_shipping_rounded,
      'color': const Color(0xFF0D9488),
      'desc': 'Melakukan pesanan pembelian barang ke supplier.'
    },
    {
      'key': 'opname',
      'title': 'Opname Stok',
      'icon': Icons.fact_check_rounded,
      'color': const Color(0xFF0284C7),
      'desc': 'Penyesuaian stok dan pencocokan kuantitas fisik.'
    },
    {
      'key': 'history',
      'title': 'Riwayat Penjualan',
      'icon': Icons.query_stats_rounded,
      'color': const Color(0xFF7C3AED),
      'desc': 'Melihat riwayat transaksi nota penjualan yang selesai.'
    },
    {
      'key': 'reports',
      'title': 'Laporan & Analitik',
      'icon': Icons.analytics_rounded,
      'color': const Color(0xFFE11D48),
      'desc': 'Dashboard analitik keuangan, laba rugi, dan ekspor PDF.'
    },
    {
      'key': 'contacts',
      'title': 'Pelanggan & Pemasok',
      'icon': Icons.people_alt_rounded,
      'color': const Color(0xFF475569),
      'desc': 'Mengelola data kontak pelanggan dan daftar pemasok.'
    },
    {
      'key': 'settings',
      'title': 'Pengaturan Toko',
      'icon': Icons.settings_rounded,
      'color': const Color(0xFF334155),
      'desc': 'Mengatur printer bluetooth, struk, dan cadangan database.'
    },
    {
      'key': 'users',
      'title': 'Manajemen User & Role',
      'icon': Icons.admin_panel_settings_rounded,
      'color': const Color(0xFFDC2626),
      'desc': 'Mengatur akun kasir baru, PIN, dan hak akses menu.'
    },
  ];

  @override
  void initState() {
    super.initState();
    context.read<RolePermissionsCubit>().loadPermissions();
  }

  @override
  Widget build(BuildContext context) {
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
              'Hak Akses Menu',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Batasi menu yang boleh dibuka oleh Kasir & Admin',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Role Selector Pill
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedRole = 'cashier'),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'cashier' ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedRole == 'cashier'
                                ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: _selectedRole == 'cashier' ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Role Kasir',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: _selectedRole == 'cashier' ? FontWeight.w700 : FontWeight.w500,
                                  color: _selectedRole == 'cashier' ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedRole = 'admin'),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'admin' ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedRole == 'admin'
                                ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security_rounded,
                                size: 16,
                                color: _selectedRole == 'admin' ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Role Admin',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: _selectedRole == 'admin' ? FontWeight.w700 : FontWeight.w500,
                                  color: _selectedRole == 'admin' ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Menu Switch List
            Expanded(
              child: BlocConsumer<RolePermissionsCubit, RolePermissionsState>(
                listener: (context, state) {
                  if (state is RolePermissionsError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message, style: GoogleFonts.poppins()),
                        backgroundColor: AppConstants.errorColor,
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

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: _availableMenus.length,
                      itemBuilder: (context, index) {
                        final menu = _availableMenus[index];
                        final menuKey = menu['key'] as String;
                        final isAllowed = allowedList.contains(menuKey);
                        final isLocked = _selectedRole == 'admin' && (menuKey == 'users' || menuKey == 'settings');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (menu['color'] as Color).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    menu['icon'] as IconData,
                                    color: menu['color'] as Color,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            menu['title'] as String,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (isLocked) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Wajib Admin',
                                                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        menu['desc'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: isAllowed,
                                  activeThumbColor: const Color(0xFF0F172A),
                                  onChanged: isLocked
                                      ? null
                                      : (val) {
                                          final newList = List<String>.from(allowedList);
                                          if (val) {
                                            newList.add(menuKey);
                                          } else {
                                            newList.remove(menuKey);
                                          }
                                          context
                                              .read<RolePermissionsCubit>()
                                              .updatePermissions(_selectedRole, newList);
                                        },
                                ),
                              ],
                            ),
                          ),
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
}
