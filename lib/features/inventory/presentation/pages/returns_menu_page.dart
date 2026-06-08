import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../data/return_repository.dart';
import '../bloc/return_cubit.dart';
import 'return_form_page.dart';

class ReturnsMenuPage extends StatefulWidget {
  const ReturnsMenuPage({super.key});

  @override
  State<ReturnsMenuPage> createState() => _ReturnsMenuPageState();
}

class _ReturnsMenuPageState extends State<ReturnsMenuPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<ReturnCubit>().loadReturnHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Retur Barang',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Retur Penjualan'),
            Tab(text: 'Retur Pembelian'),
          ],
        ),
      ),
      body: BlocListener<ReturnCubit, ReturnState>(
        listener: (context, state) {
          if (state is ReturnSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppConstants.successColor,
              ),
            );
          } else if (state is ReturnError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppConstants.errorColor,
              ),
            );
          }
        },
        child: BlocBuilder<ReturnCubit, ReturnState>(
          builder: (context, state) {
            if (state is ReturnLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ReturnError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(state.message, style: GoogleFonts.poppins(color: AppConstants.errorColor)),
                ),
              );
            }

            if (state is ReturnHistoryLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildSalesReturnsList(state.salesReturns),
                  _buildPurchaseReturnsList(state.purchaseReturns),
                ],
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final returnCubit = context.read<ReturnCubit>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReturnFormPage(
                initialIsSales: _tabController.index == 0,
              ),
            ),
          ).then((value) {
            returnCubit.loadReturnHistory();
          });
        },
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Tambah Retur',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSalesReturnsList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _buildEmptyState('Belum ada riwayat retur penjualan.');
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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            onTap: () => _showSalesReturnDetailsSheet(ret.id),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ret.referenceNo,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(ret.refundAmount),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppConstants.errorColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        customer?.name ?? 'Pelanggan Umum',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textDarkColor, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        ret.refundMethod == 'cash' ? 'Tunai' : 'Potong Piutang',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
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
      return _buildEmptyState('Belum ada riwayat retur pembelian.');
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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            onTap: () => _showPurchaseReturnDetailsSheet(ret.id),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ret.referenceNo,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.teal,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(ret.refundAmount),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppConstants.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        supplier?.name ?? 'Supplier',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textDarkColor, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        ret.refundMethod == 'cash' ? 'Tunai' : 'Potong Hutang',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_return_outlined, size: 64, color: AppConstants.textLightColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(color: AppConstants.textLightColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showSalesReturnDetailsSheet(int id) async {
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
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }

            final data = snapshot.data;
            if (data == null) {
              return const SizedBox(height: 100, child: Center(child: Text('Data tidak ditemukan.')));
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
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rincian Retur Penjualan',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.textDarkColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMetaRow('No. Retur', ret.referenceNo),
                    _buildMetaRow('Tanggal', DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt)),
                    _buildMetaRow('Pelanggan', customer?.name ?? 'Pelanggan Umum'),
                    _buildMetaRow('No. Invoice Asal', order?.referenceNo ?? 'Retur Umum'),
                    _buildMetaRow('Metode Pengembalian', ret.refundMethod == 'cash' ? 'Tunai (Cash)' : 'Potong Piutang (Bon)'),
                    if (ret.notes != null && ret.notes!.isNotEmpty) _buildMetaRow('Alasan / Catatan', ret.notes!),
                    const Divider(height: 30),
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
                                  Text(product?.name ?? 'Produk', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(
                                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.price)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                  ),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(item.subtotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Refund', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.errorColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmVoidSalesReturn(this.context, ret);
                        },
                        icon: const Icon(Icons.cancel_outlined, color: AppConstants.errorColor),
                        label: Text(
                          'BATALKAN TRANSAKSI RETUR',
                          style: GoogleFonts.poppins(color: AppConstants.errorColor, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppConstants.errorColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPurchaseReturnDetailsSheet(int id) async {
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
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }

            final data = snapshot.data;
            if (data == null) {
              return const SizedBox(height: 100, child: Center(child: Text('Data tidak ditemukan.')));
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
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rincian Retur Pembelian',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.textDarkColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildMetaRow('No. Retur', ret.referenceNo),
                    _buildMetaRow('Tanggal', DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt)),
                    _buildMetaRow('Supplier / Pemasok', supplier?.name ?? 'Pemasok'),
                    _buildMetaRow('No. Purchase Order', purchase?.referenceNo ?? 'Retur Umum'),
                    _buildMetaRow('Metode Pengembalian', ret.refundMethod == 'cash' ? 'Tunai (Cash)' : 'Potong Hutang'),
                    if (ret.notes != null && ret.notes!.isNotEmpty) _buildMetaRow('Alasan / Catatan', ret.notes!),
                    const Divider(height: 30),
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
                                  Text(product?.name ?? 'Produk', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(
                                    '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.costPrice)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                  ),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.format(item.subtotal), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Refund / Potongan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          CurrencyFormatter.format(ret.refundAmount),
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.successColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmVoidPurchaseReturn(this.context, ret);
                        },
                        icon: const Icon(Icons.cancel_outlined, color: AppConstants.errorColor),
                        label: Text(
                          'BATALKAN TRANSAKSI RETUR',
                          style: GoogleFonts.poppins(color: AppConstants.errorColor, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppConstants.errorColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
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
            width: 140,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textDarkColor, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _confirmVoidSalesReturn(BuildContext context, SalesReturn ret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Batalkan Retur Penjualan?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi retur ${ret.referenceNo}? Tindakan ini akan mengembalikan/mengurangi stok produk ke kondisi semula, dan mengembalikan piutang pelanggan jika sebelumnya dipotong.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ReturnCubit>().voidSalesReturn(ret.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmVoidPurchaseReturn(BuildContext context, PurchaseReturn ret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Batalkan Retur Pembelian?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi retur ${ret.referenceNo}? Tindakan ini akan mengembalikan stok produk ke kondisi semula (menambahkan kembali stok), dan mengembalikan hutang ke supplier jika sebelumnya dipotong.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ReturnCubit>().voidPurchaseReturn(ret.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
