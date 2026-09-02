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
              'Hutang & Piutang',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Monitoring tagihan customer & kewajiban supplier',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodFilter(),
          // Modern Segmented Tab Bar & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5),
                    unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12.5),
                    tabs: const [
                      Tab(text: 'Piutang Pelanggan'),
                      Tab(text: 'Hutang Supplier'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                    _applySearchFilter();
                  },
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: _tabController.index == 0 ? 'Cari nama pelanggan / no. ref...' : 'Cari nama supplier / no. ref...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _applySearchFilter();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
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
              ? _buildEmptyState('Belum ada data piutang pelanggan.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
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
              ? _buildEmptyState('Belum ada data hutang supplier.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              'Total ${isReceivable ? "Piutang" : "Hutang"}',
              total,
              const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItem(
              'Terbayar',
              paid,
              const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItem(
              'Sisa Saldo',
              remaining,
              remaining > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            CurrencyFormatter.format(amount),
            style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w700),
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
    Color statusColor = const Color(0xFF059669);
    if (status == 'unpaid') {
      statusLabel = 'BELUM LUNAS';
      statusColor = const Color(0xFFDC2626);
    } else if (status == 'partial') {
      statusLabel = 'BAYAR SEBAGIAN';
      statusColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5, color: const Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.poppins(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w700),
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
                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              Text(
                'Jatuh Tempo: $dueStr',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Tagihan', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(CurrencyFormatter.format(total), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terbayar', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(CurrencyFormatter.format(paid), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sisa Saldo', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(remaining),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: remaining > 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periode Laporan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Kustom'].map((range) {
              final isSelected = _selectedRange == range;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          range,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
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
