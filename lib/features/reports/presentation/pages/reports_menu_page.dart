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
import 'owner_dashboard_page.dart';

class ReportsMenuPage extends StatefulWidget {
  const ReportsMenuPage({super.key});

  @override
  State<ReportsMenuPage> createState() => _ReportsMenuPageState();
}

class _ReportsMenuPageState extends State<ReportsMenuPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // P&L State variables
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _updateDateRange();
    context.read<ReportsCubit>().loadPnL(_startDate, _endDate);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      context.read<ReportsCubit>().loadPnL(_startDate, _endDate);
    } else {
      context.read<ReportsCubit>().loadShifts();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                // Header
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

                // Table P&L items
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

      // Share PDF using share_plus
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
          'Laporan Keuangan',
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
          unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Laba Rugi'),
            Tab(text: 'Shift Kasir'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPnLTab(),
          _buildShiftsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OwnerDashboardPage()),
          );
        },
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
        label: Text(
          'DASHBOARD OWNER',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPnLTab() {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        return Column(
          children: [
            // Date Filter selector (Redesigned & Modernized)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERIODE LAPORAN',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppConstants.textLightColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini'].map((range) {
                      final isSelected = _selectedRange == range;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedRange = range;
                              });
                              _updateDateRange();
                              context.read<ReportsCubit>().loadPnL(_startDate, _endDate);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                                          color: AppConstants.primaryColor.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  range,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
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
            ),

            if (state.isPnLLoading && state.pnlData == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (state.pnlData != null) ...[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Calculation Breakdown Card
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
                      // Share Button
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

  Widget _buildShiftsTab() {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        if (state.isShiftsLoading && state.shiftsData == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.shiftsData != null) {
          final list = state.shiftsData!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 54, color: AppConstants.textLightColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat shift yang ditutup.',
                    style: GoogleFonts.poppins(color: AppConstants.textLightColor, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final row = list[index];
              final CashierSession session = row['session'];
              final String cashierName = row['cashierName'];

              final openStr = DateFormat('dd MMM yyyy, HH:mm').format(session.openTime);
              final closeStr = session.closeTime != null ? DateFormat('HH:mm').format(session.closeTime!) : '-';

              final double expected = session.expectedCash ?? 0.0;
              final double actual = session.closingCash ?? 0.0;
              final double diff = actual - expected;

              Color diffColor = AppConstants.textLightColor;
              String diffText = 'Sesuai';
              if (diff > 0) {
                diffColor = AppConstants.successColor;
                diffText = 'Surplus (+${CurrencyFormatter.format(diff)})';
              } else if (diff < 0) {
                diffColor = AppConstants.errorColor;
                diffText = 'Selisih / Minus (${CurrencyFormatter.format(diff)})';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cashierName,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppConstants.textDarkColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: diffColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              diffText,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: diffColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Shift: $openStr - $closeStr',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kas Awal', style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor)),
                                Text(CurrencyFormatter.format(session.openingCash), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textDarkColor)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ekspektasi Kas', style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor)),
                                Text(CurrencyFormatter.format(expected), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textDarkColor)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kas Aktual', style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor)),
                                Text(CurrencyFormatter.format(actual), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textDarkColor)),
                              ],
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

        return const Center(child: Text('Gagal memuat data.'));
      },
    );
  }
}
