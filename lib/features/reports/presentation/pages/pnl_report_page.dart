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
import '../bloc/reports_cubit.dart';

class PnlReportPage extends StatefulWidget {
  const PnlReportPage({super.key});

  @override
  State<PnlReportPage> createState() => _PnlReportPageState();
}

class _PnlReportPageState extends State<PnlReportPage> {
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    context.read<ReportsCubit>().loadPnL(_startDate, _endDate);
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

  Future<void> _exportPnLToPdf(Map<String, dynamic> pnl) async {
    final pdf = pw.Document();

    final double grossSales = pnl['grossSales'] ?? 0.0;
    final double discount = pnl['discount'] ?? 0.0;
    final double tax = pnl['tax'] ?? 0.0;
    final double netSales = pnl['netSales'] ?? 0.0;
    final double hpp = pnl['hpp'] ?? 0.0;
    final double grossProfit = pnl['grossProfit'] ?? 0.0;
    final double expenses = pnl['expenses'] ?? 0.0;
    final double netProfit = pnl['netProfit'] ?? 0.0;

    final dateRangeStr = "${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('GawePOS', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                        pw.Text('Laporan Keuangan Laba Rugi', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Periode Laporan:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        pw.Text(dateRangeStr, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.indigo, height: 30),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                  children: [
                    _buildPdfRow('Penjualan Kotor (Gross)', CurrencyFormatter.format(grossSales)),
                    _buildPdfRow('Total Diskon (-)', '- ${CurrencyFormatter.format(discount)}', color: PdfColors.red700),
                    _buildPdfRow('Total Pajak (+)', CurrencyFormatter.format(tax)),
                    _buildPdfRow('Total Penjualan Bersih (Net)', CurrencyFormatter.format(netSales), isBold: true),
                    _buildPdfRow('Harga Pokok Penjualan (HPP) (-)', '- ${CurrencyFormatter.format(hpp)}', color: PdfColors.red700),
                    _buildPdfRow('Profit Kotor (Gross Margin)', CurrencyFormatter.format(grossProfit), isBold: true, color: PdfColors.indigo),
                    _buildPdfRow('Biaya Operasional Cashier (-)', '- ${CurrencyFormatter.format(expenses)}', color: PdfColors.red700),
                    _buildPdfRow('Profit Bersih (Net Profit)', CurrencyFormatter.format(netProfit), isBold: true, color: netProfit >= 0 ? PdfColors.green700 : PdfColors.red700),
                  ],
                ),
                pw.Spacer(),
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Dicetak secara otomatis oleh sistem GawePOS.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()), style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Laporan_Laba_Rugi_${_selectedRange.replaceAll(' ', '_')}.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Laba Rugi POS Mobile periode $dateRangeStr');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor PDF: $e'), backgroundColor: AppConstants.errorColor),
      );
    }
  }

  pw.TableRow _buildPdfRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ),
      ],
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
              'Laporan Laba Rugi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Analisis pendapatan, HPP & margin bersih',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<ReportsCubit, ReportsState>(
            builder: (context, state) {
              if (state.pnlData == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined, color: Color(0xFF0F172A), size: 20),
                tooltip: 'Bagikan PDF',
                onPressed: () => _exportPnLToPdf(state.pnlData!),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          return Column(
            children: [
              _buildPeriodFilter(() {
                context.read<ReportsCubit>().loadPnL(_startDate, _endDate);
              }),
              if (state.isPnLLoading && state.pnlData == null)
                const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))))
              else if (state.pnlData != null) ...[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        // Hero Net Profit Card
                        _buildHeroProfitCard(state.pnlData!),
                        const SizedBox(height: 16),

                        // Card Rincian
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rincian Pendapatan & Beban',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Kalkulasi omzet, modal dan pengeluaran',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 28, color: Color(0xFFE2E8F0)),
                              _buildPnLItemRow('Penjualan Kotor (Gross)', state.pnlData!['grossSales'] ?? 0.0),
                              _buildPnLItemRow('Total Diskon (-)', -(state.pnlData!['discount'] ?? 0.0), isNegative: true),
                              _buildPnLItemRow('Total Pajak (+)', state.pnlData!['tax'] ?? 0.0),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _buildPnLItemRow('Penjualan Bersih (Net Sales)', state.pnlData!['netSales'] ?? 0.0, isBold: true),
                              _buildPnLItemRow('Harga Pokok Penjualan (HPP) (-)', -(state.pnlData!['hpp'] ?? 0.0), isNegative: true),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _buildPnLItemRow('Profit Kotor (Gross Margin)', state.pnlData!['grossProfit'] ?? 0.0, isBold: true, color: const Color(0xFF0F172A)),
                              _buildPnLItemRow('Biaya Operasional Kasir (-)', -(state.pnlData!['expenses'] ?? 0.0), isNegative: true),
                              const Divider(height: 24, color: Color(0xFFE2E8F0)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildPnLItemRow(
                                  'Profit Bersih (Net Income)',
                                  state.pnlData!['netProfit'] ?? 0.0,
                                  isBold: true,
                                  color: (state.pnlData!['netProfit'] ?? 0.0) >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Export Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: Text(
                              'EKSPOR LAPORAN (PDF)',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: () => _exportPnLToPdf(state.pnlData!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                const Expanded(child: Center(child: Text('Gagal memuat data.'))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroProfitCard(Map<String, dynamic> pnl) {
    final double netProfit = pnl['netProfit'] ?? 0.0;
    final double netSales = pnl['netSales'] ?? 0.0;
    final double marginPct = netSales > 0 ? (netProfit / netSales) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                'PROFIT BERSIH (NET PROFIT)',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      netProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: netProfit >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${marginPct.toStringAsFixed(1)}% Margin',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: netProfit >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(netProfit),
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeroSubItem('Omzet Bersih', CurrencyFormatter.format(netSales)),
                Container(height: 24, width: 1, color: Colors.white.withValues(alpha: 0.15)),
                _buildHeroSubItem('Profit Kotor', CurrencyFormatter.format(pnl['grossProfit'] ?? 0.0)),
                Container(height: 24, width: 1, color: Colors.white.withValues(alpha: 0.15)),
                _buildHeroSubItem('Beban Kasir', CurrencyFormatter.format(pnl['expenses'] ?? 0.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPnLItemRow(String label, double amount, {bool isBold = false, bool isNegative = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppConstants.textDarkColor : AppConstants.textLightColor,
            ),
          ),
          Text(
            amount == 0 && isNegative ? 'Rp 0' : CurrencyFormatter.format(amount),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isNegative ? AppConstants.errorColor : AppConstants.textDarkColor),
            ),
          ),
        ],
      ),
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
}
