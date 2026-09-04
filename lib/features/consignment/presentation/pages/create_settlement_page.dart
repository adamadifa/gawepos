import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/consignment_repository.dart';
import '../bloc/consignment_cubit.dart';

class CreateSettlementPage extends StatefulWidget {
  final Supplier supplier;
  const CreateSettlementPage({super.key, required this.supplier});

  @override
  State<CreateSettlementPage> createState() => _CreateSettlementPageState();
}

class _CreateSettlementPageState extends State<CreateSettlementPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'cash'; // 'cash', 'transfer'
  bool _isDirectPay = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculate() {
    context.read<ConsignmentCubit>().calculateUnsettled(
          supplierId: widget.supplier.id,
          startDate: _startDate,
          endDate: _endDate,
        );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppConstants.primaryColor,
            colorScheme: const ColorScheme.light(primary: AppConstants.primaryColor),
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
      _calculate();
    }
  }

  void _showAppSnackbar(String message, {bool isError = false}) {
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
        backgroundColor: isError ? AppConstants.errorColor : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitSettlement(ConsignmentUnsettledCalculated state) async {
    if (state.items.isEmpty) {
      _showAppSnackbar('Tidak ada barang terjual yang perlu di-settle.', isError: true);
      return;
    }

    final double totalPayable = state.totalPayable;
    final double paidAmount = _isDirectPay
        ? (double.tryParse(_paidAmountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? totalPayable)
        : 0.0;

    setState(() => _isProcessing = true);

    final success = await context.read<ConsignmentCubit>().createSettlement(
          supplierId: widget.supplier.id,
          startDate: _startDate,
          endDate: _endDate,
          items: state.items,
          paidAmount: paidAmount,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    setState(() => _isProcessing = false);

    if (success && mounted) {
      _showAppSnackbar('Nota settlement konsinyasi berhasil dibuat & disimpan!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Buat Settlement Konsinyasi',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: BlocBuilder<ConsignmentCubit, ConsignmentState>(
        builder: (context, state) {
          if (state is ConsignmentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ConsignmentUnsettledCalculated) {
            if (_paidAmountController.text.isEmpty && state.totalPayable > 0) {
              _paidAmountController.text = state.totalPayable.toStringAsFixed(0);
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // Header Mitra Card
                      _buildSupplierCard(dateFormat),
                      const SizedBox(height: 16),

                      // Ringkasan Finansial Card
                      _buildFinancialSummaryCard(state),
                      const SizedBox(height: 16),

                      // Daftar Rincian Barang Terjual
                      _buildItemsList(state.items),
                      const SizedBox(height: 16),

                      // Form Pelunasan / Opsi Pembayaran
                      _buildPaymentSection(state.totalPayable),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Bottom Action Button
                _buildBottomActionBar(state),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSupplierCard(DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  widget.supplier.name.isNotEmpty ? widget.supplier.name[0].toUpperCase() : 'M',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.supplier.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Pemasok / Penitip Barang',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _selectDateRange,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Periode: ${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard(ConsignmentUnsettledCalculated state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Omzet Penjualan', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
              Text(
                CurrencyFormatter.format(state.totalSales),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Komisi / Bagian Toko', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF16A34A))),
              Text(
                '+ ${CurrencyFormatter.format(state.totalCommission)}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hak Bersih Penitip (Setor)',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              Text(
                CurrencyFormatter.format(state.totalPayable),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<ConsignmentUnsettledItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rincian Produk Terjual',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} Item',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Tidak ada transaksi penjualan produk titipan pada rentang tanggal ini.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            '${item.soldQty.toInt()} ${item.unit.name} x ${CurrencyFormatter.format(item.supplierRate)} (Hak Setor)',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(item.supplierPayable),
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF2563EB)),
                        ),
                        Text(
                          'Komisi: ${CurrencyFormatter.format(item.storeCommission)}',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(double totalPayable) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Langsung Bayar / Lunasi?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              Switch(
                value: _isDirectPay,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) => setState(() => _isDirectPay = val),
              ),
            ],
          ),
          if (_isDirectPay) ...[
            const SizedBox(height: 12),
            Text(
              'Metode Pembayaran',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'cash'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'cash' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentMethod == 'cash' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments_rounded, size: 16, color: _paymentMethod == 'cash' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('Tunai / Kas', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _paymentMethod == 'cash' ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'transfer'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'transfer' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentMethod == 'transfer' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded, size: 16, color: _paymentMethod == 'transfer' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('Transfer Bank', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _paymentMethod == 'transfer' ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _paidAmountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Jumlah yang Dibayarkan (Rp)',
                labelStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                prefixText: 'Rp ',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Catatan Settlement (Opsional)',
              labelStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
              hintText: 'Contoh: Settlement Titipan Roti Minggu ke-1',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(ConsignmentUnsettledCalculated state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: (_isProcessing || state.items.isEmpty) ? null : () => _submitSettlement(state),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            disabledBackgroundColor: const Color(0xFF94A3B8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Simpan & Selesaikan Settlement',
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
