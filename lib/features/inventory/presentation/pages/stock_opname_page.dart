import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../bloc/inventory_cubit.dart';
import '../../../../core/utils/scan_sound_helper.dart';
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
        child: _ProductAdjustmentDialog(
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
                        'Hasil stok opname berhasil disimpan.',
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
                        'Stok Inventori & Opname',
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
                  child: BlocBuilder<InventoryCubit, InventoryState>(
                    builder: (context, state) {
                      if (state is InventoryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is InventoryLoaded) {
                        var itemsList = state.items;

                        if (_searchQuery.isNotEmpty) {
                          itemsList = itemsList.where((item) {
                            final Product p = item['product'];
                            return p.name.toLowerCase().contains(_searchQuery) ||
                                (p.sku?.toLowerCase().contains(_searchQuery) ?? false);
                          }).toList();
                        }

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
                          return RefreshIndicator(
                            onRefresh: () async {
                              context.read<InventoryCubit>().loadInventory();
                            },
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: Center(
                                    child: Text(
                                      'Belum ada data stok.',
                                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            context.read<InventoryCubit>().loadInventory();
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                            itemCount: groupedList.length,
                            itemBuilder: (context, index) {
                              final item = groupedList[index];
                              final Product product = item['product'];
                              final List<Map<String, dynamic>> productUnits = 
                                  List<Map<String, dynamic>>.from(item['units']);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                              if (product.sku != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'SKU: ${product.sku}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          onPressed: () => _showProductAdjustmentDialog(
                                            context,
                                            product: product,
                                            productUnits: productUnits,
                                          ),
                                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                                          label: const Text('Opname'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F172A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            textStyle: GoogleFonts.poppins(
                                                fontSize: 11.5, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    const SizedBox(height: 12),
                                    
                                    ...productUnits.map((uMap) {
                                      final ProductUnit unit = uMap['unit'];
                                      final InventoryData? inv = uMap['inventory'];
                                      final double currentStock = inv?.quantity ?? 0.0;
                                      final isLowStock = currentStock <= product.minStockAlert;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isLowStock
                                                        ? const Color(0xFFFEF2F2)
                                                        : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isLowStock
                                                          ? const Color(0xFFFECACA)
                                                          : const Color(0xFFE2E8F0),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    unit.name,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: isLowStock
                                                          ? const Color(0xFFDC2626)
                                                          : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '${currentStock % 1 == 0 ? currentStock.toInt() : currentStock.toStringAsFixed(2)} ${unit.name}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => BlocProvider<InventoryCubit>(
                                                          create: (context) => getIt<InventoryCubit>(),
                                                          child: StockCardPage(product: product),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: const Icon(Icons.history_rounded,
                                                      size: 16, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            },
                          ),
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
  final List<Map<String, dynamic>> _sortedProductUnits = [];

  @override
  void initState() {
    super.initState();
    // Copy and sort by conversionFactor descending (largest unit first)
    _sortedProductUnits.addAll(widget.productUnits);
    _sortedProductUnits.sort((a, b) {
      final ProductUnit unitA = a['unit'];
      final ProductUnit unitB = b['unit'];
      return unitB.conversionFactor.compareTo(unitA.conversionFactor);
    });

    for (var uMap in _sortedProductUnits) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        child: const Icon(Icons.edit_note_rounded,
                            color: Color(0xFF0F172A), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Stok Opname Fisik',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
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

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._sortedProductUnits.map((uMap) {
                        final ProductUnit unit = uMap['unit'];
                        final InventoryData? inv = uMap['inventory'];
                        final double currentStock = inv?.quantity ?? 0.0;
                        final double diff = _differences[unit.id] ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          unit.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Stok Sistem: ${currentStock % 1 == 0 ? currentStock.toInt() : currentStock.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Stok Fisik / Riil *',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF334155),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _controllers[unit.id],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            final pStock = double.tryParse(val) ?? 0.0;
                                            setState(() {
                                              _physicalStocks[unit.id] = pStock;
                                              _differences[unit.id] = pStock - currentStock;
                                            });
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
                                          'Selisih',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF334155),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: diff == 0
                                                ? const Color(0xFFF1F5F9)
                                                : diff > 0
                                                    ? const Color(0xFFECFDF5)
                                                    : const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: diff == 0
                                                  ? const Color(0xFFE2E8F0)
                                                  : diff > 0
                                                      ? const Color(0xFFA7F3D0)
                                                      : const Color(0xFFFECACA),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '')}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: diff == 0
                                                  ? const Color(0xFF64748B)
                                                  : diff > 0
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Text(
                        'Alasan / Catatan Penyesuaian (Opsional)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Hasil stock opname akhir bulan...',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
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
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  onPressed: () {
                    final List<Map<String, dynamic>> adjustments = [];
                    for (var uMap in _sortedProductUnits) {
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
                  label: Text(
                    'SIMPAN PERUBAHAN STOK',
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
}

