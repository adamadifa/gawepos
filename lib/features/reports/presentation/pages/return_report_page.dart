import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../inventory/data/return_repository.dart';
import '../bloc/reports_cubit.dart';

class ReturnReportPage extends StatefulWidget {
  const ReturnReportPage({super.key});

  @override
  State<ReturnReportPage> createState() => _ReturnReportPageState();
}

class _ReturnReportPageState extends State<ReturnReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateDateRange();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<ReportsCubit>().loadReturnsReport(_startDate, _endDate);
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

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke papan klip'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periode Laporan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Kustom'].map((range) {
              final isSelected = _selectedRange == range;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
                            _selectedRange = 'Kustom';
                            _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
                            _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                          });
                          _loadData();
                        }
                      } else {
                        setState(() {
                          _selectedRange = range;
                          _updateDateRange();
                          _loadData();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          range,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
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

  Widget _buildSummaryCards(double totalSalesReturn, double totalPurchaseReturn) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_received_rounded, size: 14, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Retur Penjualan',
                        style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFFDC2626), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(totalSalesReturn),
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_made_rounded, size: 14, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Retur Pembelian',
                        style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF059669), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(totalPurchaseReturn),
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horizontal_circle_outlined, size: 36, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesReturnsList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _buildEmptyState('Belum ada transaksi retur penjualan di periode ini.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final row = list[index];
        final SalesReturn ret = row['return'];
        final Customer? customer = row['customer'];
        final Order? order = row['order'];

        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt);

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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showSalesReturnDetailsSheet(ret.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              ret.referenceNo,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _copyToClipboard(context, ret.referenceNo, 'No. Retur'),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          customer?.name ?? 'Pelanggan Umum',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ret.refundMethod == 'cash' ? 'Tunai' : 'Potong Piutang',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ref Penjualan: ${order?.referenceNo ?? "Retur Umum"}',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseReturnsList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _buildEmptyState('Belum ada transaksi retur pembelian di periode ini.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final row = list[index];
        final PurchaseReturn ret = row['return'];
        final Supplier? supplier = row['supplier'];
        final Purchase? purchase = row['purchase'];

        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt);

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
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showPurchaseReturnDetailsSheet(ret.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              ret.referenceNo,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _copyToClipboard(context, ret.referenceNo, 'No. Retur'),
                            ),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          supplier?.name ?? 'Supplier Pemasok',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ret.refundMethod == 'cash' ? 'Tunai' : 'Potong Hutang',
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ref Pembelian: ${purchase?.referenceNo ?? "Retur Umum"}',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSalesReturnDetailsSheet(int id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: getIt<ReturnRepository>().getSalesReturnDetails(id),
          builder: (fbCtx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))));
            }

            final data = snapshot.data;
            if (data == null) {
              return const SizedBox(height: 150, child: Center(child: Text('Detail retur tidak ditemukan.')));
            }

            final SalesReturn ret = data['return'];
            final Customer? customer = data['customer'];
            final Order? order = data['order'];
            final List<Map<String, dynamic>> items = data['items'];

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rincian Retur Penjualan',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMetaRowWithCopy(ctx, 'No. Retur', ret.referenceNo),
                    _buildMetaRow('Tanggal', DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt)),
                    _buildMetaRow('Pelanggan', customer?.name ?? 'Pelanggan Umum'),
                    _buildMetaRowWithCopy(ctx, 'No. Invoice Asal', order?.referenceNo ?? 'Retur Umum'),
                    _buildMetaRow('Metode Pengembalian', ret.refundMethod == 'cash' ? 'Tunai (Cash)' : 'Potong Piutang (Bon)'),
                    if (ret.notes != null && ret.notes!.isNotEmpty) _buildMetaRow('Alasan / Catatan', ret.notes!),
                    const Divider(height: 30, color: Color(0xFFE2E8F0)),
                    Text(
                      'Barang yang Diretur:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    ...items.map((itemRow) {
                      final SalesReturnItem item = itemRow['item'];
                      final Product? product = itemRow['product'];
                      final ProductUnit? unit = itemRow['unit'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product?.name ?? 'Produk', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  Text(
                                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.price)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(item.subtotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Refund', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPurchaseReturnDetailsSheet(int id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: getIt<ReturnRepository>().getPurchaseReturnDetails(id),
          builder: (fbCtx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))));
            }

            final data = snapshot.data;
            if (data == null) {
              return const SizedBox(height: 150, child: Center(child: Text('Detail retur tidak ditemukan.')));
            }

            final PurchaseReturn ret = data['return'];
            final Supplier? supplier = data['supplier'];
            final Purchase? purchase = data['purchase'];
            final List<Map<String, dynamic>> items = data['items'];

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rincian Retur Pembelian',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMetaRowWithCopy(ctx, 'No. Retur', ret.referenceNo),
                    _buildMetaRow('Tanggal', DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt)),
                    _buildMetaRow('Supplier', supplier?.name ?? 'Supplier Pemasok'),
                    _buildMetaRowWithCopy(ctx, 'No. PO Asal', purchase?.referenceNo ?? 'Retur Umum'),
                    _buildMetaRow('Metode Pengembalian', ret.refundMethod == 'cash' ? 'Tunai (Cash)' : 'Potong Hutang (Kredit)'),
                    if (ret.notes != null && ret.notes!.isNotEmpty) _buildMetaRow('Alasan / Catatan', ret.notes!),
                    const Divider(height: 30, color: Color(0xFFE2E8F0)),
                    Text(
                      'Barang yang Diretur:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    ...items.map((itemRow) {
                      final PurchaseReturnItem item = itemRow['item'];
                      final Product? product = itemRow['product'];
                      final ProductUnit? unit = itemRow['unit'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product?.name ?? 'Produk', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  Text(
                                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.costPrice)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(item.subtotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Refund / Potongan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRowWithCopy(BuildContext context, String label, String value) {
    final isNone = value == 'Retur Umum' || value == '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
                  ),
                ),
                if (!isNone)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyToClipboard(context, value, label),
                  ),
              ],
            ),
          ),
        ],
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
              'Laporan Retur',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Pengembalian penjualan & retur pembelian',
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
          final salesList = state.salesReturnsReportData ?? [];
          final purchaseList = state.purchaseReturnsReportData ?? [];

          double totalSalesReturn = 0.0;
          for (var item in salesList) {
            final SalesReturn r = item['return'];
            totalSalesReturn += r.refundAmount;
          }

          double totalPurchaseReturn = 0.0;
          for (var item in purchaseList) {
            final PurchaseReturn r = item['return'];
            totalPurchaseReturn += r.refundAmount;
          }

          return Column(
            children: [
              _buildPeriodFilter(),
              _buildSummaryCards(totalSalesReturn, totalPurchaseReturn),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Container(
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
                    labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Retur Penjualan'),
                      Tab(text: 'Retur Pembelian'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: state.isReturnsLoading && state.salesReturnsReportData == null
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSalesReturnsList(salesList),
                          _buildPurchaseReturnsList(purchaseList),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
