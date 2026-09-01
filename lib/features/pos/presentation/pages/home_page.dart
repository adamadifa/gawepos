import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../master/presentation/pages/master_menu_page.dart';
import 'pos_page.dart';
import 'settings_page.dart';
import 'sales_history_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../purchases/presentation/pages/purchases_list_page.dart';
import '../../../inventory/presentation/pages/stock_opname_page.dart';
import '../../../inventory/presentation/pages/debts_receivables_page.dart';
import '../../../reports/presentation/pages/reports_menu_page.dart';
import '../../../reports/presentation/pages/owner_dashboard_page.dart';
import '../../../master/presentation/pages/contacts_page.dart';
import '../../../inventory/presentation/pages/returns_menu_page.dart';

class HomePage extends StatefulWidget {
  final User user;
  final CashierSession? session;
  const HomePage({super.key, required this.user, this.session});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _closingCashController = TextEditingController();
  late Timer _clockTimer;
  String _currentTime = "";
  String _currentDate = "";
  bool _showShiftDetails = false;

  @override
  void initState() {
    super.initState();
    _currentTime = _formatTime(DateTime.now());
    _currentDate = _formatDate(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = _formatTime(DateTime.now());
          _currentDate = _formatDate(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _closingCashController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  String _formatDate(DateTime dt) {
    return DateFormat('EEEE, dd MMM yyyy', 'id').format(dt);
  }

  void _showCloseShiftDialog(BuildContext context, double expectedCash) {
    _closingCashController.text = expectedCash.toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Akhiri Shift Kasir',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kas Teoretis di Sistem',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(expectedCash),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D4ED8),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hitung fisik uang tunai di laci kasir dan masukkan nominal aslinya:',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.3),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _closingCashController,
              decoration: InputDecoration(
                labelText: 'Jumlah Fisik Uang Tunai',
                prefixText: 'Rp ',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final actual = double.tryParse(_closingCashController.text) ?? 0.0;
              Navigator.pop(ctx);
              context.read<AuthCubit>().closeShift(actual);
            },
            child: Text('Tutup Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();

    final List<Map<String, dynamic>> menus = [
      {
        'key': 'pos',
        'icon': Icons.point_of_sale_rounded,
        'title': 'POS Kasir',
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFEFF6FF),
        'onTap': () {
          if (widget.session == null) {
            _showOpenShiftRequiredDialog(context);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PosPage()),
            );
          }
        },
      },
      {
        'key': 'owner_dashboard',
        'icon': Icons.space_dashboard_rounded,
        'title': 'Dashboard',
        'color': const Color(0xFF4F46E5), // Indigo
        'bg': const Color(0xFFEEF2FF),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OwnerDashboardPage()),
            ),
      },
      {
        'key': 'products',
        'icon': Icons.inventory_2_rounded,
        'title': 'Produk',
        'color': const Color(0xFF059669), // Emerald
        'bg': const Color(0xFFECFDF5),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MasterMenuPage()),
            ),
      },
      {
        'key': 'reports',
        'icon': Icons.analytics_rounded,
        'title': 'Laporan',
        'color': const Color(0xFFDB2777), // Pink
        'bg': const Color(0xFFFDF2F8),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportsMenuPage()),
            ),
      },
      {
        'key': 'expenses',
        'icon': Icons.payments_rounded,
        'title': 'Biaya',
        'color': const Color(0xFFD97706), // Amber
        'bg': const Color(0xFFFFFBEB),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExpensesPage()),
            ),
      },
      {
        'key': 'restock',
        'icon': Icons.local_shipping_rounded,
        'title': 'Restok',
        'color': const Color(0xFF0D9488), // Teal
        'bg': const Color(0xFFF0FDFA),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PurchasesListPage()),
            ),
      },
      {
        'key': 'opname',
        'icon': Icons.assessment_rounded,
        'title': 'Opname',
        'color': const Color(0xFF0284C7), // Sky
        'bg': const Color(0xFFF0F9FF),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StockOpnamePage()),
            ),
      },
      {
        'key': 'history',
        'icon': Icons.query_stats_rounded,
        'title': 'Riwayat',
        'color': const Color(0xFF7C3AED), // Violet
        'bg': const Color(0xFFF5F3FF),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SalesHistoryPage()),
            ),
      },
      {
        'key': 'debts_receivables',
        'icon': Icons.account_balance_wallet_rounded,
        'title': 'Hutang Piutang',
        'color': const Color(0xFFEA580C), // Orange
        'bg': const Color(0xFFFFF7ED),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DebtsReceivablesPage()),
            ),
      },
      {
        'key': 'contacts',
        'icon': Icons.people_alt_rounded,
        'title': 'Kontak',
        'color': const Color(0xFF475569), // Slate
        'bg': const Color(0xFFF1F5F9),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ContactsPage()),
            ),
      },
      {
        'key': 'returns',
        'icon': Icons.assignment_return_rounded,
        'title': 'Retur',
        'color': const Color(0xFFE11D48), // Rose
        'bg': const Color(0xFFFFF1F2),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReturnsMenuPage()),
            ),
      },
    ];

    final allowedMenus = menus.where((m) => authCubit.isMenuAllowed(m['key'] as String)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP EXECUTIVE APP BAR ──────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GawePOS',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  // Settings button
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569), size: 22),
                    tooltip: 'Pengaturan',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    ),
                  ),
                  // Logout button
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
                    tooltip: 'Keluar',
                    onPressed: () {
                      if (widget.session != null) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('Sesi Kasir Aktif', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            content: const Text(
                              'Anda tidak dapat logout saat shift masih aktif. Silakan akhiri shift terlebih dahulu.',
                              style: TextStyle(fontSize: 13, color: AppConstants.textLightColor),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                            ],
                          ),
                        );
                      } else {
                        context.read<AuthCubit>().logout();
                      }
                    },
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE2E8F0)),

            // ── SCROLLABLE BODY ───────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0F172A),
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User greeting strip
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                widget.user.name[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  widget.user.role.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Live Clock Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 5),
                                Text(
                                  _currentTime,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Stat card shift (Slate Glassmorphism Modern)
                      widget.session == null
                          ? _buildOpenShiftPromptCard()
                          : FutureBuilder<Map<String, dynamic>?>(
                              future: context.read<AuthCubit>().getActiveSessionDetails(),
                              builder: (context, snapshot) {
                                final details = snapshot.data;
                                return _buildStatCard(details, widget.session!.openingCash);
                              },
                            ),

                      const SizedBox(height: 20),

                      // Section title: Menu Aplikasi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Menu & Operasional',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${allowedMenus.length} Layanan',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Menu Grid Bento Style
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: allowedMenus.length,
                        itemBuilder: (context, index) {
                          final m = allowedMenus[index];
                          return _buildMenuCard(
                            icon: m['icon'] as IconData,
                            title: m['title'] as String,
                            color: m['color'] as Color,
                            bgColor: m['bg'] as Color? ?? (m['color'] as Color).withValues(alpha: 0.1),
                            onTap: m['onTap'] as VoidCallback,
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Close Shift Card
                      if (widget.session != null) ...[
                        FutureBuilder<double>(
                          future: context.read<AuthCubit>().getExpectedCashAmount(),
                          builder: (context, snapshot) {
                            final expected = snapshot.data ?? widget.session!.openingCash;
                            return _buildCloseShiftCard(context, expected);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modern Slate/Emerald Shift Card
  Widget _buildStatCard(Map<String, dynamic>? details, double openingCash) {
    final double expected = details?['expectedCash'] ?? openingCash;
    final Map<String, dynamic> paymentDetails = details?['paymentDetails'] ?? {
      'cash': 0.0,
      'qris': 0.0,
      'card': 0.0,
      'transfer': 0.0,
    };
    final Map<String, dynamic> cashSources = details?['cashSources'] ?? {
      'opening': openingCash,
      'sales': 0.0,
      'debts': 0.0,
      'supplierDebts': 0.0,
      'expenses': 0.0,
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Executive Deep Slate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981), // Emerald Pulse
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SHIFT KASIR AKTIF',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                Text(
                  _currentDate,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Kas Laci Teoretis',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.format(expected),
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.login_rounded, size: 13, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text(
                      'Buka: ${widget.session!.openTime.toString().substring(11, 16)}',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, size: 13, color: Colors.white.withValues(alpha: 0.6)),
                    const SizedBox(width: 5),
                    Text(
                      'Modal: ${CurrencyFormatter.format(widget.session!.openingCash)}',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => _showShiftDetails = !_showShiftDetails),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showShiftDetails ? 'Sembunyikan Rincian Kas' : 'Lihat Rincian Kas Laci',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF60A5FA),
                      ),
                    ),
                    Icon(
                      _showShiftDetails ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF60A5FA),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            if (_showShiftDetails) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 10),
              Text(
                'Metode Pembayaran Masuk:',
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 4),
              _buildStatDetailRow('Tunai (Cash)', paymentDetails['cash'] ?? 0.0),
              _buildStatDetailRow('QRIS', paymentDetails['qris'] ?? 0.0),
              _buildStatDetailRow('EDC / Kartu', paymentDetails['card'] ?? 0.0),
              _buildStatDetailRow('Transfer Bank', paymentDetails['transfer'] ?? 0.0),
              const SizedBox(height: 10),
              Text(
                'Arus Fisik Laci:',
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 4),
              _buildStatDetailRow('Modal Awal (+)', cashSources['opening'] ?? 0.0),
              _buildStatDetailRow('Penjualan Tunai (+)', cashSources['sales'] ?? 0.0),
              _buildStatDetailRow('Penerimaan Piutang (+)', cashSources['debts'] ?? 0.0),
              _buildStatDetailRow('Pengeluaran Toko (-)', cashSources['expenses'] ?? 0.0, isNegative: true),
              _buildStatDetailRow('Bayar Hutang Supplier (-)', cashSources['supplierDebts'] ?? 0.0, isNegative: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatDetailRow(String label, double amount, {bool isNegative = false}) {
    final formatted = CurrencyFormatter.format(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7)),
          ),
          Text(
            isNegative && amount > 0 ? '- $formatted' : formatted,
            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Close shift card modern
  Widget _buildCloseShiftCard(BuildContext context, double expected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)), // Rose 200
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_clock_rounded, color: Color(0xFFE11D48), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesi Kasir Masih Berjalan',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), fontSize: 13),
                ),
                Text(
                  'Tutup shift untuk serah terima kas.',
                  style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _showCloseShiftDialog(context, expected),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text('Tutup Shift', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Menu card ala fintech launcher
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              color: const Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftPromptCard() {
    final openingCashController = TextEditingController(text: '0');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFFFBBF24)),
              ),
              const SizedBox(width: 10),
              Text(
                'Shift Kasir Belum Dibuka',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Buka shift kasir terlebih dahulu untuk memulai transaksi dan mencatat modal awal kas laci.',
            style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white70, height: 1.3),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    'Buka Shift Kasir',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Masukkan saldo kas awal di laci kasir:',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: openingCashController,
                        decoration: InputDecoration(
                          labelText: 'Kas Awal',
                          prefixText: 'Rp ',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final cash = double.tryParse(openingCashController.text) ?? 0.0;
                        Navigator.pop(ctx);
                        context.read<AuthCubit>().openShift(cash);
                      },
                      child: Text('Buka Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.vpn_key_rounded, size: 15),
            label: Text('Buka Shift Sekarang', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showOpenShiftRequiredDialog(BuildContext context) {
    final openingCashController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Shift Belum Dibuka',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Anda harus membuka shift kasir terlebih dahulu untuk masuk ke POS Kasir. Masukkan modal kas awal:',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569), height: 1.3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: openingCashController,
              decoration: InputDecoration(
                labelText: 'Kas Awal',
                prefixText: 'Rp ',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final cash = double.tryParse(openingCashController.text) ?? 0.0;
              Navigator.pop(ctx);
              context.read<AuthCubit>().openShift(cash);
            },
            child: Text('Buka Shift', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
