import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/app_database.dart';
import '../../data/purchase_repository.dart';
import '../bloc/purchase_cubit.dart';
import 'purchase_form_page.dart';

class PurchasesListPage extends StatefulWidget {
  const PurchasesListPage({super.key});

  @override
  State<PurchasesListPage> createState() => _PurchasesListPageState();
}

class _PurchasesListPageState extends State<PurchasesListPage> {
  @override
  void initState() {
    super.initState();
    context.read<PurchaseCubit>().loadPurchases();
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: getIt<PurchaseRepository>().getPurchaseDetails(purchaseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Gagal memuat rincian pembelian.',
                      style: GoogleFonts.poppins(color: AppConstants.errorColor),
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
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.textDarkColor,
                                ),
                              ),
                              Text(
                                supplier?.name ?? 'Supplier Umum',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppConstants.textLightColor,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Purchase Date & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppConstants.textLightColor,
                            ),
                          ),
                          _buildStatusBadge(purchase.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daftar Barang Restok:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppConstants.textDarkColor,
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

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppConstants.textDarkColor,
                                          ),
                                        ),
                                        Text(
                                          '${CurrencyFormatter.formatQty(item.quantity)} ${unit?.name ?? 'Unit'} x ${CurrencyFormatter.format(item.costPrice)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppConstants.textLightColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.textDarkColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 24),
                      // Calculation details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
                          Text(CurrencyFormatter.format(purchase.subtotal), style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textDarkColor)),
                        ],
                      ),
                      if (purchase.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Diskon', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
                            Text('- ${CurrencyFormatter.format(purchase.discountAmount)}', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.errorColor)),
                          ],
                        ),
                      ],
                      if (purchase.taxAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pajak', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
                            Text(CurrencyFormatter.format(purchase.taxAmount), style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textDarkColor)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor)),
                          Text(
                            CurrencyFormatter.format(purchase.grandTotal),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // If pending, show confirm receive button
                      if (purchase.status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.successColor,
                            ),
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                            label: const Text('KONFIRMASI PENERIMAAN BARANG'),
                            onPressed: () {
                              context.read<PurchaseCubit>().confirmReceive(purchase.id);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Penerimaan barang berhasil dikonfirmasi. Stok bertambah!'),
                                  backgroundColor: AppConstants.successColor,
                                ),
                              );
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
            ? AppConstants.successColor.withOpacity(0.12)
            : AppConstants.warningColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReceived
              ? AppConstants.successColor.withOpacity(0.3)
              : AppConstants.warningColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        isReceived ? 'Diterima' : 'Menunggu',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isReceived ? AppConstants.successColor : AppConstants.warningColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Restok & Pembelian',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textDarkColor,
      ),
      body: BlocConsumer<PurchaseCubit, PurchaseState>(
        listener: (context, state) {
          if (state is PurchaseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppConstants.errorColor),
            );
          }
        },
        builder: (context, state) {
          if (state is PurchaseLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PurchaseLoaded) {
            final list = state.purchases;

            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 64,
                      color: AppConstants.textLightColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada pembelian restok.',
                      style: GoogleFonts.poppins(
                        color: AppConstants.textLightColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final Purchase purchase = item['purchase'];
                final Supplier? supplier = item['supplier'];
                final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    side: const BorderSide(color: AppConstants.borderLightColor),
                  ),
                  child: InkWell(
                    onTap: () => _showPurchaseDetails(context, purchase.id),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                purchase.referenceNo,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppConstants.textDarkColor,
                                ),
                              ),
                              _buildStatusBadge(purchase.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            supplier?.name ?? 'Supplier Umum',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.textDarkColor.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppConstants.borderLightColor),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppConstants.textLightColor,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(purchase.grandTotal),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppConstants.primaryColor,
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
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PurchaseFormPage()),
          );
        },
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'RESTOK BARANG',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
