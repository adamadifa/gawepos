import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
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
              'Laporan Shift Kasir',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Rekap sesi kasir & pergerakan kas laci',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          if (state.isShiftsLoading && state.shiftsData == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
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
                // Filter Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDateRange,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF0F172A)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _startDate == null || _endDate == null
                                            ? 'Pilih Rentang Tanggal'
                                            : '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: _startDate == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_startDate != null || _endDate != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFFDC2626), size: 20),
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
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _selectedCashierId,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            hint: Text('Semua Kasir', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua Kasir', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                              ),
                              ..._cashiers.map((u) => DropdownMenuItem<int?>(
                                    value: u.id,
                                    child: Text(u.name, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A))),
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
                Expanded(
                  child: filteredShifts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.history_toggle_off_rounded, size: 36, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada shift yang cocok dengan filter.',
                                style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
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
                            final closeStr = session.closeTime != null ? DateFormat('HH:mm').format(session.closeTime!) : 'Aktif';

                            final double expected = session.expectedCash ?? 0.0;
                            final double actual = session.closingCash ?? 0.0;
                            final double diff = actual - expected;

                            Color diffColor = const Color(0xFF64748B);
                            String diffText = 'Sesuai';
                            if (session.closeTime != null) {
                              if (diff > 0) {
                                diffColor = const Color(0xFF059669);
                                diffText = 'Surplus (+${CurrencyFormatter.format(diff)})';
                              } else if (diff < 0) {
                                diffColor = const Color(0xFFDC2626);
                                diffText = 'Selisih (${CurrencyFormatter.format(diff)})';
                              }
                            } else {
                              diffColor = const Color(0xFFD97706);
                              diffText = 'Sedang Berjalan';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              cashierName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: diffColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            diffText,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: diffColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Waktu: $openStr s/d $closeStr',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Kas Awal', style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B))),
                                              const SizedBox(height: 2),
                                              Text(CurrencyFormatter.format(session.openingCash), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Ekspektasi Kas', style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B))),
                                              const SizedBox(height: 2),
                                              Text(CurrencyFormatter.format(expected), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Kas Aktual', style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B))),
                                              const SizedBox(height: 2),
                                              Text(session.closingCash != null ? CurrencyFormatter.format(actual) : '-', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Penjualan per Metode Pembayaran:',
                                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildDetailRow('Tunai (Cash)', paymentDetails['cash'] ?? 0.0),
                                          _buildDetailRow('QRIS', paymentDetails['qris'] ?? 0.0),
                                          _buildDetailRow('EDC / Kartu', paymentDetails['card'] ?? 0.0),
                                          _buildDetailRow('Transfer', paymentDetails['transfer'] ?? 0.0),
                                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                                          Text(
                                            'Sumber Aliran Kas Laci:',
                                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B))),
          Text(
            isNegative && amount > 0 ? '- $formatted' : formatted,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isNegative && amount > 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

