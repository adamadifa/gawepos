import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
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

  void _showAppSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Hapus Produk',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus produk "${product.name}" beserta seluruh satuan dan harganya?',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductCubit>().deleteProduct(product.id, productName: product.name);
            },
            child: Text(
              'YA, HAPUS',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Clean Header
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
                    'Katalog Produk',
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
            
            // Search Input Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: GoogleFonts.poppins(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk, SKU, barcode...',
                    hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Products List
            Expanded(
              child: BlocConsumer<ProductCubit, ProductState>(
                listener: (context, state) {
                  if (state is ProductDeleted) {
                    _showAppSnackbar('Produk ${state.productName.isNotEmpty ? '"${state.productName}" ' : ''}berhasil dihapus.');
                  }
                  if (state is ProductSaved) {
                    _showAppSnackbar(state.isUpdate ? 'Data produk berhasil diperbarui.' : 'Produk baru berhasil ditambahkan.');
                  }
                  if (state is ProductError) {
                    _showAppSnackbar(state.message, isError: true);
                  }
                },
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
                          style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final Product product = item['product'];
                        final Brand? brand = item['brand'];
                        final Category? category = item['category'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: product.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        File(product.imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.inventory_2_outlined,
                                                color: Color(0xFF94A3B8), size: 18),
                                      ),
                                    )
                                  : const Icon(Icons.inventory_2_outlined,
                                      color: Color(0xFF94A3B8), size: 18),
                            ),
                            title: Text(
                              product.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: const Color(0xFF0F172A),
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
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (category != null)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          category.name,
                                          style: GoogleFonts.poppins(
                                              fontSize: 9.5,
                                              color: const Color(0xFF0F172A),
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    if (brand != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          brand.name,
                                          style: GoogleFonts.poppins(
                                              fontSize: 9.5,
                                              color: const Color(0xFF059669),
                                              fontWeight: FontWeight.w700),
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
                                  color: const Color(0xFFF1F5F9),
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
                                      padding: EdgeInsets.all(7),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        color: Color(0xFF334155),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Material(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _showDeleteDialog(context, product),
                                    child: const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFDC2626),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Tambah Produk',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
