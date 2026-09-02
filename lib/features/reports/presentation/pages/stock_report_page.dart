import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../inventory/presentation/bloc/inventory_cubit.dart';
import '../../../inventory/presentation/pages/stock_card_page.dart';

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan & Kartu Stok',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kuantitas stok real-time & mutasi barang',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Cari nama produk...',
                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                ),
              ),
            ),
          ),
          // Info header ringkasan
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state is InventoryLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                }
                if (state is InventoryError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        state.message,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFDC2626)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (state is InventoryLoaded) {
                  var filteredList = state.items;
                  if (_searchQuery.isNotEmpty) {
                    filteredList = filteredList.where((item) {
                      final Product product = item['product'];
                      return product.name.toLowerCase().contains(_searchQuery);
                    }).toList();
                  }

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada produk yang cocok.',
                            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  // Group items by product ID
                  final Map<int, List<Map<String, dynamic>>> groupedItems = {};
                  for (var item in filteredList) {
                    final Product product = item['product'];
                    groupedItems.putIfAbsent(product.id, () => []).add(item);
                  }
                  final groupedKeys = groupedItems.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groupedKeys.length,
                    itemBuilder: (context, index) {
                      final productId = groupedKeys[index];
                      final productItems = groupedItems[productId]!;
                      final Product product = productItems.first['product'];

                      // Find the unit with the largest conversionFactor
                      ProductUnit largestUnit = productItems.first['unit'];
                      for (var item in productItems) {
                        final ProductUnit unit = item['unit'];
                        if (unit.conversionFactor > largestUnit.conversionFactor) {
                          largestUnit = unit;
                        }
                      }

                      // Check if total stock (converted to largest unit) is low
                      double totalBaseQty = 0.0;
                      for (var item in productItems) {
                        final ProductUnit unit = item['unit'];
                        final dynamic inv = item['inventory'];
                        final double qty = (inv?.quantity as num?)?.toDouble() ?? 0.0;
                        totalBaseQty += qty * unit.conversionFactor;
                      }
                      final double totalLargestQty = totalBaseQty / largestUnit.conversionFactor;
                      final isLowStock = product.isStockManaged && totalLargestQty <= product.minStockAlert;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isLowStock
                                ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () {
                              // Buka Kartu Stok Detail dengan instance Cubit lokal terisolasi
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
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isLowStock
                                          ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                                          : const Color(0xFF0F172A).withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: product.imagePath != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.file(
                                              File(product.imagePath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Icon(
                                                    Icons.inventory_2_rounded,
                                                    color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                                    size: 20,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.inventory_2_rounded,
                                            color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                            size: 20,
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        if (product.isStockManaged)
                                          Text(
                                            'Limit Min: ${product.minStockAlert}',
                                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                          ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Lihat Kartu Stok',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF0F172A)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ...productItems.map((item) {
                                        final ProductUnit unit = item['unit'];
                                        final dynamic inv = item['inventory'];
                                        final double qty = (inv?.quantity as num?)?.toDouble() ?? 0.0;
                                        final qtyStr = qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
                                        
                                        final unitLow = product.isStockManaged && qty <= product.minStockAlert;

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Text(
                                            '$qtyStr ${unit.name}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: unitLow ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (isLowStock && product.isStockManaged)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Stok Menipis',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}

