import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/reports_cubit.dart';

class ExpensesReportPage extends StatefulWidget {
  const ExpensesReportPage({super.key});

  @override
  State<ExpensesReportPage> createState() => _ExpensesReportPageState();
}

class _ExpensesReportPageState extends State<ExpensesReportPage> {
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    context.read<ReportsCubit>().loadExpensesReport(_startDate, _endDate);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Biaya',
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
          final expenses = state.expensesData ?? [];
          final double totalExpenses = expenses.fold(0.0, (sum, exp) => sum + exp.amount);

          return Column(
            children: [
              _buildPeriodFilter(() {
                context.read<ReportsCubit>().loadExpensesReport(_startDate, _endDate);
              }),
              if (state.isExpensesLoading && state.expensesData == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else ...[
                // Summary card for expenses
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppConstants.errorColor, AppConstants.errorColor.withValues(alpha: 0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.errorColor.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pengeluaran / Biaya',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          CurrencyFormatter.format(totalExpenses),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: expenses.isEmpty
                      ? _buildEmptyState('Belum ada catatan biaya di periode ini.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: expenses.length,
                          itemBuilder: (context, index) {
                            final exp = expenses[index];
                            final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(exp.date);

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
                                      backgroundColor: AppConstants.errorColor.withValues(alpha: 0.08),
                                      child: const Icon(Icons.outbox_rounded, color: AppConstants.errorColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            exp.categoryName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppConstants.textDarkColor,
                                            ),
                                          ),
                                          if (exp.description != null && exp.description!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              exp.description!,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: AppConstants.textLightColor,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            dateStr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(exp.amount),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.errorColor,
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
            ],
          );
        },
      ),
    );
  }
}
