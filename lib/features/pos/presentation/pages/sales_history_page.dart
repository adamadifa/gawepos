import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
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
          if (customer == null) return false;
          if (!customer.name.toLowerCase().contains(_customerSearchQuery.toLowerCase())) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
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
          const SnackBar(content: Text('Resi berhasil dicetak ulang!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak struk! Pastikan printer bluetooth Anda terhubung dan terkonfigurasi.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _showOrderDetails(Order order) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(16)),
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
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  order.referenceNo,
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: order.referenceNo));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Nomor transaksi berhasil disalin!'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.copy_rounded,
                                      size: 16,
                                      color: AppConstants.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMMM yyyy HH:mm').format(order.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppConstants.textLightColor),
                          ),
                          _buildStatusBadge(order.paymentStatus, order.status),
                        ],
                      ),
                      const Divider(height: 24),
                      if (customer != null) ...[
                        Text('Pelanggan: ${customer.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                      ],
                      if (order.notes != null) ...[
                        Text('Catatan: ${order.notes}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      const Text('Daftar Produk:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product?.name ?? 'Produk Terhapus (ID: ${item.productId})',
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$qtyStr ${unit?.name ?? "Satuan"} x ${CurrencyFormatter.format(item.price)}',
                                        style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(CurrencyFormatter.format(item.subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      // Summary info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppConstants.textLightColor)),
                          Text(CurrencyFormatter.format(order.subtotal), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      if (order.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Diskon Global:', style: TextStyle(fontSize: 12, color: AppConstants.textLightColor)),
                            Text('- ${CurrencyFormatter.format(order.discountAmount)}', style: const TextStyle(fontSize: 12, color: AppConstants.errorColor)),
                          ],
                        ),
                      ],
                      if (order.taxAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pajak:', style: TextStyle(fontSize: 12, color: AppConstants.textLightColor)),
                            Text(CurrencyFormatter.format(order.taxAmount), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Grand Total:', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(CurrencyFormatter.format(order.grandTotal), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
                        ],
                      ),
                      const Divider(height: 24),
                      // Payments info
                      const Text('Pembayaran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Column(
                        children: payments.map((p) {
                          final method = p.paymentMethod == 'cash'
                              ? 'Tunai'
                              : p.paymentMethod == 'qris'
                                  ? 'QRIS'
                                  : p.paymentMethod == 'card'
                                      ? 'EDC/Kartu'
                                      : 'Transfer';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(method, style: const TextStyle(fontSize: 12, color: AppConstants.textLightColor)),
                              Text(CurrencyFormatter.format(p.amount), style: const TextStyle(fontSize: 12)),
                            ],
                          );
                        }).toList(),
                      ),
                      if (order.changeAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kembalian:', style: TextStyle(fontSize: 12, color: AppConstants.textLightColor)),
                            Text(CurrencyFormatter.format(order.changeAmount), style: const TextStyle(fontSize: 12, color: AppConstants.successColor)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _reprint(order.id);
                          },
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('CETAK ULANG STRUK'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      if (order.status != 'void' && session?.status == 'open') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmVoidOrder(order);
                            },
                            icon: const Icon(Icons.cancel_outlined, color: AppConstants.errorColor),
                            label: Text(
                              'BATALKAN TRANSAKSI (VOID)',
                              style: GoogleFonts.poppins(color: AppConstants.errorColor, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppConstants.errorColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
        title: Text(
          'Batalkan Transaksi?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi ${order.referenceNo}? Tindakan ini akan mengembalikan stok produk dan membatalkan laporan omzet/piutang terkait.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
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
                      backgroundColor: AppConstants.successColor,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membatalkan transaksi: $e'),
                      backgroundColor: AppConstants.errorColor,
                    ),
                  );
                }
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? paymentStatus, String orderStatus) {
    if (orderStatus == 'void') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'BATAL / VOID',
          style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      );
    }

    String label = 'LUNAS';
    Color color = AppConstants.successColor;
    
    if (paymentStatus == 'unpaid') {
      label = 'BELUM LUNAS';
      color = AppConstants.errorColor;
    } else if (paymentStatus == 'partial') {
      label = 'BAYAR SEBAGIAN';
      color = AppConstants.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Riwayat Transaksi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  side: const BorderSide(color: AppConstants.borderLightColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _selectDateRange,
                              icon: const Icon(Icons.date_range_rounded, size: 16),
                              label: Text(
                                _startDate == null || _endDate == null
                                    ? 'Pilih Periode'
                                    : '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppConstants.textDarkColor,
                                side: const BorderSide(color: AppConstants.borderLightColor),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                ),
                              ),
                            ),
                          ),
                          if (_startDate != null || _endDate != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppConstants.errorColor),
                              onPressed: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                _applyFilters();
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerSearchController,
                        onChanged: (val) {
                          setState(() {
                            _customerSearchQuery = val;
                          });
                          _applyFilters();
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari Nama Pelanggan...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppConstants.textLightColor),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppConstants.textLightColor),
                          suffixIcon: _customerSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _customerSearchController.clear();
                                    setState(() {
                                      _customerSearchQuery = '';
                                    });
                                    _applyFilters();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            borderSide: const BorderSide(color: AppConstants.borderLightColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            borderSide: const BorderSide(color: AppConstants.borderLightColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                            borderSide: const BorderSide(color: AppConstants.primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada riwayat transaksi.',
                              style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final item = _filteredOrders[index];
                              final customer = _customerMap[item.customerId];
                              final timeStr = DateFormat('HH:mm').format(item.createdAt);
                              final dateStr = DateFormat('dd/MM/yyyy').format(item.createdAt);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                  side: const BorderSide(color: AppConstants.borderLightColor),
                                ),
                                child: ListTile(
                                  onTap: () => _showOrderDetails(item),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.referenceNo,
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () {
                                                    Clipboard.setData(ClipboardData(text: item.referenceNo));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Nomor transaksi berhasil disalin!'),
                                                        duration: Duration(seconds: 1),
                                                      ),
                                                    );
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    child: Icon(
                                                      Icons.copy_rounded,
                                                      size: 13,
                                                      color: AppConstants.textLightColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (customer != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Pelanggan: ${customer.name}',
                                                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor, fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        CurrencyFormatter.format(item.grandTotal),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppConstants.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$dateStr $timeStr',
                                          style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                                        ),
                                        _buildStatusBadge(item.paymentStatus, item.status),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppConstants.textLightColor),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          if (_isPrinting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Mencetak Struk...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
