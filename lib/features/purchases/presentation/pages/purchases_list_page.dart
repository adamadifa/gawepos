import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/app_database.dart';
import '../../../master/data/master_repository.dart';
import '../../data/purchase_repository.dart';
import '../bloc/purchase_cubit.dart';
import 'purchase_form_page.dart';

class PurchasesListPage extends StatefulWidget {
  const PurchasesListPage({super.key});

  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  final MasterRepository _masterRepository = getIt<MasterRepository>();
  List<Supplier> _suppliers = [];
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    context.read<PurchaseCubit>().loadPurchases();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final list = await _masterRepository.getSuppliers();
      setState(() {
        _suppliers = list;
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

  Future<bool?> _showConfirmDeleteDialog(BuildContext context, bool isReceived) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isReceived ? 'Batal & Hapus Penerimaan' : 'Hapus Pesanan Pembelian',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFFDC2626)),
        ),
        content: Text(
          isReceived
              ? 'Peringatan: Pesanan ini sudah diterima. Jika Anda menghapus pesanan ini, seluruh stok barang yang bertambah dari pesanan ini akan dikurangi kembali secara otomatis dari inventory.\n\nApakah Anda yakin?'
              : 'Apakah Anda yakin ingin menghapus pesanan pembelian ini? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDetails(BuildContext context, int purchaseId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: getIt<PurchaseRepository>().getPurchaseDetails(purchaseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Gagal memuat rincian pembelian.',
                      style: GoogleFonts.poppins(color: const Color(0xFFDC2626)),
                    ),
                  ),
                );
              }

              final data = snapshot.data!;
              final Purchase purchase = data['purchase'];
              final Supplier? supplier = data['supplier'];
              final List<Map<String, dynamic>> items = data['items'];

              return SafeArea(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                purchase.referenceNo,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                supplier?.name ?? 'Supplier Umum',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      // Purchase Date & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          _buildStatusBadge(purchase.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daftar Barang Restok:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Items List
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, idx) {
                            final row = items[idx];
                            final PurchaseItem item = row['item'];
                            final Product? product = row['product'];
                            final ProductUnit? unit = row['unit'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product?.name ?? 'Produk Tidak Dikenal',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '${CurrencyFormatter.formatQty(item.quantity)} ${unit?.name ?? 'Unit'} x ${CurrencyFormatter.format(item.costPrice)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      // Calculation details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(purchase.subtotal), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      if (purchase.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Diskon', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            Text('- ${CurrencyFormatter.format(purchase.discountAmount)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                          ],
                        ),
                      ],
                      if (purchase.taxAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pajak', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            Text(CurrencyFormatter.format(purchase.taxAmount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          Text(
                            CurrencyFormatter.format(purchase.grandTotal),
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // If pending, show confirm receive button
                      if (purchase.status == 'pending') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                            label: Text('KONFIRMASI PENERIMAAN BARANG', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            onPressed: () {
                              context.read<PurchaseCubit>().confirmReceive(purchase.id);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Penerimaan barang berhasil dikonfirmasi. Stok bertambah!'),
                                  backgroundColor: Color(0xFF059669),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Show delete/cancel button for both pending and received status
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(
                            purchase.status == 'received'
                                ? 'BATALKAN PENERIMAAN / HAPUS'
                                : 'BATALKAN / HAPUS PESANAN',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          onPressed: () async {
                            final confirm = await _showConfirmDeleteDialog(context, purchase.status == 'received');
                            if (confirm == true && context.mounted) {
                              context.read<PurchaseCubit>().deletePurchase(purchase.id);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(purchase.status == 'received'
                                      ? 'Penerimaan berhasil dibatalkan dan stok dikurangi kembali.'
                                      : 'Pesanan pembelian berhasil dihapus.'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final isReceived = status == 'received';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isReceived
            ? const Color(0xFF059669).withValues(alpha: 0.1)
            : const Color(0xFFD97706).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReceived
              ? const Color(0xFF059669).withValues(alpha: 0.3)
              : const Color(0xFFD97706).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isReceived ? 'Diterima' : 'Menunggu',
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isReceived ? const Color(0xFF059669) : const Color(0xFFD97706),
        ),
      ),
    );
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
              'Restok & Pembelian',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kelola pesanan restok barang ke supplier',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: BlocConsumer<PurchaseCubit, PurchaseState>(
        listener: (context, state) {
          if (state is PurchaseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: const Color(0xFFDC2626)),
            );
          }
        },
        builder: (context, state) {
          if (state is PurchaseLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
          }

          if (state is PurchaseLoaded) {
            final allPurchases = state.purchases;
            final filteredPurchases = allPurchases.where((row) {
              final Purchase purchase = row['purchase'];

              if (_selectedSupplierId != null && purchase.supplierId != _selectedSupplierId) {
                return false;
              }

              final compareDate = purchase.createdAt;
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

            return RefreshIndicator(
              color: const Color(0xFF0F172A),
              onRefresh: () async {
                context.read<PurchaseCubit>().loadPurchases();
              },
              child: Column(
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
                              value: _selectedSupplierId,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              hint: Text('Semua Supplier / Pemasok', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Semua Supplier / Pemasok', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                                ),
                                ..._suppliers.map((s) => DropdownMenuItem<int?>(
                                      value: s.id,
                                      child: Text(s.name, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A))),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedSupplierId = val;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredPurchases.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.45,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping_outlined,
                                        size: 36,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tidak ada data pembelian yang sesuai.',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredPurchases.length,
                            itemBuilder: (context, index) {
                              final item = filteredPurchases[index];
                              final Purchase purchase = item['purchase'];
                              final Supplier? supplier = item['supplier'];
                              final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
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
                                child: InkWell(
                                  onTap: () => _showPurchaseDetails(context, purchase.id),
                                  borderRadius: BorderRadius.circular(14),
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
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.receipt_rounded, size: 16, color: Color(0xFF0F172A)),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  purchase.referenceNo,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            _buildStatusBadge(purchase.status),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            const Icon(Icons.storefront_rounded, size: 15, color: Color(0xFF64748B)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                supplier?.name ?? 'Supplier Umum',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              dateStr,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                            Text(
                                              CurrencyFormatter.format(purchase.grandTotal),
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color: const Color(0xFF0F172A),
                                              ),
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
            );
          }

          return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PurchaseFormPage()),
          );
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text(
          'RESTOK BARANG',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.white),
        ),
      ),
    );
  }
}

