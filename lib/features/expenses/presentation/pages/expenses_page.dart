import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/expenses_cubit.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Beban Operasional';

  final List<String> _categories = [
    'Beban Operasional',
    'Beban Gaji',
    'Beban Sewa',
    'Beban Listrik & Air',
    'Beban Transportasi',
    'Lain-lain',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showAddExpenseModal(BuildContext context) {
    _amountController.clear();
    _descController.clear();
    _selectedCategory = 'Beban Operasional';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedAmount = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double? amount = double.tryParse(_amountController.text);
            final isAmountValid = amount != null && amount > 0;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Catat Pengeluaran Kasir',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textDarkColor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Dropdown Category
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Pengeluaran *',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat, style: GoogleFonts.poppins(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Amount Input
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Jumlah (Rp) *',
                          prefixText: 'Rp ',
                          errorText: (hasInteractedAmount && !isAmountValid)
                              ? 'Masukkan jumlah nominal yang valid (> 0)'
                              : null,
                        ),
                        onChanged: (_) {
                          setModalState(() {
                            hasInteractedAmount = true;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Description Notes
                      TextField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan / Catatan',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 24),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isAmountValid
                              ? () {
                                  context.read<ExpensesCubit>().addExpense(
                                        categoryName: _selectedCategory,
                                        amount: amount,
                                        description: _descController.text.trim().isEmpty
                                            ? null
                                            : _descController.text.trim(),
                                      );
                                  Navigator.pop(ctx);
                                }
                              : null,
                          child: const Text('SIMPAN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hapus Catatan Pengeluaran',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus catatan biaya "${expense.categoryName}" senilai ${CurrencyFormatter.format(expense.amount)}?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            onPressed: () {
              context.read<ExpensesCubit>().deleteExpense(expense.id);
              Navigator.pop(ctx);
            },
            child: const Text('HAPUS'),
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
          'Biaya & Pengeluaran',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textDarkColor,
      ),
      body: BlocConsumer<ExpensesCubit, ExpensesState>(
        listener: (context, state) {
          if (state is ExpensesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppConstants.errorColor),
            );
          }
        },
        builder: (context, state) {
          if (state is ExpensesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ExpensesLoaded) {
            final list = state.expenses;
            final totalAmount = list.fold<double>(0, (sum, item) => sum + item.amount);

            return Column(
              children: [
                // Summary Total Card (Premium Design)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppConstants.primaryColor, AppConstants.primaryDarkColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.primaryColor.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Pengeluaran Sesi Ini',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(totalAmount),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pengeluaran operasional mengurangi saldo kas laci kasir.',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Expense List View
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 64, color: AppConstants.textLightColor.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada pengeluaran dicatat.',
                                style: GoogleFonts.poppins(
                                  color: AppConstants.textLightColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(item.date);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                side: const BorderSide(color: AppConstants.borderLightColor),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.categoryName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppConstants.textDarkColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '- ${CurrencyFormatter.format(item.amount)}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppConstants.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    if (item.description != null &&
                                        item.description!.isNotEmpty) ...[
                                      Text(
                                        item.description!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppConstants.textDarkColor.withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppConstants.textLightColor,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _showDeleteConfirmDialog(context, item),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AppConstants.errorColor.withOpacity(0.8),
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
                        ),
                ),
              ],
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseModal(context),
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
