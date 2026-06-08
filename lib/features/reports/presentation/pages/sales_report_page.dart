import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/reports_cubit.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _salesSubTab = 'Transaksi';

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    context.read<ReportsCubit>().loadSalesReports(_startDate, _endDate);
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

  Widget _buildPeriodFilter(VoidCallback onDateRangeChanged) {
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
                          onDateRangeChanged();
                        }
                      } else {
                        setState(() {
                          _selectedRange = range;
                        });
                        _updateDateRange();
                        onDateRangeChanged();
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

  Widget _buildSalesSummaryCard(ReportsState state) {
    if (state.isSalesLoading || state.transactionsData == null) {
      return const SizedBox.shrink();
    }
    final transactions = state.transactionsData ?? [];
    final products = state.productSalesData ?? [];
    
    final double totalSales = transactions.fold(0.0, (sum, tx) => sum + (tx['order'] as Order).grandTotal);
    final int totalTx = transactions.length;
    final double totalProfit = products.fold(0.0, (sum, prod) => sum + (prod['profit'] as double? ?? 0.0));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.primaryColor.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rekapitulasi Penjualan',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Omzet',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(totalSales),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaksi',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalTx',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Profit',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(totalProfit),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSubTabContent(ReportsState state) {
    if (_salesSubTab == 'Transaksi') {
      final transactions = state.transactionsData ?? [];
      if (transactions.isEmpty) {
        return _buildEmptyState('Belum ada transaksi di periode ini.');
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final tx = transactions[index];
          final Order order = tx['order'];
          final String customerName = tx['customerName'];
          final String paymentMethods = tx['paymentMethods'];
          final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);

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
                      Text(
                        order.referenceNo,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(order.grandTotal),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pelanggan: $customerName',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                      Text(
                        paymentMethods,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.successColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    dateStr,
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_salesSubTab == 'Produk') {
      final products = state.productSalesData ?? [];
      if (products.isEmpty) {
        return _buildEmptyState('Belum ada penjualan produk di periode ini.');
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final stats = products[index];
          final String prodName = stats['productName'];
          final String unitName = stats['unitName'];
          final double qty = stats['quantity'];
          final double revenue = stats['revenue'];
          final double profit = stats['profit'];

          final qtyStr = qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

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
                  Text(
                    prodName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDarkColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Jumlah Terjual: $qtyStr $unitName',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                      Text(
                        'Penjualan: ${CurrencyFormatter.format(revenue)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(),
                      Text(
                        'Profit: ${CurrencyFormatter.format(profit)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: profit >= 0 ? AppConstants.successColor : AppConstants.errorColor,
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
    } else {
      // Pelanggan
      final customers = state.customerSalesData ?? [];
      if (customers.isEmpty) {
        return _buildEmptyState('Belum ada transaksi pelanggan di periode ini.');
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final cust = customers[index];
          final String customerName = cust['customerName'];
          final int txCount = cust['transactionCount'];
          final double totalSpent = cust['totalSpent'];

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
                    child: const Icon(Icons.person_outline_rounded, color: AppConstants.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$txCount Transaksi',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(totalSpent),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Penjualan',
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
          return Column(
            children: [
              _buildPeriodFilter(() {
                context.read<ReportsCubit>().loadSalesReports(_startDate, _endDate);
              }),
              _buildSalesSummaryCard(state),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: ['Transaksi', 'Produk', 'Pelanggan'].map((subTab) {
                    final isSelected = _salesSubTab == subTab;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _salesSubTab = subTab;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppConstants.primaryColor.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                subTab,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppConstants.primaryColor : AppConstants.textLightColor,
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
              if (state.isSalesLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: _buildSalesSubTabContent(state),
                ),
            ],
          );
        },
      ),
    );
  }
}
