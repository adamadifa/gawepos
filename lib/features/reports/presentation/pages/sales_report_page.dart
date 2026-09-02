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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.15),
              blurRadius: 12,
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
                  'REKAPITULASI PENJUALAN',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalTx Transaksi',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(totalSales),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Estimasi Profit',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(totalProfit),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF34D399),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final tx = transactions[index];
          final Order order = tx['order'];
          final String customerName = tx['customerName'];
          final String paymentMethods = tx['paymentMethods'];
          final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt);

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
                    Text(
                      order.referenceNo,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(order.grandTotal),
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
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
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        paymentMethods,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Text(
                  dateStr,
                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                ),
              ],
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final stats = products[index];
          final String prodName = stats['productName'];
          final String unitName = stats['unitName'];
          final double qty = stats['quantity'];
          final double revenue = stats['revenue'];
          final double profit = stats['profit'];

          final qtyStr = qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

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
                Text(
                  prodName,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jumlah Terjual: $qtyStr $unitName',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    Text(
                      CurrencyFormatter.format(revenue),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: profit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final cust = customers[index];
          final String customerName = cust['customerName'];
          final int txCount = cust['transactionCount'];
          final double totalSpent = cust['totalSpent'];

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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Color(0xFF0F172A), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$txCount Transaksi',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(totalSpent),
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
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

  Widget _buildPeriodFilter(VoidCallback onDateRangeChanged) {
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
              'Laporan Penjualan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Rekap transaksi kasir, omzet & produk',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0F172A), size: 20),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: ['Transaksi', 'Produk', 'Pelanggan'].map((subTab) {
                      final isSelected = _salesSubTab == subTab;
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _salesSubTab = subTab;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                subTab,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
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
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              if (state.isSalesLoading && state.transactionsData == null)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))))
              else if (state.salesError != null && state.transactionsData == null)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 40, color: const Color(0xFFDC2626)),
                          const SizedBox(height: 12),
                          Text(
                            state.salesError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              context.read<ReportsCubit>().loadSalesReports(_startDate, _endDate);
                            },
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
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
