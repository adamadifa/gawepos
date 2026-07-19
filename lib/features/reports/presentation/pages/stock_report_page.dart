import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
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
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan & Kartu Stok',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari nama produk...',
                prefixIcon: const Icon(Icons.search, color: AppConstants.textLightColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppConstants.primaryColor),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Info header ringkasan
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state is InventoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is InventoryError) {
                  return Center(child: Text(state.message));
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
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada produk yang cocok.',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
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
                    padding: const EdgeInsets.all(12),
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppConstants.borderLightColor),
                        ),
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
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isLowStock
                                        ? AppConstants.errorColor.withValues(alpha: 0.08)
                                        : AppConstants.primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: product.imagePath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(product.imagePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.inventory_2_rounded,
                                                  color: isLowStock ? AppConstants.errorColor : AppConstants.primaryColor,
                                                ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.inventory_2_rounded,
                                          color: isLowStock ? AppConstants.errorColor : AppConstants.primaryColor,
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.textDarkColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (product.isStockManaged)
                                        Text(
                                          'Limit Min: ${product.minStockAlert}',
                                          style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
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
                                            fontWeight: FontWeight.bold,
                                            color: unitLow ? AppConstants.errorColor : AppConstants.textDarkColor,
                                          ),
                                        ),
                                      );
                                    }),
                                    if (isLowStock && product.isStockManaged)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppConstants.errorColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Stok Menipis',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.errorColor,
                                          ),
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
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
