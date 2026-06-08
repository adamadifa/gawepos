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
                        pw.Text('WarungPro', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
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
                    pw.Text('Dicetak secara otomatis oleh sistem WarungPro.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
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
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Laba Rugi',
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
                context.read<ReportsCubit>().loadPnL(_startDate, _endDate);
              }),
              if (state.isPnLLoading && state.pnlData == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (state.pnlData != null) ...[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            side: const BorderSide(color: AppConstants.borderLightColor),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rincian Pendapatan & Beban',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppConstants.textDarkColor,
                                  ),
                                ),
                                const Divider(height: 24),
                                _buildPnLItemRow('Penjualan Kotor', state.pnlData!['grossSales'] ?? 0.0),
                                _buildPnLItemRow('Total Diskon (-)', -(state.pnlData!['discount'] ?? 0.0), isNegative: true),
                                _buildPnLItemRow('Total Pajak (+)', state.pnlData!['tax'] ?? 0.0),
                                _buildPnLItemRow('Penjualan Bersih (Net)', state.pnlData!['netSales'] ?? 0.0, isBold: true),
                                _buildPnLItemRow('Harga Pokok Penjualan (HPP) (-)', -(state.pnlData!['hpp'] ?? 0.0), isNegative: true),
                                _buildPnLItemRow('Profit Kotor (Gross Profit)', state.pnlData!['grossProfit'] ?? 0.0, isBold: true, color: AppConstants.primaryColor),
                                _buildPnLItemRow('Biaya Operasional Kasir (-)', -(state.pnlData!['expenses'] ?? 0.0), isNegative: true),
                                const Divider(height: 24),
                                _buildPnLItemRow(
                                  'Profit Bersih (Net Income)',
                                  state.pnlData!['netProfit'] ?? 0.0,
                                  isBold: true,
                                  color: (state.pnlData!['netProfit'] ?? 0.0) >= 0 ? AppConstants.successColor : AppConstants.errorColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppConstants.primaryColor,
                              side: const BorderSide(color: AppConstants.primaryColor),
                            ),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('BAGIKAN LAPORAN (PDF)'),
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
}
