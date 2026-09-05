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

  void _showSeedChoiceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0F172A), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generate Data Dummy Contoh',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Option 1: F&B Coffee Shop Menu with Recipes
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _startSeedingCoffeeProducts(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF78350F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.coffee_rounded, color: Color(0xFF78350F), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Menu Kedai Kopi (F&B)',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Resep BOM',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '15 Menu Minuman F&B siap kasir terhubung otomatis ke 23 Bahan Baku racikan',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Retail / Minimarket 100 Products
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _startSeedingRetailProducts(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF1E293B), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100 Produk Retail / Minimarket',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sembako, snack, minuman botol, rokok, sabun, multi-satuan & harga grosir',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSeedingCoffeeProducts(BuildContext context) {
    int currentProgress = 0;
    int totalProgress = 15;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat Menu & Resep F&B...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentProgress dari $totalProgress menu kedai kopi diproses',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalProgress > 0 ? (currentProgress / totalProgress) : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    context.read<ProductCubit>().repository.seedCoffeeMenuProducts(
      onProgress: (cur, tot) {
        currentProgress = cur;
        totalProgress = tot;
      },
    ).then((count) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        context.read<ProductCubit>().loadProducts();
        _showAppSnackbar('Berhasil membuat $count menu F&B lengkap dengan resep racikan!');
      }
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        _showAppSnackbar('Gagal membuat menu F&B: $e', isError: true);
      }
    });
  }

  void _startSeedingRetailProducts(BuildContext context) {
    int currentProgress = 0;
    int totalProgress = 100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat 100 Produk Dummy...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentProgress dari $totalProgress produk diproses',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalProgress > 0 ? (currentProgress / totalProgress) : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    context.read<ProductCubit>().repository.seedDummyData(
      onProgress: (cur, tot) {
        currentProgress = cur;
        totalProgress = tot;
      },
    ).then((count) {
      if (context.mounted) {
        Navigator.pop(context);
        context.read<ProductCubit>().loadProducts();
        _showAppSnackbar('Berhasil membuat $count produk dummy retail beserta foto!');
      }
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showAppSnackbar('Gagal mengisi data dummy: $e', isError: true);
      }
    });
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
                  const Spacer(),
                  Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showSeedChoiceDialog(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.playlist_add_rounded,
                            color: Color(0xFF334155), size: 20),
                      ),
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
                    var list = state.products.where((item) {
                      final Product product = item['product'];
                      return product.productType != 'raw_material';
                    }).toList();

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
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (category != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          category.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
