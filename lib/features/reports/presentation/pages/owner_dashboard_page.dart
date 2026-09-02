import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/reports_cubit.dart';
import 'pnl_report_page.dart';
import 'sales_report_page.dart';
import 'shift_report_page.dart';
import 'stock_report_page.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  String _selectedRange = 'Bulan Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    _loadData();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'Hari Ini':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case '7 Hari Terakhir':
        _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Bulan Ini':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }
  }

  void _loadData() {
    context.read<ReportsCubit>().loadDashboard(start: _startDate, end: _endDate);
  }

  String get _dateRangeLabel {
    final fmt = DateFormat('dd MMM yyyy', 'id');
    return '${fmt.format(_startDate)} - ${fmt.format(_endDate)}';
  }

  void _showHppInfoDialog(BuildContext context) {
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
                color: AppConstants.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppConstants.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Perhitungan HPP',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HPP (Harga Pokok Penjualan) dihitung per unit barang yang terjual dengan formula akurasi:',
                style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 14),
              _buildDialogInfoCard(
                title: '1. Riwayat Pembelian Terakhir',
                desc: 'Mengambil harga restok terakhir dari transaksi pembelian barang.',
                badge: 'Prioritas',
                badgeColor: AppConstants.primaryColor,
              ),
              const SizedBox(height: 10),
              _buildDialogInfoCard(
                title: '2. Estimasi Dasar (Fallback)',
                desc: 'Jika belum pernah ada histori restok, estimasi HPP dihitung 60% dari harga jual.',
                badge: 'Cadangan',
                badgeColor: const Color(0xFFD97706),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoCard({
    required String title,
    required String desc,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B), height: 1.3),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _selectedRange = 'Pilih Tanggal';
      });
      _loadData();
    }
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
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Eksekutif',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF0F172A)),
            ),
            Text(
              'Ringkasan Finansial & Operasional',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF334155)),
              tooltip: 'Segarkan Data',
              onPressed: _loadData,
            ),
          ),
        ],
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          if (state.isDashboardLoading && state.dashboardData == null) {
            return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
          }
          if (state.dashboardError != null && state.dashboardData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.error_outline_rounded, size: 36, color: Colors.red.shade600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal Memuat Data',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.dashboardError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.5),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state.dashboardData != null) {
            return _buildBody(state.dashboardData!);
          }
          return const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor));
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final double grossSales = (data['grossSales'] as num?)?.toDouble() ?? 0.0;
    final double netProfit = (data['netProfit'] as num?)?.toDouble() ?? 0.0;
    final double grossProfit = (data['grossProfit'] as num?)?.toDouble() ?? 0.0;
    final double expenses = (data['expenses'] as num?)?.toDouble() ?? 0.0;
    final double hpp = (data['hpp'] as num?)?.toDouble() ?? 0.0;
    final int transactionCount = data['transactionCount'] ?? 0;
    final List<Map<String, dynamic>> trend = List<Map<String, dynamic>>.from(data['trend'] ?? []);
    final List<Map<String, dynamic>> bestSellers = List<Map<String, dynamic>>.from(data['bestSellers'] ?? []);
    final List<Map<String, dynamic>> lowStock = List<Map<String, dynamic>>.from(data['lowStock'] ?? []);

    final double profitMargin = grossSales > 0 ? (netProfit / grossSales) * 100 : 0.0;
    final double avgTicket = transactionCount > 0 ? grossSales / transactionCount : 0.0;

    final bool isTablet = MediaQuery.of(context).size.width > 720;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isTablet
              ? _buildTabletDashboardLayout(
                  grossSales: grossSales,
                  netProfit: netProfit,
                  grossProfit: grossProfit,
                  expenses: expenses,
                  hpp: hpp,
                  transactionCount: transactionCount,
                  profitMargin: profitMargin,
                  avgTicket: avgTicket,
                  trend: trend,
                  bestSellers: bestSellers,
                  lowStock: lowStock,
                )
              : _buildMobileDashboardLayout(
                  grossSales: grossSales,
                  netProfit: netProfit,
                  grossProfit: grossProfit,
                  expenses: expenses,
                  hpp: hpp,
                  transactionCount: transactionCount,
                  profitMargin: profitMargin,
                  avgTicket: avgTicket,
                  trend: trend,
                  bestSellers: bestSellers,
                  lowStock: lowStock,
                ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 MOBILE DASHBOARD LAYOUT (<= 720px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileDashboardLayout({
    required double grossSales,
    required double netProfit,
    required double grossProfit,
    required double expenses,
    required double hpp,
    required int transactionCount,
    required double profitMargin,
    required double avgTicket,
    required List<Map<String, dynamic>> trend,
    required List<Map<String, dynamic>> bestSellers,
    required List<Map<String, dynamic>> lowStock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PERIOD SELECTOR
        _buildPeriodSection(isTablet: false),
        const SizedBox(height: 16),

        // 2. EXECUTIVE FINANCIAL HERO CARD
        _buildExecutiveHeroCard(
          netProfit: netProfit,
          grossSales: grossSales,
          profitMargin: profitMargin,
          transactionCount: transactionCount,
          avgTicket: avgTicket,
        ),
        const SizedBox(height: 16),

        // 3. KEY METRICS BENTO GRID (2x2)
        _buildMetricsGrid(
          grossSales: grossSales,
          hpp: hpp,
          grossProfit: grossProfit,
          expenses: expenses,
        ),
        const SizedBox(height: 20),

        // 4. SALES VELOCITY / TREND CHART
        _buildTrendChartCard(trend),
        const SizedBox(height: 20),

        // 5. FINANCIAL BREAKDOWN VISUALIZER (Arus Kas)
        _buildFinancialFlowCard(
          grossSales: grossSales,
          hpp: hpp,
          grossProfit: grossProfit,
          expenses: expenses,
          netProfit: netProfit,
        ),
        const SizedBox(height: 20),

        // 6. TOP SELLING PRODUCTS
        _buildTopPerformersCard(bestSellers),
        const SizedBox(height: 16),

        // 7. INVENTORY SENTINEL (Stok Menipis)
        _buildInventoryAlertCard(lowStock),
        const SizedBox(height: 20),

        // 8. QUICK ACCESS BAR
        _buildQuickShortcuts(),
        const SizedBox(height: 36),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📟 TABLET DASHBOARD LAYOUT (> 720px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletDashboardLayout({
    required double grossSales,
    required double netProfit,
    required double grossProfit,
    required double expenses,
    required double hpp,
    required int transactionCount,
    required double profitMargin,
    required double avgTicket,
    required List<Map<String, dynamic>> trend,
    required List<Map<String, dynamic>> bestSellers,
    required List<Map<String, dynamic>> lowStock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Period Selector (Horizontal Bar on Tablet)
        _buildPeriodSection(isTablet: true),
        const SizedBox(height: 18),

        // 2. Top Row: Financial Hero (flex 5) & 4 Key Metrics (flex 7)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildExecutiveHeroCard(
                netProfit: netProfit,
                grossSales: grossSales,
                profitMargin: profitMargin,
                transactionCount: transactionCount,
                avgTicket: avgTicket,
                isTablet: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: _buildMetricsGrid(
                grossSales: grossSales,
                hpp: hpp,
                grossProfit: grossProfit,
                expenses: expenses,
                isTablet: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 3. Middle Row: Sales Velocity Chart (50%) & Financial Flow / Arus Kas (50%)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTrendChartCard(trend, isTablet: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFinancialFlowCard(
                grossSales: grossSales,
                hpp: hpp,
                grossProfit: grossProfit,
                expenses: expenses,
                netProfit: netProfit,
                isTablet: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // 4. Bottom Row: Top Best Selling Products (50%) & Inventory Sentinel + Shortcuts (50%)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTopPerformersCard(bestSellers, isTablet: true),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInventoryAlertCard(lowStock, isTablet: true),
                  const SizedBox(height: 16),
                  _buildQuickShortcuts(isTablet: true),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  PERIOD SELECTOR SECTION
  // ─────────────────────────────────────────
  Widget _buildPeriodSection({bool isTablet = false}) {
    final periods = ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini'];

    if (isTablet) {
      return Row(
        children: [
          // Segmented Bar
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: periods.map((range) {
                  final isSelected = _selectedRange == range;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedRange = range);
                        _updateDateRange();
                        _loadData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            range,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Custom Date Range Picker Chip
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () => _selectDateRange(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dateRangeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedRange == 'Pilih Tanggal' ? 'Kustom' : 'Ubah',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppConstants.primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: periods.map((range) {
              final isSelected = _selectedRange == range;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedRange = range);
                    _updateDateRange();
                    _loadData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        range,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Custom Date Range Chip / Bar
        InkWell(
          onTap: () => _selectDateRange(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  _dateRangeLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                Text(
                  _selectedRange == 'Pilih Tanggal' ? 'Kustom' : 'Ubah Rentang',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppConstants.primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  EXECUTIVE HERO CARD (Deep Slate & Glassmorphism)
  // ─────────────────────────────────────────
  Widget _buildExecutiveHeroCard({
    required double netProfit,
    required double grossSales,
    required double profitMargin,
    required int transactionCount,
    required double avgTicket,
    bool isTablet = false,
  }) {
    final bool isPositive = netProfit >= 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 18 : 20),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient light pattern
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isTablet ? 18 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isPositive ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PROFIT BERSIH',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Margin badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isPositive ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isPositive ? const Color(0xFF34D399) : const Color(0xFFF87171)).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 13,
                            color: isPositive ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Margin ${profitMargin.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isPositive ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Big Net Profit Value
                Text(
                  (isPositive ? '' : '-') + CurrencyFormatter.format(netProfit.abs()),
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 26 : 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 14),

                // Bottom KPIs (Gross Sales, Orders, Avg Basket)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildHeroSubMetric(
                        label: 'Omzet Penjualan',
                        value: CurrencyFormatter.format(grossSales),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _buildHeroSubMetric(
                        label: 'Transaksi',
                        value: '$transactionCount Struk',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    Expanded(
                      child: _buildHeroSubMetric(
                        label: 'Rata-rata/Struk',
                        value: CurrencyFormatter.format(avgTicket),
                        icon: Icons.shopping_basket_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
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
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  METRICS BENTO GRID (2x2)
  // ─────────────────────────────────────────
  Widget _buildMetricsGrid({
    required double grossSales,
    required double hpp,
    required double grossProfit,
    required double expenses,
    bool isTablet = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildBentoMetricCard(
              width: cardWidth,
              title: 'Omzet Kotor',
              value: grossSales,
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFF2563EB), // Royal Blue
              bgColor: const Color(0xFFEFF6FF),
              subtitle: 'Penjualan riil belum potong HPP',
              isTablet: isTablet,
            ),
            _buildBentoMetricCard(
              width: cardWidth,
              title: 'Beban Pokok (HPP)',
              value: hpp,
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFFD97706), // Amber
              bgColor: const Color(0xFFFFFBEB),
              subtitle: 'Modal pokok barang keluar',
              trailing: GestureDetector(
                onTap: () => _showHppInfoDialog(context),
                child: const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFFB45309)),
              ),
              isTablet: isTablet,
            ),
            _buildBentoMetricCard(
              width: cardWidth,
              title: 'Laba Kotor',
              value: grossProfit,
              icon: Icons.show_chart_rounded,
              iconColor: const Color(0xFF7C3AED), // Purple
              bgColor: const Color(0xFFF5F3FF),
              subtitle: 'Omzet dikurangi modal HPP',
              isTablet: isTablet,
            ),
            _buildBentoMetricCard(
              width: cardWidth,
              title: 'Biaya Operasional',
              value: expenses,
              icon: Icons.outbox_rounded,
              iconColor: const Color(0xFFDC2626), // Rose Red
              bgColor: const Color(0xFFFEF2F2),
              subtitle: 'Beban operasional & lain-lain',
              isTablet: isTablet,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBentoMetricCard({
    required double width,
    required String title,
    required double value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String subtitle,
    Widget? trailing,
    bool isTablet = false,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(isTablet ? 13 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: isTablet ? 8 : 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 11 : 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            CurrencyFormatter.format(value),
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 14 : 14.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  TREND CHART CARD
  // ─────────────────────────────────────────
  Widget _buildTrendChartCard(List<Map<String, dynamic>> trend, {bool isTablet = false}) {
    double totalWeekSales = 0.0;
    for (var t in trend) {
      totalWeekSales += (t['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 18 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Penjualan',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Performa 7 Hari Terakhir',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total: ${CurrencyFormatter.format(totalWeekSales)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (trend.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text('Belum ada histori penjualan 7 hari terakhir.',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
              ),
            )
          else
            _buildFlChart(trend),
        ],
      ),
    );
  }

  Widget _buildFlChart(List<Map<String, dynamic>> trend) {
    final List<FlSpot> spots = [];
    double maxAmount = 0.0;
    for (int i = 0; i < trend.length; i++) {
      final double amt = (trend[i]['amount'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), amt));
      if (amt > maxAmount) maxAmount = amt;
    }
    if (maxAmount == 0.0) maxAmount = 100000.0;

    return SizedBox(
      height: 190,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxAmount / 4,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Color(0xFFF1F5F9),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < trend.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        trend[idx]['day'],
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxAmount / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Text(
                    value >= 1000000
                        ? '${(value / 1000000).toStringAsFixed(1)}jt'
                        : value >= 1000
                            ? '${(value / 1000).toStringAsFixed(0)}rb'
                            : value.toStringAsFixed(0),
                    style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: maxAmount * 1.15,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 10,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final day = idx >= 0 && idx < trend.length ? trend[idx]['day'] : '';
                  return LineTooltipItem(
                    '$day\n',
                    GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                    children: [
                      TextSpan(
                        text: CurrencyFormatter.format(spot.y),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFF2563EB),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: const Color(0xFF2563EB),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.18),
                    const Color(0xFF2563EB).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  FINANCIAL FLOW BREAKDOWN (Arus Kas)
  // ─────────────────────────────────────────
  Widget _buildFinancialFlowCard({
    required double grossSales,
    required double hpp,
    required double grossProfit,
    required double expenses,
    required double netProfit,
    bool isTablet = false,
  }) {
    final double hppPercent = grossSales > 0 ? (hpp / grossSales).clamp(0.0, 1.0) : 0.0;
    final double expPercent = grossSales > 0 ? (expenses / grossSales).clamp(0.0, 1.0) : 0.0;
    final double profitPercent = grossSales > 0 ? (netProfit / grossSales).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 18 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Struktur Arus Kas',
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PnlReportPage()),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Laporan P&L',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppConstants.primaryColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Proportion Segment Bar
          if (grossSales > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (hppPercent > 0)
                      Expanded(
                        flex: (hppPercent * 100).toInt(),
                        child: Container(color: const Color(0xFFF59E0B)), // HPP Amber
                      ),
                    if (expPercent > 0)
                      Expanded(
                        flex: (expPercent * 100).toInt(),
                        child: Container(color: const Color(0xFFEF4444)), // Expenses Red
                      ),
                    if (profitPercent > 0)
                      Expanded(
                        flex: (profitPercent * 100).toInt(),
                        child: Container(color: const Color(0xFF10B981)), // Profit Green
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFlowLegend(label: 'HPP (${(hppPercent * 100).toStringAsFixed(0)}%)', color: const Color(0xFFF59E0B)),
                _buildFlowLegend(label: 'Biaya (${(expPercent * 100).toStringAsFixed(0)}%)', color: const Color(0xFFEF4444)),
                _buildFlowLegend(label: 'Net (${(profitPercent * 100).toStringAsFixed(0)}%)', color: const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
          ],

          // Breakdown List Rows
          _buildFlowRow(
            label: 'Total Omzet Kotor',
            amount: grossSales,
            color: const Color(0xFF0F172A),
            isBold: true,
          ),
          const SizedBox(height: 8),
          _buildFlowRow(
            label: 'Harga Pokok Penjualan (HPP)',
            amount: -hpp,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(height: 8),
          _buildFlowRow(
            label: 'Laba Kotor (Gross Profit)',
            amount: grossProfit,
            color: const Color(0xFF475569),
          ),
          const SizedBox(height: 8),
          _buildFlowRow(
            label: 'Biaya Operasional Toko',
            amount: -expenses,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laba Bersih Akhir',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Setelah HPP & seluruh biaya',
                    style: GoogleFonts.poppins(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Text(
                (netProfit >= 0 ? '+' : '') + CurrencyFormatter.format(netProfit),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowLegend({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildFlowRow({
    required String label,
    required double amount,
    required Color color,
    bool isBold = false,
  }) {
    final bool isNegative = amount < 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF475569),
          ),
        ),
        Text(
          (isNegative ? '- ' : '') + CurrencyFormatter.format(amount.abs()),
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  TOP PERFORMERS (Best Sellers)
  // ─────────────────────────────────────────
  Widget _buildTopPerformersCard(List<Map<String, dynamic>> bestSellers, {bool isTablet = false}) {
    final double maxQty = bestSellers.isNotEmpty ? (bestSellers.first['qty'] as num?)?.toDouble() ?? 1.0 : 1.0;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 18 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Produk Terlaris',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Top 5 Barang',
                style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (bestSellers.isEmpty)
            SizedBox(
              height: 80,
              child: Center(
                child: Text('Belum ada transaksi produk pada periode ini.',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
              ),
            )
          else
            Column(
              children: bestSellers.asMap().entries.map((entry) {
                final int index = entry.key;
                final item = entry.value;
                final double qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
                final double ratio = maxQty > 0 ? (qty / maxQty).clamp(0.05, 1.0) : 0.0;

                // Color rank
                Color badgeBg;
                Color badgeText;
                if (index == 0) {
                  badgeBg = const Color(0xFFFEF3C7);
                  badgeText = const Color(0xFFB45309);
                } else if (index == 1) {
                  badgeBg = const Color(0xFFF1F5F9);
                  badgeText = const Color(0xFF475569);
                } else if (index == 2) {
                  badgeBg = const Color(0xFFFFEDD5);
                  badgeText = const Color(0xFFC2410C);
                } else {
                  badgeBg = const Color(0xFFF8FAFC);
                  badgeText = const Color(0xFF94A3B8);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Stack(
                    children: [
                      // Background progress fill
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeText,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] ?? '-',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${CurrencyFormatter.formatQty(qty)} Terjual',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  INVENTORY SENTINEL (Low Stock)
  // ─────────────────────────────────────────
  Widget _buildInventoryAlertCard(List<Map<String, dynamic>> lowStock, {bool isTablet = false}) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 18 : 20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Peringatan Stok Menipis',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StockReportPage()),
                  );
                },
                child: Text(
                  'Cek Semua',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (lowStock.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Text(
                    'Seluruh stok barang dalam kondisi aman',
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF059669)),
                  ),
                ],
              ),
            )
          else
            Column(
              children: lowStock.take(isTablet ? 4 : 5).map((item) {
                final Product p = item['product'];
                final ProductUnit u = item['unit'];
                final double currentStock = (item['currentStock'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE4E6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.priority_high_rounded, size: 11, color: Color(0xFFE11D48)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sisa ${CurrencyFormatter.formatQty(currentStock)} ${u.name}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  QUICK ACCESS SHORTCUTS
  // ─────────────────────────────────────────
  Widget _buildQuickShortcuts({bool isTablet = false}) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(isTablet ? 18 : 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Laporan Lengkap Toko',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildShortcutButton(
                title: 'Laba Rugi',
                icon: Icons.analytics_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PnlReportPage())),
              ),
              const SizedBox(width: 6),
              _buildShortcutButton(
                title: 'Penjualan',
                icon: Icons.receipt_long_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesReportPage())),
              ),
              const SizedBox(width: 6),
              _buildShortcutButton(
                title: 'Stok Barang',
                icon: Icons.inventory_2_outlined,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockReportPage())),
              ),
              const SizedBox(width: 8),
              _buildShortcutButton(
                title: 'Shift Kasir',
                icon: Icons.access_time_rounded,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ShiftReportPage())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
