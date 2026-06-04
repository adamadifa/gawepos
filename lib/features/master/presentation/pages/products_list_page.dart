import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
import '../bloc/product_cubit.dart';
import '../bloc/category_cubit.dart';
import '../bloc/brand_cubit.dart';
import 'product_form_page.dart';

class ProductsListPage extends StatefulWidget {
  const ProductsListPage({super.key});

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends State<ProductsListPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<ProductCubit>().loadProducts();
    // Load categories & brands to pass down to form page if needed
    context.read<CategoryCubit>().loadCategories();
    context.read<BrandCubit>().loadBrands();
  }

  void _showDeleteDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Apakah Anda yakin ingin menghapus produk "${product.name}" beserta seluruh satuannya?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ProductCubit>().deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
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
                      Text(
                        'Master Produk',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search Input Card
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
                        decoration: const InputDecoration(
                          hintText: 'Cari nama produk, SKU, barcode...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Products List
                Expanded(
                  child: BlocBuilder<ProductCubit, ProductState>(
                    builder: (context, state) {
                      if (state is ProductLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is ProductError) {
                        return Center(child: Text(state.message));
                      }
                      if (state is ProductLoaded) {
                        var list = state.products;

                        // Filter queries
                        if (_searchQuery.isNotEmpty) {
                          list = list.where((item) {
                            final Product product = item['product'];
                            final nameMatch = product.name.toLowerCase().contains(_searchQuery);
                            final skuMatch = product.sku?.toLowerCase().contains(_searchQuery) ?? false;
                            final barcodeMatch = product.barcode?.toLowerCase().contains(_searchQuery) ?? false;
                            return nameMatch || skuMatch || barcodeMatch;
                          }).toList();
                        }

                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              'Belum ada produk.',
                              style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            final Product product = item['product'];
                            final Brand? brand = item['brand'];
                            final Category? category = item['category'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                side: const BorderSide(color: AppConstants.borderLightColor),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppConstants.backgroundColor,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                  ),
                                  child: product.imagePath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                          child: Image.file(
                                            File(product.imagePath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.shopping_bag_outlined,
                                                    color: AppConstants.textLightColor, size: 20),
                                          ),
                                        )
                                      : const Icon(Icons.shopping_bag_outlined,
                                          color: AppConstants.textLightColor, size: 20),
                                ),
                                title: Text(
                                  product.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppConstants.textDarkColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      'SKU: ${product.sku ?? '-'}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppConstants.textLightColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (category != null)
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppConstants.primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              category.name,
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  color: AppConstants.primaryColor,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        if (brand != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppConstants.successColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              brand.name,
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  color: AppConstants.successColor,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: AppConstants.primaryColor.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ProductFormPage(
                                                existingProduct: product,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.edit_outlined,
                                            color: AppConstants.primaryColor,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.redAccent.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _showDeleteDialog(context, product),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 16,
                                          ),
                                        ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('TAMBAH PRODUK'),
      ),
    );
  }
}
