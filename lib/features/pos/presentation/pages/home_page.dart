import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/curved_header.dart';
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
        title: Text(
          'Akhiri Shift Kasir',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                border: Border.all(
                    color: AppConstants.primaryColor.withValues(alpha: 0.15)),
              ),
              child: Text(
                'Kas teoretis: ${CurrencyFormatter.format(expectedCash)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.primaryColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hitung fisik uang tunai di laci kasir dan masukkan jumlahnya:',
              style: TextStyle(
                  fontSize: 13, color: AppConstants.textLightColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _closingCashController,
              decoration: const InputDecoration(
                labelText: 'Jumlah Fisik Uang Tunai',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              final cash =
                  double.tryParse(_closingCashController.text) ?? 0.0;
              Navigator.pop(ctx);
              context.read<AuthCubit>().closeShift(cash);
            },
            child: const Text('TUTUP SHIFT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final menus = [
      {
        'key': 'pos',
        'icon': Icons.point_of_sale_rounded,
        'title': 'POS Kasir',
        'color': AppConstants.primaryColor,
        'onTap': () {
          if (widget.session == null) {
            _showOpenShiftRequiredDialog(context);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PosPage(),
              ),
            );
          }
        },
      },
      {
        'key': 'products',
        'icon': Icons.inventory_2_rounded,
        'title': 'Produk',
        'color': AppConstants.successColor,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MasterMenuPage(),
              ),
            ),
      },
      {
        'key': 'expenses',
        'icon': Icons.payments_rounded,
        'title': 'Biaya',
        'color': AppConstants.warningColor,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExpensesPage(),
              ),
            ),
      },
      {
        'key': 'restock',
        'icon': Icons.local_shipping_rounded,
        'title': 'Restok',
        'color': Colors.teal,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PurchasesListPage(),
              ),
            ),
      },
      {
        'key': 'opname',
        'icon': Icons.assessment_rounded,
        'title': 'Opname',
        'color': AppConstants.primaryLightColor,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StockOpnamePage(),
              ),
            ),
      },
      {
        'key': 'history',
        'icon': Icons.query_stats_rounded,
        'title': 'Riwayat',
        'color': const Color(0xFF7C3AED), // Violet
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesHistoryPage(),
              ),
            ),
      },
      {
        'key': 'reports',
        'icon': Icons.analytics_rounded,
        'title': 'Laporan',
        'color': Colors.pink,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReportsMenuPage(),
              ),
            ),
      },
      {
        'key': 'owner_dashboard',
        'icon': Icons.dashboard_outlined,
        'title': 'Dashboard',
        'color': Colors.indigo,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OwnerDashboardPage(),
              ),
            ),
      },
      {
        'key': 'debts_receivables',
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'Hutang Piutang',
        'color': Colors.deepOrange,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DebtsReceivablesPage(),
              ),
            ),
      },
      {
        'key': 'contacts',
        'icon': Icons.people_alt_rounded,
        'title': 'Kontak',
        'color': Colors.blueGrey,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ContactsPage(),
              ),
            ),
      },
      {
        'key': 'returns',
        'icon': Icons.assignment_return_rounded,
        'title': 'Retur',
        'color': Colors.redAccent,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReturnsMenuPage(),
              ),
            ),
      },
    ];

    final allowedMenus = menus.where((m) => authCubit.isMenuAllowed(m['key'] as String)).toList();

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          // Background header dengan diagonal clipper
          const CurvedHeader(height: 165),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // ── Top AppBar ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GawePOS',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.settings_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        tooltip: 'Pengaturan Printer & Toko',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.power_settings_new_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        onPressed: () {
                          if (widget.session != null) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(
                                  'Sesi Kasir Aktif',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                ),
                                content: const Text(
                                  'Anda tidak dapat logout saat sesi kasir/shift masih aktif. Silakan akhiri shift terlebih dahulu di bagian bawah halaman sebelum keluar.',
                                  style: TextStyle(fontSize: 13, color: AppConstants.textLightColor),
                                ),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: Row(
                    children: [
                      // Avatar kasir
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSm),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            widget.user.name[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              widget.user.role.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Content ──────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppConstants.primaryColor,
                    onRefresh: () async {
                      // Refresh session details & expected cash in FutureBuilder by rebuilding
                      setState(() {});
                      await Future.delayed(const Duration(milliseconds: 300));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Stat card melayang di atas header
                        widget.session == null
                            ? _buildOpenShiftPromptCard()
                            : FutureBuilder<Map<String, dynamic>?>(
                                future: context
                                    .read<AuthCubit>()
                                    .getActiveSessionDetails(),
                                builder: (context, snapshot) {
                                  final details = snapshot.data;
                                  return _buildStatCard(details, widget.session!.openingCash);
                                },
                              ),
                        const SizedBox(height: 24),

                        // Section title
                        Text(
                          'Menu Transaksi',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Menu Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                          children: allowedMenus.map((m) {
                            return _buildMenuCard(
                              icon: m['icon'] as IconData,
                              title: m['title'] as String,
                              color: m['color'] as Color,
                              onTap: m['onTap'] as VoidCallback,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // Close Shift Card
                        if (widget.session != null) ...[
                          FutureBuilder<double>(
                            future: context
                                .read<AuthCubit>()
                                .getExpectedCashAmount(),
                            builder: (context, snapshot) {
                              final expected =
                                  snapshot.data ?? widget.session!.openingCash;
                              return _buildCloseShiftCard(context, expected);
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Redesigned modern gradient stat card with live digital clock and details.
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan Sesi Shift',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              // Live Digital Clock
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentTime,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Kas Laci Teoretis',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  CurrencyFormatter.format(expected),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Live Local Date
              Text(
                _currentDate,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.login_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Buka: ${widget.session!.openTime.toString().substring(11, 16)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.monetization_on_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    'Modal: ${CurrencyFormatter.format(widget.session!.openingCash)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              setState(() {
                _showShiftDetails = !_showShiftDetails;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showShiftDetails ? 'Sembunyikan Rincian Sesi' : 'Tampilkan Rincian Sesi',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  _showShiftDetails ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
          if (_showShiftDetails) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            Text(
              'Rincian Pembayaran:',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatDetailRow('Tunai (Cash)', paymentDetails['cash'] ?? 0.0),
            _buildStatDetailRow('QRIS', paymentDetails['qris'] ?? 0.0),
            _buildStatDetailRow('EDC / Kartu', paymentDetails['card'] ?? 0.0),
            _buildStatDetailRow('Transfer', paymentDetails['transfer'] ?? 0.0),
            const SizedBox(height: 12),
            Text(
              'Aliran Kas Laci:',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatDetailRow('Modal Kas Awal (+)', cashSources['opening'] ?? 0.0),
            _buildStatDetailRow('Penjualan Tunai (+)', cashSources['sales'] ?? 0.0),
            _buildStatDetailRow('Penerimaan Piutang Tunai (+)', cashSources['debts'] ?? 0.0),
            _buildStatDetailRow('Pengeluaran Toko Tunai (-)', cashSources['expenses'] ?? 0.0, isNegative: true),
            _buildStatDetailRow('Pembayaran Hutang Tunai (-)', cashSources['supplierDebts'] ?? 0.0, isNegative: true),
            _buildStatDetailRow('Retur Penjualan Tunai (-)', cashSources['salesReturns'] ?? 0.0, isNegative: true),
            _buildStatDetailRow('Retur Pembelian Tunai (+)', cashSources['purchaseReturns'] ?? 0.0),
          ],
        ],
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
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            isNegative && amount > 0 ? '- $formatted' : formatted,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Close shift card dengan left-red accent strip.
  Widget _buildCloseShiftCard(BuildContext context, double expected) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left red accent bar
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesi Kasir Aktif',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Akhiri sesi shift sebelum serah terima kas.',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _showCloseShiftDialog(context, expected),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSm),
              ),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
            child: const Text('TUTUP\nSHIFT', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  /// Menu card ala dompet digital (launcher style)
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: AppConstants.textDarkColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildOpenShiftPromptCard() {
    final openingCashController = TextEditingController(text: '0');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade700, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Shift Kasir Belum Dibuka',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Silakan buka shift kasir terlebih dahulu untuk memulai penjualan dan mencatat uang laci.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    'Buka Shift Kasir',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Masukkan saldo kas awal di laci kasir:',
                        style: TextStyle(fontSize: 13, color: AppConstants.textLightColor),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: openingCashController,
                        decoration: const InputDecoration(
                          labelText: 'Kas Awal',
                          prefixText: 'Rp ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('BATAL'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final cash = double.tryParse(openingCashController.text) ?? 0.0;
                        Navigator.pop(ctx);
                        context.read<AuthCubit>().openShift(cash);
                      },
                      child: const Text('BUKA SHIFT'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange.shade800,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.vpn_key_rounded, size: 16),
            label: const Text('BUKA SHIFT SEKARANG'),
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
        title: Text(
          'Shift Belum Dibuka',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Anda harus membuka shift kasir terlebih dahulu untuk masuk ke menu POS Kasir. Silakan masukkan kas awal di laci:',
              style: TextStyle(fontSize: 13, color: AppConstants.textLightColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: openingCashController,
              decoration: const InputDecoration(
                labelText: 'Kas Awal',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              final cash = double.tryParse(openingCashController.text) ?? 0.0;
              Navigator.pop(ctx);
              context.read<AuthCubit>().openShift(cash);
            },
            child: const Text('BUKA SHIFT'),
          ),
        ],
      ),
    );
  }
}
