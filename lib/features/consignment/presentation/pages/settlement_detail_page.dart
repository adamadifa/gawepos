import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/consignment_repository.dart';
import '../bloc/consignment_cubit.dart';

class SettlementDetailPage extends StatefulWidget {
  final int settlementId;
  const SettlementDetailPage({super.key, required this.settlementId});

  @override
  State<SettlementDetailPage> createState() => _SettlementDetailPageState();
}

class _SettlementDetailPageState extends State<SettlementDetailPage> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final repo = getIt<ConsignmentRepository>();
    final data = await repo.getSettlementDetail(widget.settlementId);
    if (mounted) {
      setState(() {
        _detail = data;
        _isLoading = false;
      });
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

  void _showPaymentDialog(ConsignmentSettlement settlement) {
    final remaining = settlement.supplierPayableAmount - settlement.paidAmount;
    final payController = TextEditingController(text: remaining.toStringAsFixed(0));
    String method = 'cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pembayaran Hak Penitip',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Sisa tagihan yang harus dibayar: ${CurrencyFormatter.format(remaining)}',
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Metode Pembayaran:',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setSheetState(() => method = 'cash'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: method == 'cash' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: method == 'cash' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        ),
                        child: Center(
                          child: Text('Tunai / Kas', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: method == 'cash' ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setSheetState(() => method = 'transfer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: method == 'transfer' ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: method == 'transfer' ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        ),
                        child: Center(
                          child: Text('Transfer Bank', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: method == 'transfer' ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: payController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Nominal Bayar (Rp)',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(payController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                    if (amount <= 0) return;
                    Navigator.pop(ctx);
                    final success = await context.read<ConsignmentCubit>().paySettlement(
                          settlementId: settlement.id,
                          amount: amount,
                          paymentMethod: method,
                        );
                    if (success) {
                      _showAppSnackbar('Pembayaran settlement berhasil disimpan!');
                      _loadDetail();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Konfirmasi Bayar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_detail == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Text('Faktur settlement tidak ditemukan', style: GoogleFonts.poppins()),
        ),
      );
    }

    final settlement = _detail!['settlement'] as ConsignmentSettlement;
    final supplier = _detail!['supplier'] as Supplier;
    final items = _detail!['items'] as List<Map<String, dynamic>>;

    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
    final periodFormat = DateFormat('dd MMM yyyy', 'id_ID');

    final isPaid = settlement.paymentStatus == 'paid';
    final isPartial = settlement.paymentStatus == 'partial';
    final remaining = settlement.supplierPayableAmount - settlement.paidAmount;

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
          settlement.settlementNo,
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Invoice Header Card
          Container(
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
                      'FAKTUR SETTLEMENT',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB), letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFDCFCE7) : (isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPaid ? 'Lunas' : (isPartial ? 'Sebagian' : 'Belum Dibayar'),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? const Color(0xFF16A34A) : (isPartial ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  supplier.name,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                Text(
                  'Dibuat: ${dateFormat.format(settlement.createdAt)}',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                Text(
                  'Periode Penjualan: ${periodFormat.format(settlement.startDate)} - ${periodFormat.format(settlement.endDate)}',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                if (settlement.notes != null && settlement.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Catatan: ${settlement.notes}',
                    style: GoogleFonts.poppins(fontSize: 11.5, fontStyle: FontStyle.italic, color: const Color(0xFF475569)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Rincian Item Settlement
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rincian Produk Titipan',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                ...items.map((row) {
                  final item = row['item'] as ConsignmentSettlementItem;
                  final product = row['product'] as Product;
                  final unit = row['unit'] as ProductUnit;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                '${item.soldQty.toInt()} ${unit.name} x ${CurrencyFormatter.format(item.supplierRate)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(item.subtotalPayable),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF2563EB)),
                            ),
                            Text(
                              'Komisi: ${CurrencyFormatter.format(item.subtotalCommission)}',
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
          ),
          const SizedBox(height: 16),

          // 3. Ringkasan Total & Pembayaran
          Container(
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
                    Text(CurrencyFormatter.format(settlement.totalSalesAmount), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hak Komisi Toko', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF16A34A))),
                    Text(CurrencyFormatter.format(settlement.storeCommissionAmount), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Hak Bayar Penitip', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    Text(CurrencyFormatter.format(settlement.supplierPayableAmount), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB))),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sudah Dibayarkan (${settlement.paymentMethod ?? "Tunai"})', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(CurrencyFormatter.format(settlement.paidAmount), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sisa Tagihan Belum Dibayar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                    Text(CurrencyFormatter.format(remaining), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tombol Bayar jika masih ada sisa tagihan
          if (remaining > 0)
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _showPaymentDialog(settlement),
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: Text('Bayar / Cicil Tagihan (${CurrencyFormatter.format(remaining)})', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
