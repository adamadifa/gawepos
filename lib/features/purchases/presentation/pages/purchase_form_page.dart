import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
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
        const SnackBar(content: Text('Produk sudah ditambahkan, silakan sesuaikan kuantitas.')),
      );
      return;
    }

    final repo = getIt<PurchaseRepository>();
    final units = await repo.getProductUnits(product.id);
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk ini tidak memiliki unit satuan.')),
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
              title: Text(
                'Pilih Pemasok / Supplier',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cari Pemasok...',
                        hintStyle: TextStyle(fontSize: 12, color: AppConstants.textLightColor),
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state is SupplierLoaded) {
                            final list = state.suppliers.where((s) {
                              return s.name.toLowerCase().contains(searchQuery);
                            }).toList();

                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  'Pemasok tidak ditemukan.',
                                  style: GoogleFonts.poppins(color: AppConstants.textLightColor, fontSize: 12),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final s = list[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  title: Text(s.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: s.phone != null ? Text(s.phone!, style: const TextStyle(fontSize: 11)) : null,
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
                  child: const Text('TUTUP'),
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
              title: Text(
                'Pilih Produk',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cari nama produk...',
                        prefixIcon: Icon(Icons.search),
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
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state is ProductLoaded) {
                            final list = state.products.where((row) {
                              final Product p = row['product'];
                              return p.name.toLowerCase().contains(searchQuery);
                            }).toList();

                            if (list.isEmpty) {
                              return Center(
                                child: Text(
                                  'Produk tidak ditemukan.',
                                  style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final row = list[idx];
                                final Product p = row['product'];

                                return ListTile(
                                  title: Text(p.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                  subtitle: Text(p.sku ?? '-', style: GoogleFonts.poppins(fontSize: 11)),
                                  trailing: const Icon(Icons.add_circle_outline, color: AppConstants.primaryColor),
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
                  child: const Text('TUTUP'),
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
        const SnackBar(content: Text('Pilih supplier terlebih dahulu!'), backgroundColor: AppConstants.errorColor),
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 barang!'), backgroundColor: AppConstants.errorColor),
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
            backgroundColor: AppConstants.errorColor,
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
        backgroundColor: AppConstants.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Restok Baru',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Supplier Picker Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        side: const BorderSide(color: AppConstants.borderLightColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Pemasok / Supplier',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppConstants.textDarkColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _showSupplierSearchDialog,
                              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Pilih Pemasok *',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  suffixIcon: _selectedSupplier != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16),
                                          onPressed: () {
                                            setState(() {
                                              _selectedSupplier = null;
                                            });
                                          },
                                        )
                                      : const Icon(Icons.arrow_drop_down_rounded),
                                ),
                                child: Text(
                                  _selectedSupplier?.name ?? 'Pilih Pemasok...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: _selectedSupplier == null ? AppConstants.textLightColor : AppConstants.textDarkColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Products Selection Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Barang Restok',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showProductSearchDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            'Tambah Barang',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (_selectedItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          border: Border.all(color: AppConstants.borderLightColor),
                        ),
                        child: Center(
                          child: Text(
                            'Belum ada barang restok yang dipilih.',
                            style: GoogleFonts.poppins(color: AppConstants.textLightColor),
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

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                              side: const BorderSide(color: AppConstants.borderLightColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppConstants.textDarkColor,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppConstants.errorColor),
                                        onPressed: () {
                                          setState(() {
                                            _selectedItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Unit Dropdown
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<ProductUnit>(
                                          value: selectedUnit,
                                          decoration: const InputDecoration(
                                            labelText: 'Satuan',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                          items: units.map((u) {
                                            return DropdownMenuItem<ProductUnit>(
                                              value: u,
                                              child: Text(u.name, style: GoogleFonts.poppins(fontSize: 12)),
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
                                      const SizedBox(width: 8),
                                      // Quantity (Support decimals)
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: item['quantity'].toString(),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Jumlah',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                          initialValue: item['costPrice'] == 0.0 ? '' : item['costPrice'].toString(),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Harga Beli (Pcs)',
                                            prefixText: 'Rp ',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Subtotal: ',
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
                                      ),
                                      Text(
                                        CurrencyFormatter.format((item['quantity'] as double) * (item['costPrice'] as double)),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppConstants.textDarkColor,
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
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppConstants.borderLightColor),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
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
                          decoration: const InputDecoration(
                            labelText: 'Diskon (Rp)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _discountAmount = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Tax
                      Expanded(
                        child: TextFormField(
                          controller: _taxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Pajak (Rp)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metode Pembayaran:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textLightColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Tunai (Lunas)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: _paymentType == 'cash' ? FontWeight.bold : FontWeight.normal,
                                    color: _paymentType == 'cash' ? Colors.white : AppConstants.textDarkColor,
                                  ),
                                ),
                              ),
                              selected: _paymentType == 'cash',
                              selectedColor: AppConstants.primaryColor,
                              backgroundColor: Colors.grey.shade50,
                              checkmarkColor: Colors.white,
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _paymentType = 'cash';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Hutang (Kredit)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: _paymentType == 'debt' ? FontWeight.bold : FontWeight.normal,
                                    color: _paymentType == 'debt' ? Colors.white : AppConstants.textDarkColor,
                                  ),
                                ),
                              ),
                              selected: _paymentType == 'debt',
                              selectedColor: AppConstants.primaryColor,
                              backgroundColor: Colors.grey.shade50,
                              checkmarkColor: Colors.white,
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _paymentType = 'debt';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_paymentType == 'debt') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _downPaymentController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Uang Muka / DP (Rp)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _downPayment = double.tryParse(val) ?? 0.0;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Restok:',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(_grandTotal),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        ),
                      ),
                      onPressed: _savePurchaseOrder,
                      child: Text(
                        'SIMPAN ORDER RESTOK',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
