import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/data/user_repository.dart';
import '../bloc/reports_cubit.dart';

class ShiftReportPage extends StatefulWidget {
  const ShiftReportPage({super.key});

  @override
  State<ShiftReportPage> createState() => _ShiftReportPageState();
}

class _ShiftReportPageState extends State<ShiftReportPage> {
  final UserRepository _userRepository = getIt<UserRepository>();
  List<User> _cashiers = [];
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedCashierId;

  @override
  void initState() {
    super.initState();
    context.read<ReportsCubit>().loadShifts();
    _loadCashiers();
  }

  Future<void> _loadCashiers() async {
    try {
      final list = await _userRepository.getUsers();
      setState(() {
        _cashiers = list;
      });
    } catch (_) {}
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Shift Kasir',
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
          if (state.isShiftsLoading && state.shiftsData == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.shiftsData != null) {
            final allShifts = state.shiftsData!;
            final filteredShifts = allShifts.where((row) {
              final CashierSession session = row['session'];

              if (_selectedCashierId != null && session.userId != _selectedCashierId) {
                return false;
              }

              final compareDate = session.closeTime ?? session.openTime;
              if (_startDate != null) {
                final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
                if (compareDate.isBefore(start)) return false;
              }
              if (_endDate != null) {
                final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
                if (compareDate.isAfter(end)) return false;
              }

              return true;
            }).toList();

            return Column(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    side: const BorderSide(color: AppConstants.borderLightColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selectDateRange,
                                icon: const Icon(Icons.date_range_rounded, size: 16),
                                label: Text(
                                  _startDate == null || _endDate == null
                                      ? 'Pilih Periode'
                                      : '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppConstants.textDarkColor,
                                  side: const BorderSide(color: AppConstants.borderLightColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                  ),
                                ),
                              ),
                            ),
                            if (_startDate != null || _endDate != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, color: AppConstants.errorColor),
                                onPressed: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            border: Border.all(color: AppConstants.borderLightColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedCashierId,
                              isExpanded: true,
                              hint: const Text('Semua Kasir', style: TextStyle(fontSize: 12)),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Semua Kasir', style: TextStyle(fontSize: 12)),
                                ),
                                ..._cashiers.map((u) => DropdownMenuItem<int?>(
                                      value: u.id,
                                      child: Text(u.name, style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedCashierId = val;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filteredShifts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 54, color: AppConstants.textLightColor.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada shift yang cocok dengan filter.',
                                style: GoogleFonts.poppins(color: AppConstants.textLightColor, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredShifts.length,
                          itemBuilder: (context, index) {
                            final row = filteredShifts[index];
                final CashierSession session = row['session'];
                final String cashierName = row['cashierName'];

                final Map<String, dynamic> paymentDetails = row['paymentDetails'] ?? {};
                final Map<String, dynamic> cashSources = row['cashSources'] ?? {};

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
                        const Divider(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.backgroundColor,
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rincian Penjualan per Metode Pembayaran:',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor),
                              ),
                              const SizedBox(height: 6),
                              _buildDetailRow('Tunai (Cash)', paymentDetails['cash'] ?? 0.0),
                              _buildDetailRow('QRIS', paymentDetails['qris'] ?? 0.0),
                              _buildDetailRow('EDC / Kartu', paymentDetails['card'] ?? 0.0),
                              _buildDetailRow('Transfer', paymentDetails['transfer'] ?? 0.0),
                              const Divider(height: 16),
                              Text(
                                'Sumber Aliran Kas Laci:',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor),
                              ),
                              const SizedBox(height: 6),
                              _buildDetailRow('Modal Kas Awal (+)', cashSources['opening'] ?? 0.0),
                              _buildDetailRow('Penjualan Tunai (+)', cashSources['sales'] ?? 0.0),
                              _buildDetailRow('Penerimaan Piutang Tunai (+)', cashSources['debts'] ?? 0.0),
                              _buildDetailRow('Pengeluaran Toko Tunai (-)', cashSources['expenses'] ?? 0.0, isNegative: true),
                              _buildDetailRow('Pembayaran Hutang Tunai (-)', cashSources['supplierDebts'] ?? 0.0, isNegative: true),
                              _buildDetailRow('Retur Penjualan Tunai (-)', cashSources['salesReturns'] ?? 0.0, isNegative: true),
                              _buildDetailRow('Retur Pembelian Tunai (+)', cashSources['purchaseReturns'] ?? 0.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
          }

          return const Center(child: Text('Gagal memuat data.'));
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, {bool isNegative = false}) {
    final formatted = CurrencyFormatter.format(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor)),
          Text(
            isNegative && amount > 0 ? '- $formatted' : formatted,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isNegative && amount > 0 ? AppConstants.errorColor : AppConstants.textDarkColor,
            ),
          ),
        ],
      ),
    );
  }
}
