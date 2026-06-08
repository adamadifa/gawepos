import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
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
                          _loadData();
                        }
                      } else {
                        setState(() {
                          _selectedRange = range;
                        });
                        _updateDateRange();
                        _loadData();
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

  Widget _buildSummaryCards(double totalSalesReturn, double totalPurchaseReturn) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.errorColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retur Penjualan',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.errorColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalSalesReturn),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.errorColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.successColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppConstants.successColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retur Pembelian',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.successColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(totalPurchaseReturn),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.successColor),
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
            Icon(Icons.assignment_return_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
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
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final row = list[index];
        final SalesReturn ret = row['return'];
        final Customer? customer = row['customer'];
        final Order? order = row['order'];

        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
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
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: AppConstants.textLightColor),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _copyToClipboard(context, ret.referenceNo, 'No. Retur'),
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(ret.refundAmount),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.errorColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        customer?.name ?? 'Pelanggan Umum',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (ret.refundMethod == 'cash' ? Colors.blue : Colors.purple).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ret.refundMethod == 'cash' ? 'Tunai' : 'Potong Piutang',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: ret.refundMethod == 'cash' ? Colors.blue.shade800 : Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppConstants.borderLightColor),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ref Penjualan: ${order?.referenceNo ?? "Retur Umum"}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                    ],
                  ),
                ],
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
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final row = list[index];
        final PurchaseReturn ret = row['return'];
        final Supplier? supplier = row['supplier'];
        final Purchase? purchase = row['purchase'];

        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
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
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: AppConstants.textLightColor),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _copyToClipboard(context, ret.referenceNo, 'No. Retur'),
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(ret.refundAmount),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        supplier?.name ?? 'Supplier Pemasok',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (ret.refundMethod == 'cash' ? Colors.blue : Colors.orange).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ret.refundMethod == 'cash' ? 'Tunai' : 'Potong Hutang',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: ret.refundMethod == 'cash' ? Colors.blue.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppConstants.borderLightColor),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ref Pembelian: ${purchase?.referenceNo ?? "Retur Umum"}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                      ),
                    ],
                  ),
                ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: getIt<ReturnRepository>().getSalesReturnDetails(id),
          builder: (fbCtx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
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
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rincian Retur Penjualan',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.textDarkColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMetaRowWithCopy(ctx, 'No. Retur', ret.referenceNo),
                    _buildMetaRow('Tanggal', DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt)),
                    _buildMetaRow('Pelanggan', customer?.name ?? 'Pelanggan Umum'),
                    _buildMetaRowWithCopy(ctx, 'No. Invoice Asal', order?.referenceNo ?? 'Retur Umum'),
                    _buildMetaRow('Metode Pengembalian', ret.refundMethod == 'cash' ? 'Tunai (Cash)' : 'Potong Piutang (Bon)'),
                    if (ret.notes != null && ret.notes!.isNotEmpty) _buildMetaRow('Alasan / Catatan', ret.notes!),
                    const Divider(height: 30, color: AppConstants.borderLightColor),
                    Text(
                      'Barang yang Diretur:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.textDarkColor),
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
                                  Text(product?.name ?? 'Produk', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppConstants.textDarkColor)),
                                  Text(
                                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.price)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                  ),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(item.subtotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30, color: AppConstants.borderLightColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Refund', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor)),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.errorColor),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: getIt<ReturnRepository>().getPurchaseReturnDetails(id),
          builder: (fbCtx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
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
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rincian Retur Pembelian',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.textDarkColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMetaRowWithCopy(ctx, 'No. Retur', ret.referenceNo),
                    _buildMetaRow('Tanggal', DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt)),
                    _buildMetaRow('Supplier / Pemasok', supplier?.name ?? 'Pemasok'),
                    _buildMetaRowWithCopy(ctx, 'No. Purchase Order', purchase?.referenceNo ?? 'Retur Umum'),
                    _buildMetaRow('Metode Pengembalian', ret.refundMethod == 'cash' ? 'Tunai (Cash)' : 'Potong Hutang'),
                    if (ret.notes != null && ret.notes!.isNotEmpty) _buildMetaRow('Alasan / Catatan', ret.notes!),
                    const Divider(height: 30, color: AppConstants.borderLightColor),
                    Text(
                      'Barang yang Diretur:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.textDarkColor),
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
                                  Text(product?.name ?? 'Produk', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppConstants.textDarkColor)),
                                  Text(
                                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.costPrice)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                  ),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(item.subtotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30, color: AppConstants.borderLightColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Refund / Potongan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor)),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.successColor),
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
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppConstants.textDarkColor),
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
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppConstants.textDarkColor),
                  ),
                ),
                if (!isNone)
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppConstants.textLightColor),
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
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Retur',
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
              const SizedBox(height: 6),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppConstants.primaryColor,
                  unselectedLabelColor: AppConstants.textLightColor,
                  indicatorColor: AppConstants.primaryColor,
                  labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                  tabs: const [
                    Tab(text: 'Retur Penjualan'),
                    Tab(text: 'Retur Pembelian'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppConstants.borderLightColor),
              Expanded(
                child: state.isReturnsLoading && state.salesReturnsReportData == null
                    ? const Center(child: CircularProgressIndicator())
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
