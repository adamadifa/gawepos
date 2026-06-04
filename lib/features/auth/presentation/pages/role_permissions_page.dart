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
      'color': AppConstants.primaryColor,
      'desc': 'Melakukan transaksi penjualan langsung ke pembeli.'
    },
    {
      'key': 'products',
      'title': 'Produk (Master)',
      'icon': Icons.inventory_2_rounded,
      'color': AppConstants.successColor,
      'desc': 'Mengelola katalog produk, harga jual, dan brand/kategori.'
    },
    {
      'key': 'expenses',
      'title': 'Biaya (Pengeluaran)',
      'icon': Icons.payments_rounded,
      'color': AppConstants.warningColor,
      'desc': 'Mencatat pengeluaran operasional toko.'
    },
    {
      'key': 'restock',
      'title': 'Restok (Pembelian)',
      'icon': Icons.local_shipping_rounded,
      'color': Colors.teal,
      'desc': 'Melakukan pembelian barang dan stok baru dari supplier.'
    },
    {
      'key': 'opname',
      'title': 'Opname Stok',
      'icon': Icons.assessment_rounded,
      'color': AppConstants.primaryLightColor,
      'desc': 'Penyesuaian dan pencocokan jumlah stok fisik.'
    },
    {
      'key': 'history',
      'title': 'Riwayat Penjualan',
      'icon': Icons.query_stats_rounded,
      'color': const Color(0xFF7C3AED),
      'desc': 'Melihat riwayat transaksi penjualan yang telah selesai.'
    },
    {
      'key': 'reports',
      'title': 'Laporan & Analitik',
      'icon': Icons.analytics_rounded,
      'color': Colors.pink,
      'desc': 'Dashboard analitik keuangan, laba rugi, dan data PDF.'
    },
    {
      'key': 'contacts',
      'title': 'Kontak',
      'icon': Icons.people_alt_rounded,
      'color': Colors.blueGrey,
      'desc': 'Mengelola data pelanggan (customers) dan pemasok (suppliers).'
    },
    {
      'key': 'settings',
      'title': 'Pengaturan Toko',
      'icon': Icons.settings_rounded,
      'color': Colors.grey.shade700,
      'desc': 'Mengatur printer bluetooth, struk, backup data toko.'
    },
    {
      'key': 'users',
      'title': 'Manajemen User & Hak Akses',
      'icon': Icons.admin_panel_settings_rounded,
      'color': Colors.red.shade700,
      'desc': 'Mengatur kasir baru, mengganti PIN, dan membatasi menu.'
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
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Hak Akses Menu',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Selector Role ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    'Pilih Role:',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'cashier',
                          label: Text('Kasir'),
                          icon: Icon(Icons.person_rounded),
                        ),
                        ButtonSegment(
                          value: 'admin',
                          label: Text('Admin'),
                          icon: Icon(Icons.security_rounded),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedRole = newSelection.first;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppConstants.primaryColor,
                        selectedForegroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // ── Menu Switch List ──────────────────────────────
            Expanded(
              child: BlocConsumer<RolePermissionsCubit, RolePermissionsState>(
                listener: (context, state) {
                  if (state is RolePermissionsError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: AppConstants.errorColor,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  if (state is RolePermissionsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is RolePermissionsLoaded) {
                    // Temukan pemetaan hak akses untuk role yang dipilih
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
                      padding: const EdgeInsets.all(16),
                      itemCount: _availableMenus.length,
                      itemBuilder: (context, index) {
                        final menu = _availableMenus[index];
                        final menuKey = menu['key'] as String;
                        final isAllowed = allowedList.contains(menuKey);

                        // Admin tidak boleh kehilangan akses ke menu 'users' atau 'settings' untuk mencegah lockout
                        final isLocked = _selectedRole == 'admin' && (menuKey == 'users' || menuKey == 'settings');

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (menu['color'] as Color).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    menu['icon'] as IconData,
                                    color: menu['color'] as Color,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        menu['title'] as String,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppConstants.textDarkColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        menu['desc'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppConstants.textLightColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(
                                  value: isAllowed,
                                  activeColor: AppConstants.primaryColor,
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
