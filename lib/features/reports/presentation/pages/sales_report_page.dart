import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
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

  Future<void> _exportToPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final state = context.read<ReportsCubit>().state;
      final pdf = pw.Document();
      final dateRangeStr =
          '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}';

      final transactions = state.transactionsData ?? [];
      final products = state.productSalesData ?? [];
      final customers = state.customerSalesData ?? [];

      final double totalSales = transactions.fold(0.0, (sum, tx) => sum + (tx['order'] as Order).grandTotal);
      final int totalTx = transactions.length;
      final double totalProfit = products.fold(0.0, (sum, prod) => sum + (prod['profit'] as double? ?? 0.0));

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('GawePOS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                pw.Text('Laporan Penjualan', style: pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                pw.Divider(thickness: 1.5, color: PdfColors.indigo),
                pw.SizedBox(height: 8),
                pw.Text('Periode: $dateRangeStr', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    border: pw.Border.all(color: PdfColors.indigo200),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _pdfSummaryItem('Total Omzet', CurrencyFormatter.format(totalSales)),
                      _pdfSummaryItem('Transaksi', '$totalTx'),
                      _pdfSummaryItem('Total Profit', CurrencyFormatter.format(totalProfit)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                if (_salesSubTab == 'Transaksi') ..._buildTransactionPdfTable(transactions),
                if (_salesSubTab == 'Produk') ..._buildProductPdfTable(products),
                if (_salesSubTab == 'Pelanggan') ..._buildCustomerPdfTable(customers),
              ],
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final fileName =
          'Penjualan_${_salesSubTab}_${DateFormat('yyyyMMdd').format(_startDate)}-${DateFormat('yyyyMMdd').format(_endDate)}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) Navigator.of(context).pop();

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Penjualan GawePOS - $dateRangeStr',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor: $e'), backgroundColor: AppConstants.errorColor),
        );
      }
    }
  }

  pw.Widget _pdfSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
      ],
    );
  }

  List<pw.Widget> _buildTransactionPdfTable(List<Map<String, dynamic>> transactionList) {
    double totalGrand = 0, totalSub = 0, totalDisc = 0, totalTax = 0;
    final tableRows = <pw.TableRow>[];

    tableRows.add(_pdfThRow(
      ['No. Nota', 'Tanggal', 'Pelanggan', 'Bayar', 'Produk', 'Qty', 'Harga', 'Subtotal'],
    ));

    for (int i = 0; i < transactionList.length; i++) {
      final tx = transactionList[i];
      final order = tx['order'] as Order;
      final customer = tx['customerName'] ?? 'Umum';
      final payment = tx['paymentMethods'] ?? '-';
      final date = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
      final items = tx['items'] as List<Map<String, dynamic>>? ?? [];

      totalSub += order.subtotal;
      totalDisc += order.discountAmount;
      totalTax += order.taxAmount;
      totalGrand += order.grandTotal;

      if (items.isEmpty) {
        tableRows.add(_pdfTdRow([order.referenceNo, date, customer, payment, '-', '', '', CurrencyFormatter.format(order.grandTotal)]));
      } else {
        final first = items.first;
        tableRows.add(_pdfTdRow([
          order.referenceNo, date, customer, payment,
          first['productName'] ?? '-',
          (first['quantity'] as num).toStringAsFixed(0),
          CurrencyFormatter.format((first['price'] as num).toDouble()),
          CurrencyFormatter.format((first['subtotal'] as num).toDouble()),
        ]));

        for (int j = 1; j < items.length; j++) {
          final item = items[j];
          tableRows.add(_pdfTdRow([
            '', '', '', '',
            item['productName'] ?? '-',
            (item['quantity'] as num).toStringAsFixed(0),
            CurrencyFormatter.format((item['price'] as num).toDouble()),
            CurrencyFormatter.format((item['subtotal'] as num).toDouble()),
          ]));
        }

        tableRows.add(_pdfTdRow([
          '', '', '', '',
          'Diskon: ${CurrencyFormatter.format(order.discountAmount)}',
          'Pajak: ${CurrencyFormatter.format(order.taxAmount)}',
          '',
          CurrencyFormatter.format(order.grandTotal),
        ], isSummary: true));
      }
    }

    return [
      pw.Header(level: 1, text: 'Daftar Transaksi'),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(70),
          1: const pw.FixedColumnWidth(70),
          2: const pw.FixedColumnWidth(60),
          3: const pw.FixedColumnWidth(45),
          4: const pw.FlexColumnWidth(3),
          5: const pw.FixedColumnWidth(35),
          6: const pw.FixedColumnWidth(55),
          7: const pw.FixedColumnWidth(60),
        },
        children: tableRows,
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(color: PdfColors.indigo50, border: pw.Border.all(color: PdfColors.indigo200)),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL KESELURUHAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
            pw.Text('${CurrencyFormatter.format(totalSub)}  |  Disc: ${CurrencyFormatter.format(totalDisc)}  |  Pajak: ${CurrencyFormatter.format(totalTax)}  |  ${CurrencyFormatter.format(totalGrand)}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
          ],
        ),
      ),
    ];
  }

  pw.TableRow _pdfThRow(List<String> cells) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.indigo700),
      children: cells.map((c) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(c, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
        );
      }).toList(),
    );
  }

  pw.TableRow _pdfTdRow(List<String> cells, {bool isSummary = false}) {
    final style = pw.TextStyle(
      fontSize: isSummary ? 6.5 : 6,
      fontWeight: isSummary ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isSummary ? PdfColors.indigo700 : PdfColors.black,
    );
    return pw.TableRow(
      decoration: isSummary ? pw.BoxDecoration(color: PdfColors.indigo50) : null,
      children: cells.map((c) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(c, style: style, textAlign: c.isEmpty ? pw.TextAlign.center : pw.TextAlign.center),
        );
      }).toList(),
    );
  }

  List<pw.Widget> _buildProductPdfTable(List<Map<String, dynamic>> productList) {
    double totalRev = 0, totalCost = 0, totalProfit = 0;

    return [
      pw.Header(level: 1, text: 'Penjualan per Produk'),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(120),
          1: const pw.FixedColumnWidth(50),
          2: const pw.FixedColumnWidth(70),
          3: const pw.FixedColumnWidth(70),
          4: const pw.FixedColumnWidth(70),
          5: const pw.FixedColumnWidth(70),
        },
        children: [
          _pdfTableRow(
            ['Nama Produk', 'Satuan', 'Jumlah Terjual', 'Penjualan', 'HPP', 'Profit'],
            isHeader: true,
          ),
          ...productList.map((p) {
            final name = p['productName'] ?? '-';
            final unit = p['unitName'] ?? '';
            final qty = (p['quantity'] as num).toStringAsFixed(0);
            final rev = (p['revenue'] as num);
            final cost = (p['cost'] as num?) ?? 0;
            final profit = (p['profit'] as num);

            totalRev += rev.toDouble();
            totalCost += cost.toDouble();
            totalProfit += profit.toDouble();

            return _pdfTableRow([
              name, unit, qty,
              CurrencyFormatter.format(rev.toDouble()),
              CurrencyFormatter.format(cost.toDouble()),
              CurrencyFormatter.format(profit.toDouble()),
            ]);
          }),
          _pdfTableRow(
            ['TOTAL', '', '',
             CurrencyFormatter.format(totalRev),
             CurrencyFormatter.format(totalCost),
             CurrencyFormatter.format(totalProfit)],
            isTotal: true,
          ),
        ],
      ),
    ];
  }

  List<pw.Widget> _buildCustomerPdfTable(List<Map<String, dynamic>> customerList) {
    int totalTxCount = 0;
    double totalSpent = 0;

    return [
      pw.Header(level: 1, text: 'Penjualan per Pelanggan'),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(200),
          1: const pw.FixedColumnWidth(100),
          2: const pw.FixedColumnWidth(150),
        },
        children: [
          _pdfTableRow(
            ['Nama Pelanggan', 'Jumlah Transaksi', 'Total Belanja'],
            isHeader: true,
          ),
          ...customerList.map((c) {
            final name = c['customerName'] ?? 'Umum';
            final count = c['transactionCount'] ?? 0;
            final spent = (c['totalSpent'] as num);

            totalTxCount += (c['transactionCount'] as int);
            totalSpent += spent.toDouble();

            return _pdfTableRow([
              name, '$count', CurrencyFormatter.format(spent.toDouble()),
            ]);
          }),
          _pdfTableRow(
            ['TOTAL', '$totalTxCount', CurrencyFormatter.format(totalSpent)],
            isTotal: true,
          ),
        ],
      ),
    ];
  }

  pw.TableRow _pdfTableRow(List<String> cells, {bool isHeader = false, bool isTotal = false}) {
    final style = pw.TextStyle(
      fontSize: isHeader ? 8 : (isTotal ? 8 : 7),
      fontWeight: isHeader || isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isHeader ? PdfColors.white : PdfColors.black,
    );
    final bg = isHeader ? PdfColors.indigo700 : (isTotal ? PdfColors.indigo50 : null);

    return pw.TableRow(
      decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
      children: cells.map((cell) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(cell, style: style, textAlign: pw.TextAlign.center),
        );
      }).toList(),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportToPdf(),
          ),
        ],
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
