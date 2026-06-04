import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final SalesRepository _salesRepository = getIt<SalesRepository>();
  final PrintService _printService = getIt<PrintService>();

  List<Order> _orders = [];
  bool _isLoading = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await _salesRepository.getRecentOrders();
      setState(() {
        _orders = list;
      });
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
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
                            child: Text(
                              order.referenceNo,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy HH:mm').format(order.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppConstants.textLightColor),
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
                          final Product product = itemDetail['product'];
                          final ProductUnit unit = itemDetail['unit'];

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
                                        product.name,
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$qtyStr ${unit.name} x ${CurrencyFormatter.format(item.price)}',
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat transaksi.',
                        style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final item = _orders[index];
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
                                Text(
                                  item.referenceNo,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppConstants.successColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SELESAI',
                                      style: TextStyle(color: AppConstants.successColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppConstants.textLightColor),
                          ),
                        );
                      },
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
