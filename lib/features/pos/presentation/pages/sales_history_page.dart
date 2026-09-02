import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/di/injection.dart';
import '../../../master/data/master_repository.dart';
import '../../data/sales_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final SalesRepository _salesRepository = getIt<SalesRepository>();
  final PrintService _printService = getIt<PrintService>();
  final MasterRepository _masterRepository = getIt<MasterRepository>();

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  Map<int, Customer> _customerMap = {};

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedRange = 'Semua';
  String _customerSearchQuery = '';
  final TextEditingController _customerSearchController = TextEditingController();
  bool _isLoading = false;
  bool _isPrinting = false;

  @override
  void dispose() {
    _customerSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final customers = await _masterRepository.getCustomers();
      final orders = await _salesRepository.getRecentOrders(limit: 500);
      setState(() {
        _customerMap = {for (var c in customers) c.id: c};
        _allOrders = orders;
      });
      _applyFilters();
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  void _setPeriod(String range) {
    final now = DateTime.now();
    setState(() {
      _selectedRange = range;
      if (range == 'Hari Ini') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (range == '7 Hari') {
        _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (range == 'Bulan Ini') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (range == 'Semua') {
        _startDate = null;
        _endDate = null;
      }
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        if (_startDate != null) {
          final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          if (order.createdAt.isBefore(start)) return false;
        }
        if (_endDate != null) {
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          if (order.createdAt.isAfter(end)) return false;
        }
        if (_customerSearchQuery.isNotEmpty) {
          final customer = _customerMap[order.customerId];
          final refMatch = order.referenceNo.toLowerCase().contains(_customerSearchQuery.toLowerCase());
          final customerMatch = customer != null && customer.name.toLowerCase().contains(_customerSearchQuery.toLowerCase());
          if (!refMatch && !customerMatch) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  Future<void> _selectCustomDateRange() async {
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
        _selectedRange = 'Kustom';
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _applyFilters();
    }
  }

  Future<void> _reprint(int orderId) async {
    setState(() {
      _isPrinting = true;
    });

    final success = await _printService.printOrder(orderId);

    setState(() {
      _isPrinting = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resi berhasil dicetak ulang!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak struk! Pastikan printer bluetooth Anda terhubung.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showOrderDetails(Order order) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
    );

    final details = await _salesRepository.getOrderDetails(order.id);
    if (!mounted) return;
    Navigator.pop(context); // Pop loading

    if (details == null) return;

    final List<Map<String, dynamic>> items = details['items'];
    final List<OrderPayment> payments = details['payments'];
    final Customer? customer = details['customer'];
    final CashierSession? session = details['session'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
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
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                order.referenceNo,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: order.referenceNo));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nomor transaksi berhasil disalin!'),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color: Color(0xFF0F172A),
                                  ),
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
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(order.createdAt),
                            style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                          ),
                          _buildStatusBadge(order.paymentStatus, order.status),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      if (customer != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Pelanggan: ${customer.name}',
                              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (order.notes != null && order.notes!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text('Catatan: ${order.notes}', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text('Rincian Item Penjualan:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      // List items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (ctx, idx) {
                          final itemDetail = items[idx];
                          final OrderItem item = itemDetail['item'];
                          final Product? product = itemDetail['product'];
                          final ProductUnit? unit = itemDetail['unit'];

                          final qtyStr = item.quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

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
                                        product?.name ?? 'Produk (ID: ${item.productId})',
                                        style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$qtyStr ${unit?.name ?? "Pcs"} x ${CurrencyFormatter.format(item.price)}',
                                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.subtotal),
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      // Summary info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(order.subtotal), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      if (order.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Diskon Global', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            Text('- ${CurrencyFormatter.format(order.discountAmount)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                          ],
                        ),
                      ],
                      if (order.taxAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pajak', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            Text(CurrencyFormatter.format(order.taxAmount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Grand Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          Text(
                            CurrencyFormatter.format(order.grandTotal),
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      // Payments info
                      Text('Rincian Pembayaran:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Column(
                        children: payments.map((p) {
                          final method = p.paymentMethod == 'cash'
                              ? 'Tunai (Cash)'
                              : p.paymentMethod == 'qris'
                                  ? 'QRIS'
                                  : p.paymentMethod == 'card'
                                      ? 'EDC / Kartu'
                                      : 'Transfer Bank';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(method, style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
                                Text(CurrencyFormatter.format(p.amount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (order.changeAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Kembalian', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                            Text(CurrencyFormatter.format(order.changeAmount), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _reprint(order.id);
                          },
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: Text('CETAK ULANG STRUK', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (order.status != 'void' && session?.status == 'open') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmVoidOrder(order);
                            },
                            icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                            label: Text(
                              'BATALKAN TRANSAKSI (VOID)',
                              style: GoogleFonts.poppins(color: const Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmVoidOrder(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Batalkan Transaksi?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi ${order.referenceNo}? Tindakan ini akan mengembalikan stok produk dan membatalkan laporan omzet/piutang terkait.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _isLoading = true;
              });
              try {
                await _salesRepository.voidOrder(order.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil dibatalkan (void).'),
                      backgroundColor: Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membatalkan transaksi: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Ya, Batalkan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? paymentStatus, String orderStatus) {
    if (orderStatus == 'void') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(
          'BATAL / VOID',
          style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
      );
    }

    String label = 'LUNAS';
    Color color = const Color(0xFF059669);

    if (paymentStatus == 'unpaid') {
      label = 'BELUM LUNAS';
      color = const Color(0xFFDC2626);
    } else if (paymentStatus == 'partial') {
      label = 'SEBAGIAN';
      color = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: color, fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalSales = _filteredOrders
        .where((o) => o.status != 'void')
        .fold(0.0, (sum, o) => sum + o.grandTotal);

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
              'Riwayat Transaksi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Histori struk penjualan & cetak ulang struk',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFF0F172A),
            onRefresh: _loadData,
            child: Column(
              children: [
                // Filter & Search Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      // Period Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Semua', 'Hari Ini', '7 Hari', 'Bulan Ini', 'Kustom'].map((range) {
                            final isSelected = _selectedRange == range;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: InkWell(
                                onTap: () {
                                  if (range == 'Kustom') {
                                    _selectCustomDateRange();
                                  } else {
                                    _setPeriod(range);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    range,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Search Input
                      TextField(
                        controller: _customerSearchController,
                        onChanged: (val) {
                          setState(() {
                            _customerSearchQuery = val;
                          });
                          _applyFilters();
                        },
                        style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Cari no. struk atau nama pelanggan...',
                          hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _customerSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFFDC2626)),
                                  onPressed: () {
                                    _customerSearchController.clear();
                                    setState(() {
                                      _customerSearchQuery = '';
                                    });
                                    _applyFilters();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Summary Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total ${_filteredOrders.length} Transaksi',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        CurrencyFormatter.format(totalSales),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Transaction List
                Expanded(
                  child: _isLoading && _allOrders.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                      : _filteredOrders.isEmpty
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
                                        child: const Icon(Icons.receipt_long_rounded, size: 36, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tidak ada transaksi yang cocok.',
                                        style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final item = _filteredOrders[index];
                                final customer = _customerMap[item.customerId];
                                final timeStr = DateFormat('HH:mm').format(item.createdAt);
                                final dateStr = DateFormat('dd MMM yyyy').format(item.createdAt);
                                final isVoid = item.status == 'void';

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
                                    onTap: () => _showOrderDetails(item),
                                    borderRadius: BorderRadius.circular(14),
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
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: isVoid
                                                          ? Colors.grey.withValues(alpha: 0.1)
                                                          : const Color(0xFF0F172A).withValues(alpha: 0.06),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      isVoid ? Icons.cancel_outlined : Icons.receipt_rounded,
                                                      size: 16,
                                                      color: isVoid ? Colors.grey : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    item.referenceNo,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13.5,
                                                      color: isVoid ? Colors.grey : const Color(0xFF0F172A),
                                                      decoration: isVoid ? TextDecoration.lineThrough : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              _buildStatusBadge(item.paymentStatus, item.status),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                customer != null ? 'Pelanggan: ${customer.name}' : 'Pelanggan Umum',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                CurrencyFormatter.format(item.grandTotal),
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: isVoid ? Colors.grey : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '$dateStr, $timeStr',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10.5,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Lihat Detail',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF0F172A)),
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
          if (_isPrinting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF0F172A)),
                      const SizedBox(height: 16),
                      Text('Mencetak Struk...', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

