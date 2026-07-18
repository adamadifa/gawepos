import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/reports_repository.dart';

class PointsReportPage extends StatefulWidget {
  const PointsReportPage({super.key});

  @override
  State<PointsReportPage> createState() => _PointsReportPageState();
}

class _PointsReportPageState extends State<PointsReportPage> {
  final ReportsRepository _repo = getIt<ReportsRepository>();

  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  int _totalEarned = 0;
  int _totalRedeemed = 0;
  int _netPoints = 0;
  int _transactionCount = 0;
  List<Map<String, dynamic>> _details = [];

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    _loadData();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    if (_selectedRange == 'Hari Ini') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedRange == '7 Hari Terakhir') {
      _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedRange == 'Bulan Ini') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getPointsReport(_startDate, _endDate);
      setState(() {
        _totalEarned = data['totalEarned'] as int;
        _totalRedeemed = data['totalRedeemed'] as int;
        _netPoints = data['netPoints'] as int;
        _transactionCount = data['transactionCount'] as int;
        _details = (data['details'] as List<Map<String, dynamic>>).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Poin',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildPeriodFilter(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            _buildSummaryCards(),
            const Divider(height: 1, color: AppConstants.borderLightColor),
            Expanded(child: _buildDetailList()),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    final ranges = ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Kustom'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ranges.map((r) {
          final selected = _selectedRange == r;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () async {
                if (r == 'Kustom') {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                  );
                  if (picked != null) {
                    _startDate = picked.start;
                    _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                    _selectedRange = 'Kustom';
                    _loadData();
                  }
                } else {
                  setState(() => _selectedRange = r);
                  _updateDateRange();
                  _loadData();
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppConstants.primaryColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  r,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? Colors.white : AppConstants.textDarkColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildSummaryItem(
            icon: Icons.add_circle_outline_rounded,
            color: AppConstants.successColor,
            label: 'Poin Diberikan',
            value: _totalEarned.toString(),
          ),
          _buildSummaryItem(
            icon: Icons.remove_circle_outline_rounded,
            color: AppConstants.errorColor,
            label: 'Poin Ditukar',
            value: _totalRedeemed.toString(),
          ),
          _buildSummaryItem(
            icon: Icons.card_giftcard_rounded,
            color: AppConstants.warningColor,
            label: 'Sisa Poin',
            value: _netPoints.toString(),
          ),
          _buildSummaryItem(
            icon: Icons.receipt_long_rounded,
            color: AppConstants.primaryColor,
            label: 'Transaksi',
            value: _transactionCount.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppConstants.textDarkColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: AppConstants.textLightColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList() {
    if (_details.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi poin',
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _details.length,
      itemBuilder: (context, index) {
        final item = _details[index];
        final txn = item['transaction'] as dynamic;
        final customerName = item['customerName'] as String;
        final isEarn = txn.type == 'earn';
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(txn.createdAt as DateTime);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: (isEarn ? AppConstants.successColor : AppConstants.errorColor).withValues(alpha: 0.1),
              child: Icon(
                isEarn ? Icons.add_rounded : Icons.remove_rounded,
                color: isEarn ? AppConstants.successColor : AppConstants.errorColor,
                size: 16,
              ),
            ),
            title: Text(
              customerName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            subtitle: Text(
              '${isEarn ? '+${txn.points}' : '-${txn.points.abs()}'} poin  |  $dateStr',
              style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor),
            ),
            trailing: txn.description != null
                ? SizedBox(
                    width: 80,
                    child: Text(
                      txn.description as String,
                      style: GoogleFonts.poppins(fontSize: 9, color: AppConstants.textLightColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
