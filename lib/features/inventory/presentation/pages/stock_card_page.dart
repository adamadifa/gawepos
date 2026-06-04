import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
import '../bloc/inventory_cubit.dart';

class StockCardPage extends StatefulWidget {
  final Product product;
  const StockCardPage({super.key, required this.product});

  @override
  State<StockCardPage> createState() => _StockCardPageState();
}

class _StockCardPageState extends State<StockCardPage> {
  @override
  void initState() {
    super.initState();
    context.read<InventoryCubit>().loadStockCard(widget.product.id);
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'sale':
        return AppConstants.errorColor; // Penjualan (Stok Keluar)
      case 'purchase':
        return AppConstants.successColor; // Pembelian (Stok Masuk)
      case 'opname':
        return AppConstants.primaryColor; // Penyesuaian
      default:
        return AppConstants.textLightColor;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'sale':
        return 'Penjualan';
      case 'purchase':
        return 'Pembelian';
      case 'opname':
        return 'Opname (Penyesuaian)';
      case 'void':
        return 'Batal Transaksi';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'sale':
        return Icons.call_made_rounded;
      case 'purchase':
        return Icons.call_received_rounded;
      case 'opname':
        return Icons.tune_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          const CurvedHeader(height: 155),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kartu Stok Barang',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Movements list
                Expanded(
                  child: BlocBuilder<InventoryCubit, InventoryState>(
                    builder: (context, state) {
                      if (state is InventoryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is InventoryError) {
                        return Center(child: Text(state.message));
                      }
                      if (state is StockCardLoaded) {
                        final list = state.movements;

                        if (list.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.history_rounded,
                                      size: 48, color: AppConstants.textLightColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Belum ada riwayat mutasi stok untuk produk ini.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                        color: AppConstants.textLightColor, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final StockMovement move = item['movement'];
                            final ProductUnit unit = item['unit'];
                            final color = _getTypeColor(move.type);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                side: const BorderSide(color: AppConstants.borderLightColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Colored icon circle indicator
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(_getTypeIcon(move.type), color: color, size: 18),
                                    ),
                                    const SizedBox(width: 14),
                                    // Details column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _getTypeLabel(move.type),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: color,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                move.createdAt.toString().substring(0, 16),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppConstants.textLightColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (move.notes != null)
                                            Text(
                                              move.notes!,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppConstants.textDarkColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          if (move.referenceNo != null)
                                            Text(
                                              'Reff: ${move.referenceNo!}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppConstants.textLightColor),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Qty diff indicator
                                    Text(
                                      '${move.quantity > 0 ? "+" : ""}${move.quantity} ${unit.name}',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
