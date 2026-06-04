import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
import '../bloc/inventory_cubit.dart';
import 'stock_card_page.dart';

class StockOpnamePage extends StatefulWidget {
  const StockOpnamePage({super.key});

  @override
  State<StockOpnamePage> createState() => _StockOpnamePageState();
}

class _StockOpnamePageState extends State<StockOpnamePage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<InventoryCubit>().loadInventory();
  }

  void _showAdjustmentDialog(
    BuildContext context, {
    required Product product,
    required ProductUnit unit,
    required double currentStock,
  }) {
    final physicalController = TextEditingController();
    final notesController = TextEditingController();
    double physicalStock = currentStock;
    double difference = 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          title: Text(
            'Sesuaikan Stok (Opname)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Satuan: ${unit.name} | SKU: ${product.sku ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: AppConstants.textLightColor),
                ),
                const Divider(height: 24),
                // Theoretical Stock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Stok Sistem (Teoretis):'),
                    Text(
                      '$currentStock ${unit.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Physical input
                TextField(
                  controller: physicalController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Stok Riil (Fisik) *',
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      physicalStock = double.tryParse(val) ?? 0.0;
                      difference = physicalStock - currentStock;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Calculation of Difference
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: difference == 0
                        ? AppConstants.backgroundColor
                        : difference > 0
                            ? AppConstants.successColor.withValues(alpha: 0.06)
                            : AppConstants.errorColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(
                      color: difference == 0
                          ? AppConstants.borderLightColor
                          : difference > 0
                              ? AppConstants.successColor.withValues(alpha: 0.15)
                              : AppConstants.errorColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selisih Penyesuaian:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        '${difference > 0 ? "+" : ""}$difference ${unit.name}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: difference == 0
                              ? AppConstants.textDarkColor
                              : difference > 0
                                  ? AppConstants.successColor
                                  : AppConstants.errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Notes
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Alasan / Catatan Penyesuaian',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (physicalController.text.trim().isEmpty) return;
                
                context.read<InventoryCubit>().adjustStock(
                  productId: product.id,
                  unitId: unit.id,
                  theoreticalQty: currentStock,
                  physicalQty: physicalStock,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventorySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Berhasil memperbarui stok inventori.')),
            );
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppConstants.errorColor),
            );
          }
        },
        builder: (context, state) {
          List<Map<String, dynamic>> rawItemsList = [];
          if (state is InventoryLoaded) {
            rawItemsList = state.items;
          }

          return Stack(
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
                          Text(
                            'Stok Inventori & Opname',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 4,
                        shadowColor: AppConstants.primaryColor.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Cari nama produk atau SKU...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: rawItemsList.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppConstants.primaryColor),
                                      tooltip: 'Scan Barcode',
                                      onPressed: () => _showBarcodeScanner(rawItemsList),
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inventory list
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (state is InventoryLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state is InventoryLoaded) {
                            var itemsList = state.items;

                            // Terapkan filter pencarian
                            if (_searchQuery.isNotEmpty) {
                              itemsList = itemsList.where((item) {
                                final Product p = item['product'];
                                return p.name.toLowerCase().contains(_searchQuery) ||
                                    (p.sku?.toLowerCase().contains(_searchQuery) ?? false);
                              }).toList();
                            }

                            // Mengelompokkan item berdasarkan ID Produk
                            final Map<int, Map<String, dynamic>> grouped = {};
                            for (var item in itemsList) {
                              final Product p = item['product'];
                              final ProductUnit u = item['unit'];
                              final InventoryData? inv = item['inventory'];

                              if (!grouped.containsKey(p.id)) {
                                grouped[p.id] = {
                                  'product': p,
                                  'units': <Map<String, dynamic>>[],
                                };
                              }
                              (grouped[p.id]!['units'] as List<Map<String, dynamic>>).add({
                                'unit': u,
                                'inventory': inv,
                              });
                            }

                            final groupedList = grouped.values.toList();

                            if (groupedList.isEmpty) {
                              return Center(
                                child: Text(
                                  'Belum ada data stok.',
                                  style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: groupedList.length,
                              itemBuilder: (context, index) {
                                final item = groupedList[index];
                                final Product product = item['product'];
                                final List<Map<String, dynamic>> productUnits = 
                                    List<Map<String, dynamic>>.from(item['units']);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                    side: const BorderSide(color: AppConstants.borderLightColor),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Info Utama Produk
                                        Text(
                                          product.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.textDarkColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (product.sku != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'SKU: ${product.sku}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppConstants.textLightColor,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        const Divider(height: 1, color: AppConstants.borderLightColor),
                                        const SizedBox(height: 12),
                                        
                                        // Daftar Satuan Unit untuk Produk ini
                                        ...productUnits.map((uMap) {
                                          final ProductUnit unit = uMap['unit'];
                                          final InventoryData? inv = uMap['inventory'];
                                          final double currentStock = inv?.quantity ?? 0.0;
                                          final isLowStock = currentStock <= product.minStockAlert;

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Row(
                                              children: [
                                                // Nama Unit & Status Stok
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: isLowStock
                                                                  ? AppConstants.errorColor.withValues(alpha: 0.1)
                                                                  : AppConstants.primaryColor.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              '$currentStock ${unit.name}',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.bold,
                                                                color: isLowStock
                                                                    ? AppConstants.errorColor
                                                                    : AppConstants.primaryColor,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            unit.name,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w500,
                                                              fontSize: 13,
                                                              color: AppConstants.textDarkColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      GestureDetector(
                                                        onTap: () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) => StockCardPage(product: product),
                                                            ),
                                                          );
                                                        },
                                                        child: const Row(
                                                          children: [
                                                            Icon(Icons.history_rounded,
                                                                size: 13, color: AppConstants.primaryColor),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Kartu Stok',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: AppConstants.primaryColor,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Tombol Aksi Opname
                                                ElevatedButton.icon(
                                                  onPressed: () => _showAdjustmentDialog(
                                                    context,
                                                    product: product,
                                                    unit: unit,
                                                    currentStock: currentStock,
                                                  ),
                                                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                                                  label: const Text('OPNAME'),
                                                  style: ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 8),
                                                    minimumSize: Size.zero,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                                    ),
                                                    textStyle: const TextStyle(
                                                        fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
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
          );
        },
      ),
    );
  }

  void _showBarcodeScanner(List<Map<String, dynamic>> itemsList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: AppConstants.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scan Barcode Produk',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final code = barcodes.first.rawValue;
                        if (code != null) {
                          Navigator.pop(ctx);
                          _handleBarcodeScanned(code, itemsList);
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleBarcodeScanned(String barcode, List<Map<String, dynamic>> itemsList) {
    try {
      final match = itemsList.firstWhere(
        (item) {
          final Product p = item['product'];
          return p.barcode == barcode || p.sku == barcode;
        },
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty) {
        final Product product = match['product'];
        final ProductUnit unit = match['unit'];
        final InventoryData? inv = match['inventory'];
        final double currentStock = inv?.quantity ?? 0.0;

        _showAdjustmentDialog(
          context,
          product: product,
          unit: unit,
          currentStock: currentStock,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk dengan barcode/SKU "$barcode" tidak ditemukan di inventori.'),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      // ignore
    }
  }
}
