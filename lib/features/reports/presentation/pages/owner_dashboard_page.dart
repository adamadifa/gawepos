import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/reports_cubit.dart';

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
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppConstants.textDarkColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Dashboard Owner',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          if (state.isDashboardLoading && state.dashboardData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.dashboardError != null && state.dashboardData == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  state.dashboardError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppConstants.errorColor),
                ),
              ),
            );
          }
          if (state.dashboardData != null) {
            return _buildBody(state.dashboardData!);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final double grossSales = data['grossSales'] ?? 0.0;
    final double netProfit = data['netProfit'] ?? 0.0;
    final double grossProfit = data['grossProfit'] ?? 0.0;
    final double expenses = data['expenses'] ?? 0.0;
    final double hpp = data['hpp'] ?? 0.0;
    final int transactionCount = data['transactionCount'] ?? 0;
    final List<Map<String, dynamic>> trend = List<Map<String, dynamic>>.from(data['trend'] ?? []);
    final List<Map<String, dynamic>> bestSellers = List<Map<String, dynamic>>.from(data['bestSellers'] ?? []);
    final List<Map<String, dynamic>> lowStock = List<Map<String, dynamic>>.from(data['lowStock'] ?? []);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══════════════════════════════════════
          //  BLUE SUMMARY CARD (Hero section)
          // ═══════════════════════════════════════
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A56DB).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top labels row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Penjualan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      'Profit Bersih',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Big values row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        CurrencyFormatter.format(grossSales),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (netProfit >= 0 ? '+' : '') + CurrencyFormatter.format(netProfit),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: netProfit >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          netProfit >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 16,
                          color: netProfit >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 12),
                // Bottom row: Transaction Count & HPP
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text(
                          '$transactionCount Transaksi',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'HPP: ',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(hpp),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          //  DATE RANGE PICKER CARD
          // ═══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                onTap: () => _selectDateRange(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.date_range_rounded,
                          color: AppConstants.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Periode Laporan',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppConstants.textLightColor,
                              ),
                            ),
                            Text(
                              _dateRangeLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textDarkColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppConstants.textLightColor,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Quick Select Chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini'].map((range) {
                final isSelected = _selectedRange == range;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedRange = range);
                        _updateDateRange();
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppConstants.primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppConstants.primaryColor.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            range,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppConstants.textLightColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // ═══════════════════════════════════════
          //  TREND CHART
          // ═══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildChartCard(trend),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════
          //  CASH FLOW SECTION
          // ═══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCashFlowSection(grossSales, hpp, grossProfit, expenses, netProfit),
          ),

          const SizedBox(height: 24),

          // ═══════════════════════════════════════
          //  BEST SELLERS
          // ═══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildListSection(
              title: 'Produk Terlaris',
              icon: Icons.star_rounded,
              child: _buildBestSellersContent(bestSellers),
            ),
          ),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════
          //  LOW STOCK
          // ═══════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildListSection(
              title: 'Stok Menipis',
              icon: Icons.warning_amber_rounded,
              child: _buildLowStockContent(lowStock),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  CHART CARD
  // ─────────────────────────────────────────
  Widget _buildChartCard(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text('Belum ada data tren.', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
        ),
      );
    }

    final List<FlSpot> spots = [];
    double maxAmount = 0.0;
    for (int i = 0; i < trend.length; i++) {
      final double amt = trend[i]['amount'];
      spots.add(FlSpot(i.toDouble(), amt));
      if (amt > maxAmount) maxAmount = amt;
    }
    if (maxAmount == 0.0) maxAmount = 100000.0;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxAmount / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < trend.length) {
                    return Text(
                      trend[idx]['day'],
                      style: GoogleFonts.poppins(fontSize: 9, color: AppConstants.textLightColor),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: maxAmount / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      value >= 1000000
                          ? '${(value / 1000000).toStringAsFixed(1)}jt'
                          : value >= 1000
                              ? '${(value / 1000).toStringAsFixed(0)}k'
                              : value.toStringAsFixed(0),
                      style: GoogleFonts.poppins(fontSize: 9, color: AppConstants.textLightColor),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: maxAmount * 1.2,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final idx = spot.x.toInt();
                  final day = idx >= 0 && idx < trend.length ? trend[idx]['day'] : '';
                  return LineTooltipItem(
                    '$day\n${CurrencyFormatter.format(spot.y)}',
                    GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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
              color: AppConstants.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: AppConstants.primaryColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppConstants.primaryColor.withValues(alpha: 0.25),
                    AppConstants.primaryColor.withValues(alpha: 0.02),
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
  //  CASH FLOW SECTION
  // ─────────────────────────────────────────
  Widget _buildCashFlowSection(
    double grossSales,
    double hpp,
    double grossProfit,
    double expenses,
    double netProfit,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arus Kas',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDarkColor,
                ),
              ),
              Text(
                _dateRangeLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppConstants.textLightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Penjualan Kotor
          _buildCashFlowRow(
            dotColor: const Color(0xFF3B82F6),
            label: 'Penjualan Kotor',
            amount: grossSales,
            isPositive: true,
          ),
          const SizedBox(height: 14),

          // HPP
          _buildCashFlowRow(
            dotColor: const Color(0xFFF59E0B),
            label: 'Harga Pokok (HPP)',
            amount: hpp,
            isPositive: false,
          ),
          const SizedBox(height: 14),

          // Gross Profit
          _buildCashFlowRow(
            dotColor: const Color(0xFF8B5CF6),
            label: 'Profit Kotor',
            amount: grossProfit,
            isPositive: true,
          ),
          const SizedBox(height: 14),

          // Expenses
          _buildCashFlowRow(
            dotColor: const Color(0xFFEF4444),
            label: 'Biaya Operasional',
            amount: expenses,
            isPositive: false,
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),

          // Total (Net Profit)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Profit Bersih',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDarkColor,
                ),
              ),
              Text(
                (netProfit >= 0 ? '+' : '') + CurrencyFormatter.format(netProfit),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: netProfit >= 0 ? const Color(0xFF059669) : AppConstants.errorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowRow({
    required Color dotColor,
    required String label,
    required double amount,
    required bool isPositive,
  }) {
    return Row(
      children: [
        // Colored dot
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppConstants.textDarkColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isPositive ? const Color(0xFF059669) : AppConstants.errorColor,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  GENERIC LIST SECTION CARD
  // ─────────────────────────────────────────
  Widget _buildListSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textDarkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BEST SELLERS CONTENT
  // ─────────────────────────────────────────
  Widget _buildBestSellersContent(List<Map<String, dynamic>> bestSellers) {
    if (bestSellers.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Belum ada data penjualan.',
            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
          ),
        ),
      );
    }

    return Column(
      children: bestSellers.asMap().entries.map((entry) {
        final int index = entry.key;
        final item = entry.value;

        // Medal colors for top 3
        Color rankColor;
        if (index == 0) {
          rankColor = const Color(0xFFFFD700);
        } else if (index == 1) {
          rankColor = const Color(0xFFC0C0C0);
        } else if (index == 2) {
          rankColor = const Color(0xFFCD7F32);
        } else {
          rankColor = Colors.grey.shade400;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: index < 3
                      ? Icon(Icons.emoji_events_rounded, size: 16, color: rankColor)
                      : Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textLightColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.textDarkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${CurrencyFormatter.formatQty(item['qty'])}x',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────
  //  LOW STOCK CONTENT
  // ─────────────────────────────────────────
  Widget _buildLowStockContent(List<Map<String, dynamic>> lowStock) {
    if (lowStock.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 20, color: AppConstants.successColor.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'Semua stok barang aman!',
                style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.successColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: lowStock.take(5).map((item) {
        final Product p = item['product'];
        final ProductUnit u = item['unit'];
        final double currentStock = item['currentStock'];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 16, color: AppConstants.errorColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppConstants.textDarkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Sisa ${CurrencyFormatter.formatQty(currentStock)} ${u.name}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.errorColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
