import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/app_database.dart';
import '../../data/purchase_repository.dart';
import '../../presentation/bloc/purchase_cubit.dart';
import '../../../master/presentation/bloc/supplier_cubit.dart';
import '../../../master/presentation/bloc/product_cubit.dart';

class PurchaseFormPage extends StatefulWidget {
  const PurchaseFormPage({super.key});

  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
  final _formKey = GlobalKey<FormState>();

  Supplier? _selectedSupplier;
  final List<Map<String, dynamic>> _selectedItems = []; // item maps
  String _paymentType = 'cash'; // 'cash' or 'debt'

  double _discountAmount = 0.0;
  double _taxAmount = 0.0;
  double _downPayment = 0.0;

  final _discountController = TextEditingController();
  final _taxController = TextEditingController();
  final _downPaymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SupplierCubit>().loadSuppliers();
    context.read<ProductCubit>().loadProducts();
    _discountController.text = '0';
    _taxController.text = '0';
    _downPaymentController.text = '0';
  }

  @override
  void dispose() {
    _discountController.dispose();
    _taxController.dispose();
    _downPaymentController.dispose();
    super.dispose();
  }

  double get _subtotal {
    double total = 0.0;
    for (var item in _selectedItems) {
      final qty = item['quantity'] as double;
      final cost = item['costPrice'] as double;
      total += (qty * cost);
    }
    return total;
  }

  double get _grandTotal {
    return _subtotal - _discountAmount + _taxAmount;
  }

  // Method to fetch product units when selected
  Future<void> _addProductItem(Product product) async {
    // Check if product already added
    final exists = _selectedItems.any((item) => (item['product'] as Product).id == product.id);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk sudah ditambahkan, silakan sesuaikan kuantitas.'),
          backgroundColor: Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final repo = getIt<PurchaseRepository>();
    final units = await repo.getProductUnits(product.id);
    if (!mounted) return;
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk ini belum memiliki unit satuan.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedItems.add({
        'product': product,
        'units': units,
        'selectedUnit': units.first,
        'quantity': 1.0,
        'costPrice': 0.0,
      });
    });
  }

  void _showSupplierSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Pilih Pemasok / Supplier',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari Pemasok...',
                        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: BlocBuilder<SupplierCubit, SupplierState>(
                        builder: (context, state) {
                          if (state is SupplierLoading) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                          }
                          if (state is SupplierLoaded) {
                            final list = state.suppliers.where((s) {
                              return s.name.toLowerCase().contains(searchQuery);
                            }).toList();

                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  'Pemasok tidak ditemukan.',
                                  style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final s = list[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF0F172A)),
                                  ),
                                  title: Text(s.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                  subtitle: s.phone != null ? Text(s.phone!, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))) : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedSupplier = s;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          }
                          return const Center(child: Text('Gagal memuat pemasok.'));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('TUTUP', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProductSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Pilih Barang Restok',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari nama produk atau SKU...',
                        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: BlocBuilder<ProductCubit, ProductState>(
                        builder: (context, state) {
                          if (state is ProductLoading) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                          }
                          if (state is ProductLoaded) {
                            final list = state.products.where((row) {
                              final Product p = row['product'];
                              return p.name.toLowerCase().contains(searchQuery) ||
                                  (p.sku != null && p.sku!.toLowerCase().contains(searchQuery));
                            }).toList();

                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  'Produk tidak ditemukan.',
                                  style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final row = list[idx];
                                final Product p = row['product'];

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF0F172A)),
                                  ),
                                  title: Text(p.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A))),
                                  subtitle: Text(p.sku ?? '-', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                                  trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A), size: 20),
                                  onTap: () {
                                    _addProductItem(p);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          }
                          return const Center(child: Text('Gagal memuat produk.'));
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('TUTUP', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _savePurchaseOrder() {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih supplier terlebih dahulu!'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 barang!'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate quantities and prices
    for (var item in _selectedItems) {
      final double qty = item['quantity'];
      final double price = item['costPrice'];
      if (qty <= 0 || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kuantitas dan Harga Beli harus valid!'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final itemsToSave = _selectedItems.map((item) {
      final ProductUnit unit = item['selectedUnit'];
      return {
        'productId': (item['product'] as Product).id,
        'unitId': unit.id,
        'quantity': item['quantity'],
        'costPrice': item['costPrice'],
      };
    }).toList();

    context.read<PurchaseCubit>().createPurchase(
          supplierId: _selectedSupplier!.id,
          items: itemsToSave,
          discountAmount: _discountAmount,
          taxAmount: _taxAmount,
          paymentType: _paymentType,
          downPayment: _paymentType == 'debt' ? _downPayment : 0.0,
        );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesanan restok berhasil disimpan sebagai pending.'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              'Restok Baru',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Input faktur & pesanan barang dari pemasok',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Picker Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pemasok / Supplier',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _showSupplierSearchDialog,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF0F172A)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _selectedSupplier?.name ?? 'Pilih Pemasok / Supplier...',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: _selectedSupplier == null ? FontWeight.normal : FontWeight.w600,
                                          color: _selectedSupplier == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (_selectedSupplier != null)
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedSupplier = null;
                                          });
                                        },
                                        child: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFFDC2626)),
                                      )
                                    else
                                      const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Products Selection Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daftar Barang Restok',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: _showProductSearchDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Tambah Barang',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11.5, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_selectedItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Belum ada barang restok yang dipilih.',
                                style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedItems.length,
                        itemBuilder: (context, index) {
                          final item = _selectedItems[index];
                          final Product product = item['product'];
                          final List<ProductUnit> units = item['units'];
                          final ProductUnit selectedUnit = item['selectedUnit'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          product.name,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _selectedItems.removeAt(index);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // Unit Dropdown
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<ProductUnit>(
                                              value: selectedUnit,
                                              isExpanded: true,
                                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                              items: units.map((u) {
                                                return DropdownMenuItem<ProductUnit>(
                                                  value: u,
                                                  child: Text(u.name, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0F172A))),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    item['selectedUnit'] = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Quantity
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: item['quantity'].toString(),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            labelText: 'Jumlah',
                                            labelStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            final qty = double.tryParse(val) ?? 0.0;
                                            setState(() {
                                              item['quantity'] = qty;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Cost Price (Harga Beli)
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          key: ValueKey('${product.id}_${selectedUnit.id}'),
                                          initialValue: item['costPrice'] == 0.0 ? '' : item['costPrice'].toString(),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            labelText: 'Harga Beli',
                                            labelStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                            prefixText: 'Rp ',
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            final price = double.tryParse(val) ?? 0.0;
                                            setState(() {
                                              item['costPrice'] = price;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Subtotal: ',
                                        style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                                      ),
                                      Text(
                                        CurrencyFormatter.format((item['quantity'] as double) * (item['costPrice'] as double)),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Invoice Details & Save Button fixed at the bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 10,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Discount
                      Expanded(
                        child: TextFormField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Diskon (Rp)',
                            labelStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _discountAmount = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Tax
                      Expanded(
                        child: TextFormField(
                          controller: _taxController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Pajak (Rp)',
                            labelStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _taxAmount = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _paymentType = 'cash';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _paymentType == 'cash' ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _paymentType == 'cash' ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Tunai (Lunas)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: _paymentType == 'cash' ? FontWeight.w700 : FontWeight.w500,
                                  color: _paymentType == 'cash' ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _paymentType = 'debt';
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _paymentType == 'debt' ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _paymentType == 'debt' ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Hutang (Kredit)',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: _paymentType == 'debt' ? FontWeight.w700 : FontWeight.w500,
                                  color: _paymentType == 'debt' ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_paymentType == 'debt') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _downPaymentController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Uang Muka / DP (Rp)',
                        labelStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _downPayment = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Restok:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(_grandTotal),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _savePurchaseOrder,
                      child: Text(
                        'SIMPAN ORDER RESTOK',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

