import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
import '../bloc/inventory_cubit.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/utils/scan_sound_helper.dart';

class StockAdjustmentPage extends StatefulWidget {
  const StockAdjustmentPage({super.key});

  @override
  State<StockAdjustmentPage> createState() => _StockAdjustmentPageState();
}

class _StockAdjustmentPageState extends State<StockAdjustmentPage> {
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

  void _showAdjustmentDialog(
    BuildContext context, {
    required Product product,
    required List<Map<String, dynamic>> productUnits,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMd)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _ManualAdjustmentDialog(
          product: product,
          productUnits: productUnits,
          cubit: context.read<InventoryCubit>(),
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
              const SnackBar(content: Text('Berhasil menyesuaikan stok.')),
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
                            'Stok Masuk / Keluar',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

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

                                    _showAdjustmentDialog(
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

                    Expanded(
                      child: rawItemsList.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : _buildProductList(rawItemsList),
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
          child: SafeArea(
            top: false,
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
                            ScanSoundHelper.playBeep();
                            HapticFeedback.lightImpact();
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
        ),
        );
      },
    ).then((code) async {
      if (code != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _handleBarcodeScanned(code, itemsList);
        }
      }
    });
  }

  void _handleBarcodeScanned(String barcode, List<Map<String, dynamic>> itemsList) {
    try {
      Map<String, dynamic>? match;
      for (var item in itemsList) {
        final Product p = item['product'];
        if (p.barcode?.trim().toLowerCase() == barcode.trim().toLowerCase() ||
            p.sku?.trim().toLowerCase() == barcode.trim().toLowerCase()) {
          match = item;
          break;
        }
      }

      if (match != null && match.isNotEmpty) {
        final Product product = match['product'];
        
        final productUnits = itemsList.where((item) {
          return (item['product'] as Product).id == product.id;
        }).toList();

        _showAdjustmentDialog(
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
    } catch (e, stack) {
      debugPrint('Error _handleBarcodeScanned: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }

  Widget _buildProductList(List<Map<String, dynamic>> items) {
    final filtered = items.where((item) {
      final Product p = item['product'];
      final query = _searchQuery;
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          (p.sku?.toLowerCase().contains(query) ?? false) ||
          (p.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();

    // Group by product
    final productIds = filtered.map((e) => (e['product'] as Product).id).toSet();
    final List<Map<String, dynamic>> grouped = productIds.map((pid) {
      final productItems = filtered.where((e) => (e['product'] as Product).id == pid).toList();
      return <String, dynamic>{
        'product': productItems.first['product'] as Product,
        'units': productItems,
      };
    }).toList();

    grouped.sort((a, b) {
      final pa = a['product'] as Product;
      final pb = b['product'] as Product;
      return pa.name.compareTo(pb.name);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        final Product product = group['product'];
        final List<Map<String, dynamic>> units = group['units'];
        return _buildProductCard(product, units);
      },
    );
  }

  Widget _buildProductCard(Product product, List<Map<String, dynamic>> units) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: const BorderSide(color: AppConstants.borderLightColor),
      ),
      child: InkWell(
        onTap: () => _showAdjustmentDialog(context, product: product, productUnits: units),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppConstants.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppConstants.textDarkColor,
                      ),
                    ),
                    if (product.sku != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${product.sku}',
                        style: const TextStyle(
                            fontSize: 11, color: AppConstants.textLightColor),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: units.map((u) {
                        final ProductUnit unit = u['unit'];
                        final InventoryData? inv = u['inventory'];
                        final qty = inv?.quantity ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$qty ${unit.name}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.warningColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppConstants.textLightColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualAdjustmentDialog extends StatefulWidget {
  final Product product;
  final List<Map<String, dynamic>> productUnits;
  final InventoryCubit cubit;

  const _ManualAdjustmentDialog({
    required this.product,
    required this.productUnits,
    required this.cubit,
  });

  @override
  State<_ManualAdjustmentDialog> createState() => _ManualAdjustmentDialogState();
}

class _ManualAdjustmentDialogState extends State<_ManualAdjustmentDialog> {
  bool _isAddition = true;
  int _selectedUnitId = 0;
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.productUnits.isNotEmpty) {
      _selectedUnitId = (widget.productUnits.first['unit'] as ProductUnit).id;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text) ?? 0;

  void _submit() {
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah harus lebih dari 0'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }
    Navigator.pop(context);
    widget.cubit.adjustStockManual(
      productId: widget.product.id,
      unitId: _selectedUnitId,
      quantity: _quantity,
      isAddition: _isAddition,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    double currentStock = 0.0;
    for (var u in widget.productUnits) {
      if ((u['unit'] as ProductUnit).id == _selectedUnitId) {
        currentStock = (u['inventory'] as InventoryData?)?.quantity ?? 0;
        break;
      }
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              widget.product.name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppConstants.textDarkColor,
              ),
            ),
            if (widget.product.sku != null)
              Text(
                'SKU: ${widget.product.sku}',
                style: const TextStyle(fontSize: 12, color: AppConstants.textLightColor),
              ),
            const SizedBox(height: 20),

            // Tipe: Masuk / Keluar
            Row(
              children: [
                Expanded(
                  child: _buildToggleButton('Stok Masuk', true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton('Stok Keluar', false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pilih Satuan
            Text(
              'Pilih Satuan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppConstants.textDarkColor,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _selectedUnitId,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
              items: widget.productUnits.map((u) {
                final unit = u['unit'] as ProductUnit;
                final inv = u['inventory'] as InventoryData?;
                return DropdownMenuItem(
                  value: unit.id,
                  child: Text('${unit.name} (stok: ${inv?.quantity ?? 0})',
                      style: GoogleFonts.poppins(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedUnitId = val);
              },
            ),
            const SizedBox(height: 16),

            // Stok saat ini
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppConstants.warningColor),
                  const SizedBox(width: 8),
                  Text(
                    'Stok saat ini: $currentStock',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppConstants.warningColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Jumlah
            Text(
              'Jumlah',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppConstants.textDarkColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              keyboardType: TextInputType.number,
              controller: _quantityController,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Catatan
            Text(
              'Catatan (opsional)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppConstants.textDarkColor,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
                hintText: 'Contoh: Stok awal, barang sample, dll.',
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('BATAL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAddition ? AppConstants.successColor : AppConstants.errorColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isAddition ? 'TAMBAH' : 'KURANGI'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isAddition) {
    final isSelected = _isAddition == isAddition;
    return InkWell(
      onTap: () => setState(() => _isAddition = isAddition),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAddition ? AppConstants.successColor : AppConstants.errorColor)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? Colors.white : AppConstants.textDarkColor,
            ),
          ),
        ),
      ),
    );
  }
}
