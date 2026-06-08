import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/app_database.dart';
import '../../data/reports_repository.dart';

class DebtsReceivablesReportPage extends StatefulWidget {
  const DebtsReceivablesReportPage({super.key});

  @override
  State<DebtsReceivablesReportPage> createState() => _DebtsReceivablesReportPageState();
}

class _DebtsReceivablesReportPageState extends State<DebtsReceivablesReportPage> with SingleTickerProviderStateMixin {
  final ReportsRepository _repository = getIt<ReportsRepository>();
  late TabController _tabController;

  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  List<Map<String, dynamic>> _customerDebts = [];
  List<Map<String, dynamic>> _filteredCustomerDebts = [];
  List<Map<String, dynamic>> _supplierDebts = [];
  List<Map<String, dynamic>> _filteredSupplierDebts = [];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
        _applySearchFilter();
      });
    });
    _updateDateRange();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
    setState(() {
      _isLoading = true;
    });
    try {
      final custDebts = await _repository.getCustomerDebtsReport(start: _startDate, end: _endDate);
      final suppDebts = await _repository.getSupplierDebtsReport(start: _startDate, end: _endDate);
      setState(() {
        _customerDebts = custDebts;
        _supplierDebts = suppDebts;
      });
      _applySearchFilter();
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  void _applySearchFilter() {
    setState(() {
      final query = _searchQuery.trim().toLowerCase();
      if (_tabController.index == 0) {
        _filteredCustomerDebts = _customerDebts.where((item) {
          final customerName = (item['customerName'] as String).toLowerCase();
          final referenceNo = (item['referenceNo'] as String).toLowerCase();
          return customerName.contains(query) || referenceNo.contains(query);
        }).toList();
      } else {
        _filteredSupplierDebts = _supplierDebts.where((item) {
          final supplierName = (item['supplierName'] as String).toLowerCase();
          final referenceNo = (item['referenceNo'] as String).toLowerCase();
          return supplierName.contains(query) || referenceNo.contains(query);
        }).toList();
      }
    });
  }

  double get _totalCustomerDebt {
    return _filteredCustomerDebts.fold(0.0, (sum, item) {
      final CustomerDebt debt = item['debt'];
      return sum + debt.amount;
    });
  }

  double get _totalCustomerPaid {
    return _filteredCustomerDebts.fold(0.0, (sum, item) {
      final CustomerDebt debt = item['debt'];
      return sum + debt.paidAmount;
    });
  }

  double get _totalCustomerRemaining => _totalCustomerDebt - _totalCustomerPaid;

  double get _totalSupplierDebt {
    return _filteredSupplierDebts.fold(0.0, (sum, item) {
      final SupplierDebt debt = item['debt'];
      return sum + debt.amount;
    });
  }

  double get _totalSupplierPaid {
    return _filteredSupplierDebts.fold(0.0, (sum, item) {
      final SupplierDebt debt = item['debt'];
      return sum + debt.paidAmount;
    });
  }

  double get _totalSupplierRemaining => _totalSupplierDebt - _totalSupplierPaid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Hutang & Piutang',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Piutang Pelanggan'),
            Tab(text: 'Hutang Supplier'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodFilter(),
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
                _applySearchFilter();
              },
              decoration: InputDecoration(
                hintText: _tabController.index == 0 ? 'Cari nama pelanggan / no. ref...' : 'Cari nama supplier / no. ref...',
                prefixIcon: const Icon(Icons.search, color: AppConstants.textLightColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _applySearchFilter();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppConstants.primaryColor),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerDebtsTab(),
                _buildSupplierDebtsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDebtsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildSummaryHeader(
          total: _totalCustomerDebt,
          paid: _totalCustomerPaid,
          remaining: _totalCustomerRemaining,
          isReceivable: true,
        ),
        Expanded(
          child: _filteredCustomerDebts.isEmpty
              ? _buildEmptyState('Belum ada piutang pelanggan.')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredCustomerDebts.length,
                  itemBuilder: (context, idx) {
                    final item = _filteredCustomerDebts[idx];
                    final CustomerDebt debt = item['debt'];
                    final String customerName = item['customerName'];
                    final String referenceNo = item['referenceNo'];
                    final dateStr = DateFormat('dd MMM yyyy').format(debt.createdAt);
                    final dueStr = debt.dueDate != null ? DateFormat('dd MMM yyyy').format(debt.dueDate!) : '-';

                    return _buildDebtCard(
                      title: customerName,
                      referenceNo: referenceNo,
                      dateStr: dateStr,
                      dueStr: dueStr,
                      total: debt.amount,
                      paid: debt.paidAmount,
                      status: debt.status,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSupplierDebtsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildSummaryHeader(
          total: _totalSupplierDebt,
          paid: _totalSupplierPaid,
          remaining: _totalSupplierRemaining,
          isReceivable: false,
        ),
        Expanded(
          child: _filteredSupplierDebts.isEmpty
              ? _buildEmptyState('Belum ada hutang supplier.')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredSupplierDebts.length,
                  itemBuilder: (context, idx) {
                    final item = _filteredSupplierDebts[idx];
                    final SupplierDebt debt = item['debt'];
                    final String supplierName = item['supplierName'];
                    final String referenceNo = item['referenceNo'];
                    final dateStr = DateFormat('dd MMM yyyy').format(debt.createdAt);
                    final dueStr = debt.dueDate != null ? DateFormat('dd MMM yyyy').format(debt.dueDate!) : '-';

                    return _buildDebtCard(
                      title: supplierName,
                      referenceNo: referenceNo,
                      dateStr: dateStr,
                      dueStr: dueStr,
                      total: debt.amount,
                      paid: debt.paidAmount,
                      status: debt.status,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader({
    required double total,
    required double paid,
    required double remaining,
    required bool isReceivable,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total ${isReceivable ? "Piutang" : "Hutang"}',
                  total,
                  AppConstants.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  'Terbayar',
                  paid,
                  AppConstants.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  'Sisa Saldo',
                  remaining,
                  remaining > 0 ? AppConstants.warningColor : AppConstants.textLightColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(amount),
            style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard({
    required String title,
    required String referenceNo,
    required String dateStr,
    required String dueStr,
    required double total,
    required double paid,
    required String status,
  }) {
    final remaining = total - paid;

    String statusLabel = 'LUNAS';
    Color statusColor = AppConstants.successColor;
    if (status == 'unpaid') {
      statusLabel = 'BELUM LUNAS';
      statusColor = AppConstants.errorColor;
    } else if (status == 'partial') {
      statusLabel = 'BAYAR SEBAGIAN';
      statusColor = AppConstants.warningColor;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppConstants.borderLightColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.textDarkColor),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.poppins(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'No. Ref: $referenceNo',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                ),
                Text(
                  'Tgl Tempo: $dueStr',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Tagihan', style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor)),
                    Text(CurrencyFormatter.format(total), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Terbayar', style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor)),
                    Text(CurrencyFormatter.format(paid), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.successColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Sisa Saldo', style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor)),
                    Text(
                      CurrencyFormatter.format(remaining),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: remaining > 0 ? AppConstants.errorColor : AppConstants.textDarkColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periode Laporan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppConstants.textLightColor,
                ),
              ),
              Text(
                '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Kustom'].map((range) {
              final isSelected = _selectedRange == range;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () async {
                      if (range == 'Kustom') {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(
                            start: _startDate,
                            end: _endDate,
                          ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
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
                            _selectedRange = 'Kustom';
                            _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
                            _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                          });
                          _loadData();
                        }
                      } else {
                        setState(() {
                          _selectedRange = range;
                        });
                        _updateDateRange();
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.primaryColor : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppConstants.primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          range,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppConstants.textDarkColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
