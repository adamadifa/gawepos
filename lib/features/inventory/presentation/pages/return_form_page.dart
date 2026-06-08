import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../master/presentation/bloc/customer_cubit.dart';
import '../../../master/presentation/bloc/supplier_cubit.dart';
import '../../../master/presentation/bloc/product_cubit.dart';
import '../bloc/return_cubit.dart';

class ReturnFormPage extends StatefulWidget {
  final bool initialIsSales;
  const ReturnFormPage({super.key, this.initialIsSales = true});

  @override
  State<ReturnFormPage> createState() => _ReturnFormPageState();
}

class _ReturnFormPageState extends State<ReturnFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  final AppDatabase _db = getIt<AppDatabase>();

  late bool _isSales;
  bool _isGeneralReturn = false; // true jika tanpa transaksi asal

  // Data transaksi asal yang dimuat dari Cubit
  dynamic _loadedTransaction; // Order atau Purchase
  dynamic _loadedContact; // Customer atau Supplier
  List<Map<String, dynamic>> _loadedItems = []; // key: product, unit, orderItem/purchaseItem, alreadyReturnedQty, quantityToReturn (double)

  // Data untuk Retur Umum (Tanpa Transaksi)
  dynamic _selectedContact; // Customer atau Supplier
  final List<Map<String, dynamic>> _generalSelectedItems = []; // key: product, units, selectedUnit, quantity, price

  String _refundMethod = 'cash'; // 'cash' or 'debt_reduction'

  @override
  void initState() {
    super.initState();
    _isSales = widget.initialIsSales;
    context.read<ReturnCubit>().resetState();
    context.read<CustomerCubit>().loadCustomers();
    context.read<SupplierCubit>().loadSuppliers();
    context.read<ProductCubit>().loadProducts();
  }

  @override
  void dispose() {
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalRefundAmount {
    if (_isGeneralReturn) {
      double total = 0.0;
      for (var item in _generalSelectedItems) {
        final double qty = item['quantity'] ?? 0.0;
        final double pr = item['price'] ?? 0.0;
        total += (qty * pr);
      }
      return total;
    } else {
      double total = 0.0;
      for (var item in _loadedItems) {
        final double qty = item['quantityToReturn'] ?? 0.0;
        final double pr = _isSales 
            ? (item['orderItem'] as OrderItem).price 
            : (item['purchaseItem'] as PurchaseItem).costPrice;
        total += (qty * pr);
      }
      return total;
    }
  }

  void _searchRef() {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor referensi transaksi terlebih dahulu.')),
      );
      return;
    }
    context.read<ReturnCubit>().searchOriginalTransaction(ref, _isSales);
  }

  // Method to fetch product units when selecting in general return
  Future<void> _addGeneralProductItem(Product product) async {
    // Check if product already added
    final exists = _generalSelectedItems.any((item) => (item['product'] as Product).id == product.id);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk sudah ada di daftar, silakan sesuaikan kuantitas.')),
      );
      return;
    }

    final units = _db.select(_db.productUnits).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.productUnits.productId)),
    ])..where(_db.productUnits.productId.equals(product.id));

    final rows = await units.get();
    final List<ProductUnit> productUnits = rows.map((r) => r.readTable(_db.productUnits)).toList();

    if (productUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk ini tidak memiliki unit satuan.')),
      );
      return;
    }

    // Default price from prices table
    final priceRow = await (_db.select(_db.productPrices)
          ..where((tbl) => tbl.productId.equals(product.id) & tbl.unitId.equals(productUnits.first.id))
          ..limit(1))
        .getSingleOrNull();

    final defaultPrice = _isSales ? (priceRow?.price ?? 0.0) : 0.0;

    setState(() {
      _generalSelectedItems.add({
        'product': product,
        'units': productUnits,
        'selectedUnit': productUnits.first,
        'quantity': 1.0,
        'price': defaultPrice,
      });
    });
  }

  void _showBarcodeScanner() {
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
                      'Scan Barcode Invoice / Transaksi',
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
        );
      },
    ).then((code) {
      if (code != null) {
        setState(() {
          _refController.text = code;
        });
        _searchRef();
      }
    });
  }

  void _saveReturn() {
    final authCubit = context.read<AuthCubit>();
    final session = authCubit.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan. Anda harus membuka shift sesi kasir terlebih dahulu di Homepage.'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }

    if (_isGeneralReturn) {
      if (_selectedContact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSales ? 'Silakan pilih pelanggan.' : 'Silakan pilih supplier.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        return;
      }
      if (_generalSelectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan tambahkan barang yang diretur.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        return;
      }

      final double refund = _totalRefundAmount;

      if (_isSales) {
        final List<Map<String, dynamic>> items = _generalSelectedItems.map((e) => {
          'productId': (e['product'] as Product).id,
          'unitId': (e['selectedUnit'] as ProductUnit).id,
          'quantity': e['quantity'] as double,
          'price': e['price'] as double,
        }).toList();

        context.read<ReturnCubit>().submitSalesReturn(
          customerId: _selectedContact.id,
          cashierSessionId: session.id,
          items: items,
          refundAmount: refund,
          refundMethod: _refundMethod,
          notes: _notesController.text.trim(),
        );
      } else {
        final List<Map<String, dynamic>> items = _generalSelectedItems.map((e) => {
          'productId': (e['product'] as Product).id,
          'unitId': (e['selectedUnit'] as ProductUnit).id,
          'quantity': e['quantity'] as double,
          'costPrice': e['price'] as double,
        }).toList();

        context.read<ReturnCubit>().submitPurchaseReturn(
          supplierId: _selectedContact.id,
          cashierSessionId: session.id,
          items: items,
          refundAmount: refund,
          refundMethod: _refundMethod,
          notes: _notesController.text.trim(),
        );
      }
    } else {
      // Retur berdasarkan transaksi
      if (_loadedTransaction == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cari dan muat transaksi asal terlebih dahulu.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        return;
      }

      final itemsToReturn = _loadedItems.where((e) => (e['quantityToReturn'] as double) > 0).toList();
      if (itemsToReturn.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masukkan kuantitas retur minimal 1 unit pada produk.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        return;
      }

      final double refund = _totalRefundAmount;

      if (_isSales) {
        final Order order = _loadedTransaction;
        final List<Map<String, dynamic>> items = itemsToReturn.map((e) {
          final OrderItem orig = e['orderItem'];
          return {
            'productId': orig.productId,
            'unitId': orig.unitId,
            'quantity': e['quantityToReturn'] as double,
            'price': orig.price,
          };
        }).toList();

        context.read<ReturnCubit>().submitSalesReturn(
          orderId: order.id,
          customerId: order.customerId,
          cashierSessionId: session.id,
          items: items,
          refundAmount: refund,
          refundMethod: _refundMethod,
          notes: _notesController.text.trim(),
        );
      } else {
        final Purchase purchase = _loadedTransaction;
        final List<Map<String, dynamic>> items = itemsToReturn.map((e) {
          final PurchaseItem orig = e['purchaseItem'];
          return {
            'productId': orig.productId,
            'unitId': orig.unitId,
            'quantity': e['quantityToReturn'] as double,
            'costPrice': orig.costPrice,
          };
        }).toList();

        context.read<ReturnCubit>().submitPurchaseReturn(
          purchaseId: purchase.id,
          supplierId: purchase.supplierId,
          cashierSessionId: session.id,
          items: items,
          refundAmount: refund,
          refundMethod: _refundMethod,
          notes: _notesController.text.trim(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Tambah Transaksi Retur',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocListener<ReturnCubit, ReturnState>(
        listener: (context, state) {
          if (state is ReturnSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppConstants.successColor),
            );
            Navigator.pop(context);
          } else if (state is ReturnError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppConstants.errorColor),
            );
          } else if (state is ReturnTransactionDetailsLoaded) {
            setState(() {
              _loadedTransaction = state.transaction;
              _loadedContact = state.contact;
              _loadedItems = state.items.map((e) => {
                ...e,
                'quantityToReturn': 0.0,
              }).toList();
            });
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Switcher Jenis Retur
              _buildTypeSwitcher(),
              const SizedBox(height: 16),

              // 2. Switcher Mode Retur (Berdasarkan Transaksi vs Retur Umum)
              _buildModeSwitcher(),
              const SizedBox(height: 16),

              // 3. Section Dinamis
              _isGeneralReturn ? _buildGeneralReturnSection() : _buildTransactionReturnSection(),

              const SizedBox(height: 20),

              // 4. Notes dan Pilihan Metode Refund
              if (_isGeneralReturn 
                  ? _generalSelectedItems.isNotEmpty 
                  : _loadedTransaction != null) ...[
                _buildRefundConfigCard(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSwitcher() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        side: const BorderSide(color: AppConstants.borderLightColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('Jenis Retur:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            ChoiceChip(
              label: const Text('Penjualan'),
              selected: _isSales,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _isSales = true;
                    _loadedTransaction = null;
                    _generalSelectedItems.clear();
                    _selectedContact = null;
                    _notesController.clear();
                    _refController.clear();
                  });
                  context.read<ReturnCubit>().resetState();
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Pembelian'),
              selected: !_isSales,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _isSales = false;
                    _loadedTransaction = null;
                    _generalSelectedItems.clear();
                    _selectedContact = null;
                    _notesController.clear();
                    _refController.clear();
                  });
                  context.read<ReturnCubit>().resetState();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        side: const BorderSide(color: AppConstants.borderLightColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isGeneralReturn = false;
                    _generalSelectedItems.clear();
                    _selectedContact = null;
                  });
                  context.read<ReturnCubit>().resetState();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_isGeneralReturn ? AppConstants.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      'Dari Transaksi Asal',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: !_isGeneralReturn ? Colors.white : AppConstants.textDarkColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isGeneralReturn = true;
                    _loadedTransaction = null;
                    _loadedItems.clear();
                    _loadedContact = null;
                  });
                  context.read<ReturnCubit>().resetState();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _isGeneralReturn ? AppConstants.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      'Retur Umum (Bebas)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isGeneralReturn ? Colors.white : AppConstants.textDarkColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionReturnSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSales ? 'Nomor Referensi Penjualan' : 'Nomor Referensi Pembelian',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _refController,
                        decoration: InputDecoration(
                          hintText: _isSales ? 'e.g. TRX-20260607-0001' : 'e.g. PUR-20260607-0001',
                          hintStyle: const TextStyle(fontSize: 12, color: AppConstants.textLightColor),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppConstants.primaryColor),
                            onPressed: _showBarcodeScanner,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (val) => _searchRef(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searchRef,
                      child: const Text('CARI'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_loadedTransaction != null) ...[
          const SizedBox(height: 16),
          _buildLoadedTransactionDetailsCard(),
          const SizedBox(height: 16),
          _buildLoadedItemsCard(),
        ],
      ],
    );
  }

  Widget _buildLoadedTransactionDetailsCard() {
    final nowStr = DateFormat('dd MMM yyyy, HH:mm').format(_isSales 
        ? (_loadedTransaction as Order).createdAt 
        : (_loadedTransaction as Purchase).createdAt);

    final String ref = _isSales ? (_loadedTransaction as Order).referenceNo : (_loadedTransaction as Purchase).referenceNo;
    final double grandTotal = _isSales ? (_loadedTransaction as Order).grandTotal : (_loadedTransaction as Purchase).grandTotal;

    return Card(
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
            Text('Ringkasan Transaksi Asal', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            const Divider(height: 20),
            _buildMetaRow('No. Invoice', ref),
            _buildMetaRow('Tanggal', nowStr),
            _buildMetaRow(_isSales ? 'Pelanggan' : 'Supplier', _loadedContact?.name ?? (_isSales ? 'Pelanggan Umum' : 'Supplier')),
            _buildMetaRow('Total Belanja', CurrencyFormatter.format(grandTotal)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedItemsCard() {
    return Card(
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
            Text('Sesuaikan Barang yang Diretur', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _loadedItems.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final item = _loadedItems[index];
                final Product? product = item['product'];
                final ProductUnit? unit = item['unit'];
                final double origQty = _isSales 
                    ? (item['orderItem'] as OrderItem).quantity 
                    : (item['purchaseItem'] as PurchaseItem).quantity;

                final double price = _isSales 
                    ? (item['orderItem'] as OrderItem).price 
                    : (item['purchaseItem'] as PurchaseItem).costPrice;

                final double alreadyReturned = item['alreadyReturnedQty'] ?? 0.0;
                final double maxQty = (origQty - alreadyReturned).clamp(0.0, double.infinity);

                final double currentReturnVal = item['quantityToReturn'] ?? 0.0;

                final String productName = product?.name ?? 'Produk Terhapus (ID: ${_isSales ? (item['orderItem'] as OrderItem).productId : (item['purchaseItem'] as PurchaseItem).productId})';
                final String unitName = unit?.name ?? 'Satuan';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Beli: ${origQty.toString().replaceAll(RegExp(r'\.0$'), '')} $unitName | Sudah Retur: ${alreadyReturned.toString().replaceAll(RegExp(r'\.0$'), '')} $unitName | Max Retur: ${maxQty.toString().replaceAll(RegExp(r'\.0$'), '')} $unitName',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Harga Unit: ${CurrencyFormatter.format(price)}',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppConstants.textDarkColor),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppConstants.primaryColor),
                              onPressed: maxQty <= 0 ? null : () {
                                if (currentReturnVal > 0) {
                                  setState(() {
                                    item['quantityToReturn'] = currentReturnVal - 1.0;
                                  });
                                }
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppConstants.borderLightColor),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentReturnVal.toString().replaceAll(RegExp(r'\.0$'), ''),
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppConstants.primaryColor),
                              onPressed: maxQty <= 0 ? null : () {
                                if (currentReturnVal < maxQty) {
                                  setState(() {
                                    item['quantityToReturn'] = currentReturnVal + 1.0;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralReturnSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pemilihan Kontak (Customer/Supplier)
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSales ? 'Pilih Pelanggan' : 'Pilih Supplier / Pemasok',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isSales ? _showCustomerSearchDialog : _showSupplierSearchDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppConstants.borderLightColor),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedContact?.name ?? (_isSales ? 'Pilih Pelanggan...' : 'Pilih Supplier...'),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _selectedContact != null ? AppConstants.textDarkColor : AppConstants.textLightColor,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, color: AppConstants.textLightColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tambah Barang Retur
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            side: const BorderSide(color: AppConstants.borderLightColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daftar Barang Retur', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                    ElevatedButton.icon(
                      onPressed: _showProductSearchDialog,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('BARANG'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (_generalSelectedItems.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Belum ada barang ditambahkan.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _generalSelectedItems.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = _generalSelectedItems[index];
                      final Product product = item['product'];
                      final List<ProductUnit> units = item['units'];
                      final ProductUnit selectedUnit = item['selectedUnit'];
                      final double qty = item['quantity'] ?? 0.0;
                      final double price = item['price'] ?? 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.errorColor, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _generalSelectedItems.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Dropdown Satuan
                              Container(
                                width: 100,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppConstants.borderLightColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<ProductUnit>(
                                    value: selectedUnit,
                                    isExpanded: true,
                                    items: units.map((u) => DropdownMenuItem<ProductUnit>(
                                      value: u,
                                      child: Text(u.name, style: const TextStyle(fontSize: 11)),
                                    )).toList(),
                                    onChanged: (val) async {
                                      if (val != null) {
                                        // Cari harga unit baru
                                        final priceRow = await (_db.select(_db.productPrices)
                                              ..where((tbl) => tbl.productId.equals(product.id) & tbl.unitId.equals(val.id))
                                              ..limit(1))
                                            .getSingleOrNull();
                                        setState(() {
                                          item['selectedUnit'] = val;
                                          item['price'] = _isSales ? (priceRow?.price ?? 0.0) : 0.0;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Qty Input
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: qty.toString().replaceAll(RegExp(r'\.0$'), ''),
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    setState(() {
                                      item['quantity'] = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Price Input
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  key: ValueKey('${product.id}_${selectedUnit.id}_price'),
                                  initialValue: price.toStringAsFixed(0),
                                  decoration: InputDecoration(
                                    labelText: _isSales ? 'Harga Jual' : 'Harga Modal',
                                    prefixText: 'Rp ',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    setState(() {
                                      item['price'] = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRefundConfigCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: const BorderSide(color: AppConstants.borderLightColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Konfigurasi Pengembalian (Refund)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            const Divider(height: 20),
            Text(
              'Metode Refund:',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 0,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: 'cash',
                      groupValue: _refundMethod,
                      onChanged: (val) {
                        if (val != null) setState(() => _refundMethod = val);
                      },
                    ),
                    Text('Uang Tunai (Cash)', style: GoogleFonts.poppins(fontSize: 12)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: 'debt_reduction',
                      groupValue: _refundMethod,
                      onChanged: (val) {
                        if (val != null) setState(() => _refundMethod = val);
                      },
                    ),
                    Text(_isSales ? 'Potong Piutang (Bon)' : 'Potong Hutang', style: GoogleFonts.poppins(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Alasan Retur / Catatan',
                hintText: 'e.g. Barang cacat produksi / Salah ukuran',
                hintStyle: TextStyle(fontSize: 11, color: AppConstants.textLightColor),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final double totalRefund = _totalRefundAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Refund:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              CurrencyFormatter.format(totalRefund),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _isSales ? AppConstants.errorColor : AppConstants.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saveReturn,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isSales ? AppConstants.errorColor : AppConstants.successColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            'SIMPAN RETUR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textDarkColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showCustomerSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text('Pilih Pelanggan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cari Pelanggan...',
                        hintStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (val) {
                        setStateDialog(() => searchQuery = val.toLowerCase());
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: BlocBuilder<CustomerCubit, CustomerState>(
                        builder: (context, state) {
                          if (state is CustomerLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (state is CustomerLoaded) {
                            final list = state.customers.where((c) => c.name.toLowerCase().contains(searchQuery)).toList();
                            if (list.isEmpty) {
                              return const Center(child: Text('Pelanggan tidak ditemukan.'));
                            }
                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final customer = list[idx];
                                return ListTile(
                                  title: Text(customer.name, style: const TextStyle(fontSize: 13)),
                                  onTap: () {
                                    setState(() {
                                      _selectedContact = customer;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          }
                          return const Center(child: Text('Gagal memuat pelanggan.'));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSupplierSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text('Pilih Supplier', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cari Supplier...',
                        hintStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (val) {
                        setStateDialog(() => searchQuery = val.toLowerCase());
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
                            final list = state.suppliers.where((s) => s.name.toLowerCase().contains(searchQuery)).toList();
                            if (list.isEmpty) {
                              return const Center(child: Text('Supplier tidak ditemukan.'));
                            }
                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final supplier = list[idx];
                                return ListTile(
                                  title: Text(supplier.name, style: const TextStyle(fontSize: 13)),
                                  onTap: () {
                                    setState(() {
                                      _selectedContact = supplier;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            );
                          }
                          return const Center(child: Text('Gagal memuat supplier.'));
                        },
                      ),
                    ),
                  ],
                ),
              ),
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
              title: Text('Pilih Produk', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Cari Produk...',
                        hintStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (val) {
                        setStateDialog(() => searchQuery = val.toLowerCase());
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
                              final Product p = row['product'] as Product;
                              return p.name.toLowerCase().contains(searchQuery);
                            }).toList();
                            if (list.isEmpty) {
                              return const Center(child: Text('Produk tidak ditemukan.'));
                            }
                            return ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, idx) {
                                final row = list[idx];
                                final Product product = row['product'] as Product;
                                return ListTile(
                                  title: Text(product.name, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(product.sku ?? '', style: const TextStyle(fontSize: 11)),
                                  onTap: () {
                                    _addGeneralProductItem(product);
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
            );
          },
        );
      },
    );
  }
}
