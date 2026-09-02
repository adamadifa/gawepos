import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/app_database.dart';

class DebtsReceivablesPage extends StatefulWidget {
  const DebtsReceivablesPage({super.key});

  @override
  State<DebtsReceivablesPage> createState() => _DebtsReceivablesPageState();
}

class _DebtsReceivablesPageState extends State<DebtsReceivablesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppDatabase _db = getIt<AppDatabase>();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _customerDebts = [];
  List<Map<String, dynamic>> _filteredCustomerDebts = [];
  List<Map<String, dynamic>> _supplierDebts = [];
  List<Map<String, dynamic>> _filteredSupplierDebts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
        _applySearchFilter();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Load Customer Debts (Piutang) grouped by Customer
      final custDebtsRaw = await (_db.select(_db.customerDebts)
            ..where((tbl) =>
                tbl.status.equals('unpaid') | tbl.status.equals('partial'))
            ..orderBy([
              (tbl) => OrderingTerm(
                  expression: tbl.createdAt, mode: OrderingMode.desc)
            ]))
          .get();

      final Map<int, Map<String, dynamic>> custMap = {};
      for (var d in custDebtsRaw) {
        final cust = await (_db.select(_db.customers)
              ..where((tbl) => tbl.id.equals(d.customerId)))
            .getSingleOrNull();
        if (cust == null) continue;

        final remaining = d.amount - d.paidAmount;
        if (remaining <= 0) continue;

        // Fetch associated order if available
        Order? order;
        if (d.orderId != null) {
          order = await (_db.select(_db.orders)
                ..where((tbl) => tbl.id.equals(d.orderId!)))
              .getSingleOrNull();
        }

        final payments = await (_db.select(_db.customerDebtPayments)
              ..where((tbl) => tbl.customerDebtId.equals(d.id))
              ..orderBy([
                (tbl) => OrderingTerm(
                    expression: tbl.createdAt, mode: OrderingMode.desc)
              ]))
            .get();

        if (!custMap.containsKey(d.customerId)) {
          custMap[d.customerId] = {
            'customer': cust,
            'totalDebt': 0.0,
            'totalOriginal': 0.0,
            'totalPaid': 0.0,
            'records': <Map<String, dynamic>>[],
          };
        }

        custMap[d.customerId]!['totalDebt'] += remaining;
        custMap[d.customerId]!['totalOriginal'] += d.amount;
        custMap[d.customerId]!['totalPaid'] += d.paidAmount;

        (custMap[d.customerId]!['records'] as List<Map<String, dynamic>>).add({
          'debt': d,
          'order': order,
          'payments': payments,
        });
      }

      // 2. Load Supplier Debts (Hutang) grouped by Supplier
      final suppDebtsRaw = await (_db.select(_db.supplierDebts)
            ..where((tbl) =>
                tbl.status.equals('unpaid') | tbl.status.equals('partial'))
            ..orderBy([
              (tbl) => OrderingTerm(
                  expression: tbl.createdAt, mode: OrderingMode.desc)
            ]))
          .get();

      final Map<int, Map<String, dynamic>> suppMap = {};
      for (var d in suppDebtsRaw) {
        final supp = await (_db.select(_db.suppliers)
              ..where((tbl) => tbl.id.equals(d.supplierId)))
            .getSingleOrNull();
        if (supp == null) continue;

        final remaining = d.amount - d.paidAmount;
        if (remaining <= 0) continue;

        // Fetch associated purchase if available
        Purchase? purchase;
        if (d.purchaseId != null) {
          purchase = await (_db.select(_db.purchases)
                ..where((tbl) => tbl.id.equals(d.purchaseId!)))
              .getSingleOrNull();
        }

        final payments = await (_db.select(_db.supplierDebtPayments)
              ..where((tbl) => tbl.supplierDebtId.equals(d.id))
              ..orderBy([
                (tbl) => OrderingTerm(
                    expression: tbl.createdAt, mode: OrderingMode.desc)
              ]))
            .get();

        if (!suppMap.containsKey(d.supplierId)) {
          suppMap[d.supplierId] = {
            'supplier': supp,
            'totalDebt': 0.0,
            'totalOriginal': 0.0,
            'totalPaid': 0.0,
            'records': <Map<String, dynamic>>[],
          };
        }

        suppMap[d.supplierId]!['totalDebt'] += remaining;
        suppMap[d.supplierId]!['totalOriginal'] += d.amount;
        suppMap[d.supplierId]!['totalPaid'] += d.paidAmount;

        (suppMap[d.supplierId]!['records'] as List<Map<String, dynamic>>).add({
          'debt': d,
          'purchase': purchase,
          'payments': payments,
        });
      }

      setState(() {
        _customerDebts = custMap.values.toList()
          ..sort((a, b) => (b['totalDebt'] as double)
              .compareTo(a['totalDebt'] as double));
        _supplierDebts = suppMap.values.toList()
          ..sort((a, b) => (b['totalDebt'] as double)
              .compareTo(a['totalDebt'] as double));
        _isLoading = false;
      });
      _applySearchFilter();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data hutang: $e',
                style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _applySearchFilter() {
    final query = _searchQuery.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomerDebts = List.from(_customerDebts);
        _filteredSupplierDebts = List.from(_supplierDebts);
      } else {
        _filteredCustomerDebts = _customerDebts.where((item) {
          final Customer cust = item['customer'];
          final name = cust.name.toLowerCase();
          final phone = (cust.phone ?? '').toLowerCase();
          return name.contains(query) || phone.contains(query);
        }).toList();

        _filteredSupplierDebts = _supplierDebts.where((item) {
          final Supplier supp = item['supplier'];
          final name = supp.name.toLowerCase();
          final phone = (supp.phone ?? '').toLowerCase();
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _payCustomerDebt(
      CustomerDebt debt, double payAmount, String paymentMethod) async {
    if (payAmount <= 0) return;
    final remaining = debt.amount - debt.paidAmount;
    final finalPay = payAmount > remaining ? remaining : payAmount;
    final newPaid = debt.paidAmount + finalPay;
    final isLunas = newPaid >= debt.amount;

    await _db.transaction(() async {
      // 1. Insert Payment Log
      await _db.into(_db.customerDebtPayments).insert(
            CustomerDebtPaymentsCompanion.insert(
              customerDebtId: debt.id,
              amountPaid: finalPay,
              paymentMethod: Value(paymentMethod),
              createdAt: Value(DateTime.now()),
            ),
          );

      // 2. Update Debt Status & paidAmount
      await _db.update(_db.customerDebts).replace(
            debt.copyWith(
              paidAmount: newPaid,
              status: isLunas ? 'paid' : 'partial',
            ),
          );

      // 3. Update Order paidAmount & paymentStatus if associated
      if (debt.orderId != null) {
        final order = await (_db.select(_db.orders)
              ..where((tbl) => tbl.id.equals(debt.orderId!)))
            .getSingleOrNull();
        if (order != null) {
          final updatedPaid = order.paidAmount + finalPay;
          await _db.update(_db.orders).replace(
                order.copyWith(
                  paidAmount: updatedPaid,
                  paymentStatus: isLunas ? 'paid' : 'partial',
                ),
              );
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pembayaran ${CurrencyFormatter.format(finalPay)} berhasil dicatat',
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    _loadData();
  }

  Future<void> _paySupplierDebt(
      SupplierDebt debt, double payAmount, String paymentMethod) async {
    if (payAmount <= 0) return;
    final remaining = debt.amount - debt.paidAmount;
    final finalPay = payAmount > remaining ? remaining : payAmount;
    final newPaid = debt.paidAmount + finalPay;
    final isLunas = newPaid >= debt.amount;

    await _db.transaction(() async {
      // 1. Insert Payment Log
      await _db.into(_db.supplierDebtPayments).insert(
            SupplierDebtPaymentsCompanion.insert(
              supplierDebtId: debt.id,
              amountPaid: finalPay,
              paymentMethod: Value(paymentMethod),
              createdAt: Value(DateTime.now()),
            ),
          );

      // 2. Update Debt Status & paidAmount
      await _db.update(_db.supplierDebts).replace(
            debt.copyWith(
              paidAmount: newPaid,
              status: isLunas ? 'paid' : 'partial',
            ),
          );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pembayaran ${CurrencyFormatter.format(finalPay)} berhasil dicatat',
                style: GoogleFonts.poppins(fontSize: 12.5),
              ),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    _loadData();
  }

  // ─── MODERN PAYMENT BOTTOM SHEET ──────────────────────────────────────────
  void _showPayBottomSheet({
    required String title,
    required String targetName,
    required double maxAmount,
    required Function(double, String) onConfirm,
  }) {
    final amountController = TextEditingController(text: maxAmount.toStringAsFixed(0));
    String selectedMethod = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                targetName,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),

                    // Tagihan Information Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sisa Tagihan Tertunggak',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(maxAmount),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Nominal Buttons
                    Text(
                      'Pilihan Cepat Nominal',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuickAmountChip(
                          label: 'Lunas (100%)',
                          amount: maxAmount,
                          currentText: amountController.text,
                          onTap: () {
                            setModalState(() {
                              amountController.text = maxAmount.toStringAsFixed(0);
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        if (maxAmount > 1000) ...[
                          _buildQuickAmountChip(
                            label: '50%',
                            amount: (maxAmount * 0.5).roundToDouble(),
                            currentText: amountController.text,
                            onTap: () {
                              setModalState(() {
                                amountController.text = (maxAmount * 0.5).round().toString();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildQuickAmountChip(
                            label: '25%',
                            amount: (maxAmount * 0.25).roundToDouble(),
                            currentText: amountController.text,
                            onTap: () {
                              setModalState(() {
                                amountController.text = (maxAmount * 0.25).round().toString();
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Amount Input
                    Text(
                      'Jumlah Pembayaran',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Text(
                            'Rp',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 18),

                    // Payment Method Selector
                    Text(
                      'Metode Pembayaran',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMethodCard(
                            keyVal: 'cash',
                            label: 'Tunai',
                            icon: Icons.payments_outlined,
                            isSelected: selectedMethod == 'cash',
                            onTap: () => setModalState(() => selectedMethod = 'cash'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMethodCard(
                            keyVal: 'transfer',
                            label: 'Transfer',
                            icon: Icons.account_balance_outlined,
                            isSelected: selectedMethod == 'transfer',
                            onTap: () => setModalState(() => selectedMethod = 'transfer'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMethodCard(
                            keyVal: 'qris',
                            label: 'QRIS',
                            icon: Icons.qr_code_2_rounded,
                            isSelected: selectedMethod == 'qris',
                            onTap: () => setModalState(() => selectedMethod = 'qris'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final val = double.tryParse(amountController.text) ?? 0.0;
                        if (val <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Masukkan nominal pembayaran yang valid',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: AppConstants.errorColor,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        onConfirm(val, selectedMethod);
                      },
                      child: Text(
                        'KONFIRMASI PEMBAYARAN',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickAmountChip({
    required String label,
    required double amount,
    required String currentText,
    required VoidCallback onTap,
  }) {
    final isMatch = (double.tryParse(currentText) ?? 0) == amount;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isMatch ? const Color(0xFF1A56DB).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isMatch ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isMatch ? FontWeight.w700 : FontWeight.w500,
                color: isMatch ? const Color(0xFF1A56DB) : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required String keyVal,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── MODERN DETAIL BOTTOM SHEET ───────────────────────────────────────────
  void _showCustomerDetailSheet(Map<String, dynamic> item) {
    final Customer customer = item['customer'];
    final List<Map<String, dynamic>> records =
        List<Map<String, dynamic>>.from(item['records']);
    final double totalDebt = item['totalDebt'];
    final double totalOriginal = item['totalOriginal'] ?? totalDebt;
    final double totalPaid = item['totalPaid'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle Bar & Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A56DB),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                customer.phone ?? 'Tidak ada nomor telepon',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Summary Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sisa Piutang Tertunggak',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(totalDebt),
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
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
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Bon',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(totalOriginal),
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Terbayar: ${CurrencyFormatter.format(totalPaid)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Daftar Transaksi Bon (${records.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              // Records List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: records.length,
                  itemBuilder: (context, idx) {
                    final record = records[idx];
                    final CustomerDebt d = record['debt'];
                    final Order? order = record['order'];
                    final List<CustomerDebtPayment> payments =
                        List<CustomerDebtPayment>.from(record['payments']);
                    final remaining = d.amount - d.paidAmount;
                    final dateStr = DateFormat('dd MMM yyyy').format(d.createdAt);
                    final refNo = order?.referenceNo ?? 'BON-#${d.id}';
                    final isOverdue = d.dueDate != null &&
                        d.dueDate!.isBefore(DateTime.now()) &&
                        remaining > 0;

                    final progress = d.amount > 0 ? (d.paidAmount / d.amount).clamp(0.0, 1.0) : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOverdue
                              ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ref & Due Date Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_outlined,
                                        size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      refNo,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: remaining <= 0
                                        ? const Color(0xFF059669).withValues(alpha: 0.1)
                                        : isOverdue
                                            ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                            : const Color(0xFFD97706).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    remaining <= 0
                                        ? 'LUNAS'
                                        : isOverdue
                                            ? 'TERLEWAT JATUH TEMPO'
                                            : 'BELUM LUNAS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: remaining <= 0
                                          ? const Color(0xFF059669)
                                          : isOverdue
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tanggal: $dateStr',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                                if (d.dueDate != null)
                                  Text(
                                    'Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(d.dueDate!)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                                      color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  remaining <= 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF1A56DB),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Nominal Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Tagihan',
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                                    Text(CurrencyFormatter.format(d.amount),
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Terbayar',
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                                    Text(CurrencyFormatter.format(d.paidAmount),
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Sisa Saldo',
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                                    Text(
                                      CurrencyFormatter.format(remaining),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: remaining > 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Action Button (Pay this specific invoice)
                            if (remaining > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A56DB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showPayBottomSheet(
                                      title: 'Bayar Bon $refNo',
                                      targetName: customer.name,
                                      maxAmount: remaining,
                                      onConfirm: (amount, paymentMethod) =>
                                          _payCustomerDebt(d, amount, paymentMethod),
                                    );
                                  },
                                  icon: const Icon(Icons.payment_rounded, size: 16),
                                  label: Text(
                                    'BAYAR TAGIHAN INI',
                                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],

                            // Payment History Logs
                            if (payments.isNotEmpty) ...[
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              Text(
                                'Riwayat Cicilan (${payments.length}):',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...payments.map((p) {
                                final pDateStr = DateFormat('dd MMM yyyy, HH:mm').format(p.createdAt);
                                final methodStr = p.paymentMethod == 'cash'
                                    ? 'Tunai'
                                    : p.paymentMethod == 'transfer'
                                        ? 'Transfer'
                                        : p.paymentMethod == 'qris'
                                            ? 'QRIS'
                                            : p.paymentMethod.toUpperCase();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              methodStr,
                                              style: GoogleFonts.poppins(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            pDateStr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '+ ${CurrencyFormatter.format(p.amountPaid)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── MODERN DETAIL BOTTOM SHEET (SUPPLIER) ───────────────────────────────
  void _showSupplierDetailSheet(Map<String, dynamic> item) {
    final Supplier supplier = item['supplier'];
    final List<Map<String, dynamic>> records =
        List<Map<String, dynamic>>.from(item['records']);
    final double totalDebt = item['totalDebt'];
    final double totalOriginal = item['totalOriginal'] ?? totalDebt;
    final double totalPaid = item['totalPaid'] ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle Bar & Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          child: Text(
                            supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                supplier.phone ?? 'Tidak ada nomor telepon',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Summary Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sisa Hutang ke Supplier',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(totalDebt),
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
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
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Tagihan',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(totalOriginal),
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Terbayar: ${CurrencyFormatter.format(totalPaid)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF34D399),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Daftar Tagihan Hutang (${records.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              // Records List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                  itemCount: records.length,
                  itemBuilder: (context, idx) {
                    final record = records[idx];
                    final SupplierDebt d = record['debt'];
                    final Purchase? purchase = record['purchase'];
                    final List<SupplierDebtPayment> payments =
                        List<SupplierDebtPayment>.from(record['payments']);
                    final remaining = d.amount - d.paidAmount;
                    final dateStr = DateFormat('dd MMM yyyy').format(d.createdAt);
                    final refNo = purchase?.referenceNo ?? 'HUTANG-#${d.id}';
                    final isOverdue = d.dueDate != null &&
                        d.dueDate!.isBefore(DateTime.now()) &&
                        remaining > 0;

                    final progress = d.amount > 0 ? (d.paidAmount / d.amount).clamp(0.0, 1.0) : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOverdue
                              ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ref & Status Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_shipping_outlined,
                                        size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      refNo,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: remaining <= 0
                                        ? const Color(0xFF059669).withValues(alpha: 0.1)
                                        : isOverdue
                                            ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                            : const Color(0xFFD97706).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    remaining <= 0
                                        ? 'LUNAS'
                                        : isOverdue
                                            ? 'TERLEWAT JATUH TEMPO'
                                            : 'BELUM LUNAS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: remaining <= 0
                                          ? const Color(0xFF059669)
                                          : isOverdue
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tanggal: $dateStr',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: const Color(0xFF64748B)),
                                ),
                                if (d.dueDate != null)
                                  Text(
                                    'Jatuh Tempo: ${DateFormat('dd MMM yyyy').format(d.dueDate!)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                                      color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  remaining <= 0
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Nominal Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Hutang',
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                                    Text(CurrencyFormatter.format(d.amount),
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Terbayar',
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                                    Text(CurrencyFormatter.format(d.paidAmount),
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Sisa Saldo',
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                                    Text(
                                      CurrencyFormatter.format(remaining),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: remaining > 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Action Button (Pay this specific invoice)
                            if (remaining > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showPayBottomSheet(
                                      title: 'Bayar Hutang $refNo',
                                      targetName: supplier.name,
                                      maxAmount: remaining,
                                      onConfirm: (amount, paymentMethod) =>
                                          _paySupplierDebt(d, amount, paymentMethod),
                                    );
                                  },
                                  icon: const Icon(Icons.payment_rounded, size: 16),
                                  label: Text(
                                    'BAYAR HUTANG INI',
                                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],

                            // Payment History Logs
                            if (payments.isNotEmpty) ...[
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              Text(
                                'Riwayat Cicilan (${payments.length}):',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...payments.map((p) {
                                final pDateStr = DateFormat('dd MMM yyyy, HH:mm').format(p.createdAt);
                                final methodStr = p.paymentMethod == 'cash'
                                    ? 'Tunai'
                                    : p.paymentMethod == 'transfer'
                                        ? 'Transfer'
                                        : p.paymentMethod == 'qris'
                                            ? 'QRIS'
                                            : p.paymentMethod.toUpperCase();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              methodStr,
                                              style: GoogleFonts.poppins(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            pDateStr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '+ ${CurrencyFormatter.format(p.amountPaid)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── EXECUTIVE SUMMARY CARDS ──────────────────────────────────────────────
  Widget _buildSummaryCards(double customerTotal, double supplierTotal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Customer Piutang Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Piutang Pelanggan',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward_rounded,
                            size: 14, color: Color(0xFF1A56DB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(customerTotal),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_customerDebts.length} Pelanggan Berhutang',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFF1A56DB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Supplier Hutang Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hutang Supplier',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            size: 14, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(supplierTotal),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_supplierDebts.length} Pemasok Tertagih',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
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
            child: Icon(icon, size: 36, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCustDebt = _customerDebts.fold<double>(
        0.0, (sum, item) => sum + item['totalDebt']);
    final totalSuppDebt = _supplierDebts.fold<double>(
        0.0, (sum, item) => sum + item['totalDebt']);

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
              'Hutang & Piutang',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kelola & catat pelunasan tagihan bon & hutang supplier',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : Column(
              children: [
                // Top Summary Cards
                _buildSummaryCards(totalCustDebt, totalSuppDebt),

                // Search Bar & Segmented TabBar Container
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      // Segmented TabBar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF64748B),
                          labelStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, fontSize: 12.5),
                          unselectedLabelStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500, fontSize: 12.5),
                          tabs: [
                            Tab(text: 'Piutang Pelanggan (${_customerDebts.length})'),
                            Tab(text: 'Hutang Supplier (${_supplierDebts.length})'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search TextField
                      TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          _searchQuery = val;
                          _applySearchFilter();
                        },
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: _tabController.index == 0
                              ? 'Cari nama pelanggan / no. telepon...'
                              : 'Cari nama supplier / no. telepon...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _applySearchFilter();
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F172A), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Customer Debts Tab
                      _filteredCustomerDebts.isEmpty
                          ? _buildEmptyState(
                              _searchQuery.isEmpty
                                  ? 'Tidak ada piutang bon pelanggan yang aktif.'
                                  : 'Tidak ada pelanggan yang cocok dengan pencarian.',
                              Icons.account_balance_wallet_outlined,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _filteredCustomerDebts.length,
                              itemBuilder: (context, index) {
                                final item = _filteredCustomerDebts[index];
                                final Customer customer = item['customer'];
                                final double total = item['totalDebt'];
                                final List records = item['records'] ?? [];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
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
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: () => _showCustomerDetailSheet(item),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: const Color(0xFF1A56DB)
                                                  .withValues(alpha: 0.1),
                                              child: Text(
                                                customer.name.isNotEmpty
                                                    ? customer.name[0].toUpperCase()
                                                    : 'C',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF1A56DB),
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer.name,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        customer.phone ?? 'Tidak ada kontak',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          color: const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 6, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF1A56DB)
                                                              .withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '${records.length} Bon',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFF1A56DB),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Sisa Tagihan',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                                Text(
                                                  CurrencyFormatter.format(total),
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.chevron_right_rounded,
                                                size: 20, color: Color(0xFF94A3B8)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                      // Supplier Debts Tab
                      _filteredSupplierDebts.isEmpty
                          ? _buildEmptyState(
                              _searchQuery.isEmpty
                                  ? 'Tidak ada hutang supplier yang aktif.'
                                  : 'Tidak ada supplier yang cocok dengan pencarian.',
                              Icons.outbox_rounded,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _filteredSupplierDebts.length,
                              itemBuilder: (context, index) {
                                final item = _filteredSupplierDebts[index];
                                final Supplier supplier = item['supplier'];
                                final double total = item['totalDebt'];
                                final List records = item['records'] ?? [];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
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
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      onTap: () => _showSupplierDetailSheet(item),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14.0),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: const Color(0xFFDC2626)
                                                  .withValues(alpha: 0.1),
                                              child: Text(
                                                supplier.name.isNotEmpty
                                                    ? supplier.name[0].toUpperCase()
                                                    : 'S',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFFDC2626),
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    supplier.name,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        supplier.phone ?? 'Tidak ada kontak',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          color: const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 6, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFDC2626)
                                                              .withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '${records.length} Faktur',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFFDC2626),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Sisa Hutang',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                                Text(
                                                  CurrencyFormatter.format(total),
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: const Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.chevron_right_rounded,
                                                size: 20, color: Color(0xFF94A3B8)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
