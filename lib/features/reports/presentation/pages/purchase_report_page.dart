import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/reports_cubit.dart';

class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateDateRange();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<ReportsCubit>().loadPurchasesReports(_startDate, _endDate);
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

  Widget _buildSummaryCards(double totalReceived, double totalPending, int txCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.successColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.successColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diterima (Received)',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.successColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalReceived),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.successColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tertunda (Pending)',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalPending),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab(List<Map<String, dynamic>> txList) {
    if (txList.isEmpty) {
      return _buildEmptyState('Belum ada transaksi pembelian di periode ini.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: txList.length,
      itemBuilder: (context, index) {
        final item = txList[index];
        final Purchase purchase = item['purchase'];
        final String supplierName = item['supplierName'];
        final isReceived = purchase.status == 'received';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isReceived ? AppConstants.successColor : Colors.orange).withValues(alpha: 0.08),
                  child: Icon(
                    isReceived ? Icons.assignment_turned_in_rounded : Icons.pending_actions_rounded,
                    color: isReceived ? AppConstants.successColor : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.referenceNo,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Supplier: $supplierName',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt),
                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(purchase.grandTotal),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isReceived ? AppConstants.successColor : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isReceived ? 'DITERIMA' : 'PENDING',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isReceived ? AppConstants.successColor : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsTab(List<Map<String, dynamic>> prodList) {
    if (prodList.isEmpty) {
      return _buildEmptyState('Belum ada data barang dibeli pada periode ini.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: prodList.length,
      itemBuilder: (context, index) {
        final stats = prodList[index];
        final String productName = stats['productName'];
        final String unitName = stats['unitName'];
        final double quantity = stats['quantity'];
        final double totalCost = stats['totalCost'];

        final qtyStr = quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.08),
                  child: const Icon(Icons.shopping_bag_outlined, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Kuantitas: $qtyStr $unitName',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(totalCost),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Pembelian',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          final txList = state.purchaseTransactionsData ?? [];
          final prodList = state.productPurchasesData ?? [];

          // Compute received vs pending sum
          double totalReceived = 0.0;
          double totalPending = 0.0;
          for (var item in txList) {
            final Purchase p = item['purchase'];
            if (p.status == 'received') {
              totalReceived += p.grandTotal;
            } else {
              totalPending += p.grandTotal;
            }
          }

          return Column(
            children: [
              _buildPeriodFilter(),
              _buildSummaryCards(totalReceived, totalPending, txList.length),
              const SizedBox(height: 6),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppConstants.primaryColor,
                  unselectedLabelColor: AppConstants.textLightColor,
                  indicatorColor: AppConstants.primaryColor,
                  labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                  tabs: const [
                    Tab(text: 'Daftar Transaksi'),
                    Tab(text: 'Per Produk'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppConstants.borderLightColor),
              Expanded(
                child: state.isPurchasesLoading && state.purchaseTransactionsData == null
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTransactionsTab(txList),
                          _buildProductsTab(prodList),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
