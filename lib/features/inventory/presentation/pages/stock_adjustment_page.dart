import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<InventoryCubit, InventoryState>(
        listener: (context, state) {
          if (state is InventorySuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Penyesuaian stok berhasil disimpan.',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF0F172A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.message,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        builder: (context, state) {
          List<Map<String, dynamic>> rawItemsList = [];
          if (state is InventoryLoaded) {
            rawItemsList = state.items;
          }

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clean Executive Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF0F172A), size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Stok Masuk / Keluar',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: const Color(0xFFE2E8F0)),

                // Search Bar Clean
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Cari nama produk / scan barcode...',
                              hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showBarcodeScanner(rawItemsList),
                          child: const Padding(
                            padding: EdgeInsets.all(11),
                            child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content List
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state is InventoryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is InventoryLoaded) {
                        if (state.items.isEmpty) {
                          return Center(
                            child: Text(
                              'Belum ada data stok.',
                              style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                            ),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async {
                            context.read<InventoryCubit>().loadInventory();
                          },
                          child: _buildProductList(state.items),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _showAdjustmentDialog(context, product: product, productUnits: units),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: Color(0xFF0F172A), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (product.sku != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${product.sku}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: units.map((u) {
                        final ProductUnit unit = u['unit'];
                        final InventoryData? inv = u['inventory'];
                        final qty = inv?.quantity ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '${qty % 1 == 0 ? qty.toInt() : qty.toStringAsFixed(2)} ${unit.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF94A3B8), size: 14),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.sync_alt_rounded,
                            color: Color(0xFF0F172A), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Penyesuaian Stok',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info Box Produk
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (widget.product.sku != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${widget.product.sku}',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Segmented Toggle: Stok Masuk / Stok Keluar
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton('Stok Masuk', Icons.arrow_downward_rounded, true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildToggleButton('Stok Keluar', Icons.arrow_upward_rounded, false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pilih Satuan & Stok Saat ini Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Satuan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          value: _selectedUnitId,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          items: widget.productUnits.map((u) {
                            final unit = u['unit'] as ProductUnit;
                            return DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedUnitId = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stok Sistem',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${currentStock % 1 == 0 ? currentStock.toInt() : currentStock.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Jumlah
              Text(
                'Jumlah Perubahan *',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                controller: _quantityController,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: '0',
                  prefixIcon: const Icon(Icons.numbers_rounded, size: 18, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Catatan
              Text(
                'Alasan / Catatan (Opsional)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Contoh: Barang rusak, retur pemasok, bonus vendor...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(_isAddition ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isAddition ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: Text(
                    _isAddition ? 'TAMBAHKAN STOK MASUK' : 'POTONG STOK KELUAR',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, IconData icon, bool isAddition) {
    final isSelected = _isAddition == isAddition;
    final activeColor = isAddition ? const Color(0xFF059669) : const Color(0xFFDC2626);
    return InkWell(
      onTap: () => setState(() => _isAddition = isAddition),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
