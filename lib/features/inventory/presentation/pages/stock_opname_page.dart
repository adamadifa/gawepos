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
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<InventoryCubit>().loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showProductAdjustmentDialog(
    BuildContext context, {
    required Product product,
    required List<Map<String, dynamic>> productUnits,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductAdjustmentDialog(
        product: product,
        productUnits: productUnits,
        cubit: context.read<InventoryCubit>(),
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
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                            onSubmitted: (val) {
                              final query = val.trim().toLowerCase();
                              if (query.isNotEmpty) {
                                try {
                                  final match = rawItemsList.firstWhere(
                                    (item) {
                                      final Product p = item['product'];
                                      return p.barcode?.toLowerCase() == query || p.sku?.toLowerCase() == query;
                                    },
                                    orElse: () => <String, dynamic>{},
                                  );

                                  if (match.isNotEmpty) {
                                    final Product product = match['product'];
                                    final productUnits = rawItemsList.where((item) {
                                      return (item['product'] as Product).id == product.id;
                                    }).toList();

                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });

                                    _showProductAdjustmentDialog(
                                      context,
                                      product: product,
                                      productUnits: productUnits,
                                    );
                                  }
                                } catch (e) {
                                  // ignore
                                }
                              }
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
                                        // Info Utama Produk & Tombol Opname Produk
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
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
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () => _showProductAdjustmentDialog(
                                                context,
                                                product: product,
                                                productUnits: productUnits,
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
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Nama Unit & Status Stok
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
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool scanned = false;
        return Container(
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
                        if (scanned) return;
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null) {
                            scanned = true;
                            Navigator.pop(ctx, code);
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
        );
      },
    ).then((code) {
      if (code != null && mounted) {
        _handleBarcodeScanned(code, itemsList);
      }
    });
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
        
        final productUnits = itemsList.where((item) {
          return (item['product'] as Product).id == product.id;
        }).toList();

        _showProductAdjustmentDialog(
          context,
          product: product,
          productUnits: productUnits,
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

class _ProductAdjustmentDialog extends StatefulWidget {
  final Product product;
  final List<Map<String, dynamic>> productUnits;
  final InventoryCubit cubit;

  const _ProductAdjustmentDialog({
    required this.product,
    required this.productUnits,
    required this.cubit,
  });

  @override
  State<_ProductAdjustmentDialog> createState() => _ProductAdjustmentDialogState();
}

class _ProductAdjustmentDialogState extends State<_ProductAdjustmentDialog> {
  final _notesController = TextEditingController();
  final Map<int, double> _physicalStocks = {};
  final Map<int, double> _differences = {};
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var uMap in widget.productUnits) {
      final ProductUnit unit = uMap['unit'];
      final InventoryData? inv = uMap['inventory'];
      final double currentStock = inv?.quantity ?? 0.0;
      
      _physicalStocks[unit.id] = currentStock;
      _differences[unit.id] = 0.0;
      _controllers[unit.id] = TextEditingController(text: currentStock.toString().replaceAll(RegExp(r'\.?0+$'), ''));
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      title: Text(
        'Sesuaikan Stok (Opname)',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.product.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.textDarkColor),
              ),
              if (widget.product.sku != null)
                Text(
                  'SKU: ${widget.product.sku}',
                  style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                ),
              const Divider(height: 24),
              ...widget.productUnits.map((uMap) {
                final ProductUnit unit = uMap['unit'];
                final InventoryData? inv = uMap['inventory'];
                final double currentStock = inv?.quantity ?? 0.0;
                final double diff = _differences[unit.id] ?? 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Satuan: ${unit.name}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: AppConstants.textDarkColor),
                        ),
                        Text(
                          'Stok Sistem: $currentStock',
                          style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _controllers[unit.id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Stok Riil (Fisik) *',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) {
                              final pStock = double.tryParse(val) ?? 0.0;
                              setState(() {
                                _physicalStocks[unit.id] = pStock;
                                _differences[unit.id] = pStock - currentStock;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            decoration: BoxDecoration(
                              color: diff == 0
                                  ? AppConstants.backgroundColor
                                  : diff > 0
                                      ? AppConstants.successColor.withValues(alpha: 0.06)
                                      : AppConstants.errorColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                              border: Border.all(
                                color: diff == 0
                                    ? AppConstants.borderLightColor
                                    : diff > 0
                                        ? AppConstants.successColor.withValues(alpha: 0.15)
                                        : AppConstants.errorColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '')}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: diff == 0
                                      ? AppConstants.textDarkColor
                                      : diff > 0
                                          ? AppConstants.successColor
                                          : AppConstants.errorColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Alasan / Catatan Penyesuaian',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: () {
            final List<Map<String, dynamic>> adjustments = [];
            for (var uMap in widget.productUnits) {
              final ProductUnit unit = uMap['unit'];
              final InventoryData? inv = uMap['inventory'];
              final double currentStock = inv?.quantity ?? 0.0;
              final double pStock = _physicalStocks[unit.id] ?? currentStock;
              final diff = pStock - currentStock;

              if (diff != 0) {
                adjustments.add({
                  'unitId': unit.id,
                  'theoreticalQty': currentStock,
                  'physicalQty': pStock,
                });
              }
            }

            final notes = _notesController.text.trim();

            if (adjustments.isEmpty) {
              Navigator.pop(context);
              return;
            }

            widget.cubit.adjustStockMultiple(
              productId: widget.product.id,
              adjustments: adjustments,
              notes: notes.isEmpty ? null : notes,
            );
            Navigator.pop(context);
          },
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}

