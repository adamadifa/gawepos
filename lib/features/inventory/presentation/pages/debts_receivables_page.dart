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

  List<Map<String, dynamic>> _customerDebts = [];
  List<Map<String, dynamic>> _supplierDebts = [];
  bool _isLoading = true;

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
    super.dispose();
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
        
        final payments = await (_db.select(_db.customerDebtPayments)..where((tbl) => tbl.customerDebtId.equals(d.id))).get();
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

        final payments = await (_db.select(_db.supplierDebtPayments)..where((tbl) => tbl.supplierDebtId.equals(d.id))).get();
        (suppMap[d.supplierId]!['records'] as List<Map<String, dynamic>>).add({
          'debt': d,
          'payments': payments,
        });
      }

      setState(() {
        _customerDebts = custMap.values.toList()
          ..sort((a, b) => (b['totalDebt'] as double).compareTo(a['totalDebt'] as double));
        _supplierDebts = suppMap.values.toList()
          ..sort((a, b) => (b['totalDebt'] as double).compareTo(a['totalDebt'] as double));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data hutang: $e'), backgroundColor: AppConstants.errorColor),
      );
    }
  }

  Future<void> _payCustomerDebt(CustomerDebt debt, double payAmount, String paymentMethod) async {
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

    _loadData();
  }

  Future<void> _paySupplierDebt(SupplierDebt debt, double payAmount, String paymentMethod) async {
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

    _loadData();
  }

  void _showPayDialog({
    required String title,
    required double maxAmount,
    required Function(double, String) onConfirm,
  }) {
    _amountController.text = maxAmount.toStringAsFixed(0);
    String selectedMethod = 'cash';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sisa Tagihan: ${CurrencyFormatter.format(maxAmount)}',
              style: GoogleFonts.poppins(fontSize: 13, color: AppConstants.textLightColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar',
                prefixText: 'Rp ',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            Text(
              'Metode Pembayaran',
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                    DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedMethod = val ?? 'cash');
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_amountController.text) ?? 0.0;
              if (val <= 0) return;
              onConfirm(val, selectedMethod);
              Navigator.pop(ctx);
            },
            child: const Text('KONFIRMASI BAYAR'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetailDialog(Map<String, dynamic> item) {
    final Customer customer = item['customer'];
    final List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(item['records']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Detail Bon ${customer.name}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, idx) {
              final record = records[idx];
              final CustomerDebt d = record['debt'];
              final List<CustomerDebtPayment> payments = List<CustomerDebtPayment>.from(record['payments']);
              final remaining = d.amount - d.paidAmount;
              final dateStr = DateFormat('dd MMM yyyy').format(d.createdAt);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppConstants.borderLightColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal: $dateStr',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Total: ${CurrencyFormatter.format(d.amount)}',
                                  style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                                ),
                                Text(
                                  'Sisa: ${CurrencyFormatter.format(remaining)}',
                                  style: const TextStyle(fontSize: 11, color: AppConstants.errorColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (remaining > 0)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showPayDialog(
                                  title: 'Bayar Bon ${customer.name}',
                                  maxAmount: remaining,
                                  onConfirm: (amount, paymentMethod) => _payCustomerDebt(d, amount, paymentMethod),
                                );
                              },
                              child: const Text('BAYAR', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      if (payments.isNotEmpty) ...[
                        const Divider(height: 12),
                        Text(
                          'Histori Pembayaran:',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.textLightColor),
                        ),
                        const SizedBox(height: 4),
                        ...payments.map((p) {
                          final pDateStr = DateFormat('dd MMM yyyy HH:mm').format(p.createdAt);
                          final methodStr = p.paymentMethod == 'cash'
                              ? 'Tunai'
                              : p.paymentMethod == 'transfer'
                                  ? 'Transfer'
                                  : p.paymentMethod == 'qris'
                                      ? 'QRIS'
                                      : p.paymentMethod.toUpperCase();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$pDateStr ($methodStr)',
                                  style: const TextStyle(fontSize: 10, color: AppConstants.textLightColor),
                                ),
                                Text(
                                  CurrencyFormatter.format(p.amountPaid),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  void _showSupplierDetailDialog(Map<String, dynamic> item) {
    final Supplier supplier = item['supplier'];
    final List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(item['records']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Detail Hutang ${supplier.name}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, idx) {
              final record = records[idx];
              final SupplierDebt d = record['debt'];
              final List<SupplierDebtPayment> payments = List<SupplierDebtPayment>.from(record['payments']);
              final remaining = d.amount - d.paidAmount;
              final dateStr = DateFormat('dd MMM yyyy').format(d.createdAt);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppConstants.borderLightColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal: $dateStr',
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Total: ${CurrencyFormatter.format(d.amount)}',
                                  style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                                ),
                                Text(
                                  'Sisa: ${CurrencyFormatter.format(remaining)}',
                                  style: const TextStyle(fontSize: 11, color: AppConstants.errorColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (remaining > 0)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showPayDialog(
                                  title: 'Bayar Hutang ${supplier.name}',
                                  maxAmount: remaining,
                                  onConfirm: (amount, paymentMethod) => _paySupplierDebt(d, amount, paymentMethod),
                                );
                              },
                              child: const Text('BAYAR', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                      if (payments.isNotEmpty) ...[
                        const Divider(height: 12),
                        Text(
                          'Histori Pembayaran:',
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppConstants.textLightColor),
                        ),
                        const SizedBox(height: 4),
                        ...payments.map((p) {
                          final pDateStr = DateFormat('dd MMM yyyy HH:mm').format(p.createdAt);
                          final methodStr = p.paymentMethod == 'cash'
                              ? 'Tunai'
                              : p.paymentMethod == 'transfer'
                                  ? 'Transfer'
                                  : p.paymentMethod == 'qris'
                                      ? 'QRIS'
                                      : p.paymentMethod.toUpperCase();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$pDateStr ($methodStr)',
                                  style: const TextStyle(fontSize: 10, color: AppConstants.textLightColor),
                                ),
                                Text(
                                  CurrencyFormatter.format(p.amountPaid),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double customerTotal, double supplierTotal) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Piutang Pelanggan (Bon)',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(customerTotal),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hutang Supplier',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(supplierTotal),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                  ),
                ],
              ),
            ),
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
          Icon(Icons.assignment_turned_in_rounded, size: 48, color: Colors.grey.shade300),
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
    final totalCustDebt = _customerDebts.fold<double>(0.0, (sum, item) => sum + item['totalDebt']);
    final totalSuppDebt = _supplierDebts.fold<double>(0.0, (sum, item) => sum + item['totalDebt']);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Hutang & Piutang',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textDarkColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: AppConstants.textLightColor,
          indicatorColor: AppConstants.primaryColor,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: const [
            Tab(text: 'Piutang Pelanggan'),
            Tab(text: 'Hutang Supplier'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCards(totalCustDebt, totalSuppDebt),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Customer Debts list
                      _customerDebts.isEmpty
                          ? _buildEmptyState('Tidak ada piutang bon pelanggan aktif.')
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _customerDebts.length,
                              itemBuilder: (context, index) {
                                final item = _customerDebts[index];
                                final Customer customer = item['customer'];
                                final double total = item['totalDebt'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: AppConstants.borderLightColor),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    title: Text(
                                      customer.name,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      customer.phone ?? 'Tidak ada kontak',
                                      style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(total),
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade900),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right_rounded, color: AppConstants.textLightColor),
                                      ],
                                    ),
                                    onTap: () => _showCustomerDetailDialog(item),
                                  ),
                                );
                              },
                            ),

                      // Supplier Debts list
                      _supplierDebts.isEmpty
                          ? _buildEmptyState('Tidak ada hutang supplier aktif.')
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _supplierDebts.length,
                              itemBuilder: (context, index) {
                                final item = _supplierDebts[index];
                                final Supplier supplier = item['supplier'];
                                final double total = item['totalDebt'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: AppConstants.borderLightColor),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    title: Text(
                                      supplier.name,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      supplier.phone ?? 'Tidak ada kontak',
                                      style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(total),
                                          style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade900),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right_rounded, color: AppConstants.textLightColor),
                                      ],
                                    ),
                                    onTap: () => _showSupplierDetailDialog(item),
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
