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

class _DebtsReceivablesPageState extends State<DebtsReceivablesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppDatabase _db = getIt<AppDatabase>();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _customerDebts = [];
  List<Map<String, dynamic>> _supplierDebts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAppSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load Customer Debts grouped by Customer
      final custDebtsRaw = await (_db.select(_db.customerDebts)
            ..where((tbl) => tbl.status.equals('unpaid') | tbl.status.equals('partial')))
          .get();

      final Map<int, Map<String, dynamic>> custMap = {};
      for (var d in custDebtsRaw) {
        final cust = await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(d.customerId))).getSingleOrNull();
        if (cust == null) continue;

        final remaining = d.amount - d.paidAmount;
        if (remaining <= 0) continue;

        if (!custMap.containsKey(d.customerId)) {
          custMap[d.customerId] = {
            'customer': cust,
            'totalDebt': 0.0,
            'records': <Map<String, dynamic>>[],
          };
        }
        custMap[d.customerId]!['totalDebt'] += remaining;
        
        final payments = await (_db.select(_db.customerDebtPayments)
              ..where((tbl) => tbl.customerDebtId.equals(d.id))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.id, mode: OrderingMode.desc)]))
            .get();
        (custMap[d.customerId]!['records'] as List<Map<String, dynamic>>).add({
          'debt': d,
          'payments': payments,
        });
      }

      // Load Supplier Debts grouped by Supplier
      final suppDebtsRaw = await (_db.select(_db.supplierDebts)
            ..where((tbl) => tbl.status.equals('unpaid') | tbl.status.equals('partial')))
          .get();

      final Map<int, Map<String, dynamic>> suppMap = {};
      for (var d in suppDebtsRaw) {
        final supp = await (_db.select(_db.suppliers)..where((tbl) => tbl.id.equals(d.supplierId))).getSingleOrNull();
        if (supp == null) continue;

        final remaining = d.amount - d.paidAmount;
        if (remaining <= 0) continue;

        if (!suppMap.containsKey(d.supplierId)) {
          suppMap[d.supplierId] = {
            'supplier': supp,
            'totalDebt': 0.0,
            'records': <Map<String, dynamic>>[],
          };
        }
        suppMap[d.supplierId]!['totalDebt'] += remaining;

        final payments = await (_db.select(_db.supplierDebtPayments)
              ..where((tbl) => tbl.supplierDebtId.equals(d.id))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.id, mode: OrderingMode.desc)]))
            .get();
        (suppMap[d.supplierId]!['records'] as List<Map<String, dynamic>>).add({
          'debt': d,
          'payments': payments,
        });
      }

      if (mounted) {
        setState(() {
          _customerDebts = custMap.values.toList()
            ..sort((a, b) => (b['totalDebt'] as double).compareTo(a['totalDebt'] as double));
          _supplierDebts = suppMap.values.toList()
            ..sort((a, b) => (b['totalDebt'] as double).compareTo(a['totalDebt'] as double));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showAppSnackbar('Gagal memuat data hutang & piutang: $e', isError: true);
      }
    }
  }

  Future<void> _payCustomerDebt(CustomerDebt debt, double payAmount, String paymentMethod, String customerName) async {
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
        final order = await (_db.select(_db.orders)..where((tbl) => tbl.id.equals(debt.orderId!))).getSingleOrNull();
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

    _showAppSnackbar(
      isLunas
          ? 'Pelunasan piutang $customerName (${CurrencyFormatter.format(finalPay)}) berhasil! Bon lunas.'
          : 'Pembayaran piutang $customerName (${CurrencyFormatter.format(finalPay)}) berhasil dicatat.',
    );
    _loadData();
  }

  Future<void> _paySupplierDebt(SupplierDebt debt, double payAmount, String paymentMethod, String supplierName) async {
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

    _showAppSnackbar(
      isLunas
          ? 'Pelunasan hutang $supplierName (${CurrencyFormatter.format(finalPay)}) berhasil! Hutang lunas.'
          : 'Pembayaran hutang $supplierName (${CurrencyFormatter.format(finalPay)}) berhasil dicatat.',
    );
    _loadData();
  }

  void _showPayDialog({
    required String title,
    required double maxAmount,
    required Function(double, String) onConfirm,
  }) {
    _amountController.text = maxAmount.toStringAsFixed(0);
    String selectedMethod = 'cash';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              title,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Card Sisa Tagihan
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sisa Tagihan Tertunggak',
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            CurrencyFormatter.format(maxAmount),
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Jumlah Pembayaran *',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            'Rp',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 14),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Metode Pembayaran',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMethodChoice('cash', 'Tunai', Icons.money_rounded, selectedMethod, (val) {
                          setDialogState(() => selectedMethod = val);
                        }),
                        const SizedBox(width: 8),
                        _buildMethodChoice('transfer', 'Transfer', Icons.account_balance_rounded, selectedMethod, (val) {
                          setDialogState(() => selectedMethod = val);
                        }),
                        const SizedBox(width: 8),
                        _buildMethodChoice('qris', 'QRIS', Icons.qr_code_2_rounded, selectedMethod, (val) {
                          setDialogState(() => selectedMethod = val);
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        onPressed: () {
                          final val = double.tryParse(_amountController.text) ?? 0.0;
                          if (val <= 0) return;
                          Navigator.pop(ctx);
                          onConfirm(val, selectedMethod);
                        },
                        label: Text(
                          'KONFIRMASI BAYAR',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMethodChoice(String id, String label, IconData icon, String current, Function(String) onSelect) {
    final isSelected = id == current;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(id),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerDetailDialog(Map<String, dynamic> item) {
    final Customer customer = item['customer'];
    final List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(item['records']);
    final double totalDebt = item['totalDebt'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Total Piutang: ${CurrencyFormatter.format(totalDebt)}',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, idx) {
                      final record = records[idx];
                      final CustomerDebt d = record['debt'];
                      final List<CustomerDebtPayment> payments = List<CustomerDebtPayment>.from(record['payments']);
                      final remaining = d.amount - d.paidAmount;
                      final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(d.createdAt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: remaining <= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: remaining <= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                  ),
                                  child: Text(
                                    remaining <= 0 ? 'Lunas' : 'Belum Lunas',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: remaining <= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Bon:', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                                Text(CurrencyFormatter.format(d.amount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sudah Terbayar:', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                                Text(CurrencyFormatter.format(d.paidAmount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                              ],
                            ),
                            const Divider(height: 12, color: Color(0xFFE2E8F0)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sisa Tagihan:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                Text(CurrencyFormatter.format(remaining), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                              ],
                            ),
                            if (remaining > 0) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.payment_rounded, size: 15),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showPayDialog(
                                      title: 'Bayar Bon ${customer.name}',
                                      maxAmount: remaining,
                                      onConfirm: (amount, paymentMethod) => _payCustomerDebt(d, amount, paymentMethod, customer.name),
                                    );
                                  },
                                  label: Text('Bayar Tagihan Ini', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11.5)),
                                ),
                              ),
                            ],
                            if (payments.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('Riwayat Pembayaran:', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              ...payments.map((p) {
                                final pDateStr = DateFormat('dd/MM/yy HH:mm').format(p.createdAt);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('$pDateStr • ${p.paymentMethod.toUpperCase()}', style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B))),
                                      Text(CurrencyFormatter.format(p.amountPaid), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupplierDetailDialog(Map<String, dynamic> item) {
    final Supplier supplier = item['supplier'];
    final List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(item['records']);
    final double totalDebt = item['totalDebt'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Total Hutang: ${CurrencyFormatter.format(totalDebt)}',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, idx) {
                      final record = records[idx];
                      final SupplierDebt d = record['debt'];
                      final List<SupplierDebtPayment> payments = List<SupplierDebtPayment>.from(record['payments']);
                      final remaining = d.amount - d.paidAmount;
                      final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(d.createdAt);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: remaining <= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: remaining <= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                  ),
                                  child: Text(
                                    remaining <= 0 ? 'Lunas' : 'Belum Lunas',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: remaining <= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Tagihan PO:', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                                Text(CurrencyFormatter.format(d.amount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sudah Terbayar:', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                                Text(CurrencyFormatter.format(d.paidAmount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
                              ],
                            ),
                            const Divider(height: 12, color: Color(0xFFE2E8F0)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sisa Hutang:', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                Text(CurrencyFormatter.format(remaining), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                              ],
                            ),
                            if (remaining > 0) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 38,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.payment_rounded, size: 15),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showPayDialog(
                                      title: 'Bayar Hutang ${supplier.name}',
                                      maxAmount: remaining,
                                      onConfirm: (amount, paymentMethod) => _paySupplierDebt(d, amount, paymentMethod, supplier.name),
                                    );
                                  },
                                  label: Text('Bayar Hutang Ini', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11.5)),
                                ),
                              ),
                            ],
                            if (payments.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('Riwayat Pembayaran:', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              ...payments.map((p) {
                                final pDateStr = DateFormat('dd/MM/yy HH:mm').format(p.createdAt);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('$pDateStr • ${p.paymentMethod.toUpperCase()}', style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B))),
                                      Text(CurrencyFormatter.format(p.amountPaid), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double customerTotal, double supplierTotal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Piutang (Bon)',
                          style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    CurrencyFormatter.format(customerTotal),
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1D4ED8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.outbox_rounded, size: 16, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hutang Suplier',
                          style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    CurrencyFormatter.format(supplierTotal),
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                    overflow: TextOverflow.ellipsis,
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCustDebt = _customerDebts.fold<double>(0.0, (sum, item) => sum + item['totalDebt']);
    final totalSuppDebt = _supplierDebts.fold<double>(0.0, (sum, item) => sum + item['totalDebt']);

    final filteredCustDebts = _customerDebts.where((item) {
      if (_searchQuery.isEmpty) return true;
      final Customer c = item['customer'];
      return c.name.toLowerCase().contains(_searchQuery) || (c.phone?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    final filteredSuppDebts = _supplierDebts.where((item) {
      if (_searchQuery.isEmpty) return true;
      final Supplier s = item['supplier'];
      return s.name.toLowerCase().contains(_searchQuery) || (s.phone?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Executive Clean Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Hutang & Piutang',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE2E8F0)),

            if (!_isLoading) ...[
              _buildSummaryCards(totalCustDebt, totalSuppDebt),

              // Search Bar Clean
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama pelanggan / pemasok...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),

              // Segmented TabBar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: const Color(0xFF0F172A),
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
                    tabs: [
                      Tab(text: 'Piutang (${_customerDebts.length})'),
                      Tab(text: 'Hutang (${_supplierDebts.length})'),
                    ],
                  ),
                ),
              ),
            ],

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Piutang Pelanggan
                        filteredCustDebts.isEmpty
                            ? _buildEmptyState('Tidak ada piutang bon pelanggan.', Icons.check_circle_outline_rounded)
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                  itemCount: filteredCustDebts.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredCustDebts[index];
                                    final Customer customer = item['customer'];
                                    final double total = item['totalDebt'];
                                    final List records = item['records'];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _showCustomerDetailDialog(item),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 20),
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
                                                        fontSize: 13.5,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${records.length} transaksi bon • ${customer.phone ?? 'No telp -'}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        color: const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    CurrencyFormatter.format(total),
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13.5,
                                                      color: const Color(0xFF2563EB),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Detail',
                                                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                                      ),
                                                      const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                        // Tab 2: Hutang Suplier
                        filteredSuppDebts.isEmpty
                            ? _buildEmptyState('Tidak ada hutang ke supplier aktif.', Icons.task_alt_rounded)
                            : RefreshIndicator(
                                onRefresh: _loadData,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                  itemCount: filteredSuppDebts.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredSuppDebts[index];
                                    final Supplier supplier = item['supplier'];
                                    final double total = item['totalDebt'];
                                    final List records = item['records'];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => _showSupplierDetailDialog(item),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.local_shipping_rounded, color: Color(0xFFDC2626), size: 20),
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
                                                        fontSize: 13.5,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${records.length} faktur PO • ${supplier.phone ?? 'No telp -'}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        color: const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    CurrencyFormatter.format(total),
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13.5,
                                                      color: const Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Detail',
                                                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                                      ),
                                                      const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
