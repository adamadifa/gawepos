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
        SnackBar(
          content: Text('Masukkan nomor referensi transaksi terlebih dahulu.', style: GoogleFonts.poppins()),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.read<ReturnCubit>().searchOriginalTransaction(ref, _isSales);
  }

  Future<void> _addGeneralProductItem(Product product) async {
    final exists = _generalSelectedItems.any((item) => (item['product'] as Product).id == product.id);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produk sudah ada di daftar, silakan sesuaikan jumlah.', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final units = _db.select(_db.productUnits).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.productUnits.productId)),
    ])..where(_db.productUnits.productId.equals(product.id));

    final rows = await units.get();
    final List<ProductUnit> productUnits = rows.map((r) => r.readTable(_db.productUnits)).toList();

    if (productUnits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk ini tidak memiliki unit satuan.', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0F172A), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pindai Barcode Transaksi',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 20),
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
        SnackBar(
          content: Text('Gagal menyimpan. Anda harus membuka shift sesi kasir terlebih dahulu.', style: GoogleFonts.poppins()),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isGeneralReturn) {
      if (_selectedContact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSales ? 'Silakan pilih pelanggan.' : 'Silakan pilih supplier.', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_generalSelectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silakan tambahkan barang yang diretur.', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
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
      if (_loadedTransaction == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cari dan muat transaksi asal terlebih dahulu.', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final itemsToReturn = _loadedItems.where((e) => (e['quantityToReturn'] as double) > 0).toList();
      if (itemsToReturn.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tentukan kuantitas retur minimal 1 unit pada salah satu produk.', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
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
    final bool hasItems = _isGeneralReturn ? _generalSelectedItems.isNotEmpty : _loadedTransaction != null;

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
              'Buat Transaksi Retur',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Pengembalian barang penjualan kasir / pembelian',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: BlocListener<ReturnCubit, ReturnState>(
        listener: (context, state) {
          if (state is ReturnSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontSize: 12.5))),
                  ],
                ),
                backgroundColor: AppConstants.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            Navigator.pop(context);
          } else if (state is ReturnError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontSize: 12.5))),
                  ],
                ),
                backgroundColor: AppConstants.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // 1. Selector Jenis Retur (Penjualan vs Pembelian)
                    _buildTypeSelector(),
                    const SizedBox(height: 14),

                    // 2. Selector Mode Retur (Invoice vs Umum)
                    _buildModeSelector(),
                    const SizedBox(height: 16),

                    // 3. Konten Dinamis
                    _isGeneralReturn ? _buildGeneralReturnSection() : _buildTransactionReturnSection(),

                    if (hasItems) ...[
                      const SizedBox(height: 16),
                      _buildRefundConfigCard(),
                    ],
                  ],
                ),
              ),

              // Sticky Bottom Action Bar
              if (hasItems) _buildStickyBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Jenis Retur',
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isSales = true;
                      _loadedTransaction = null;
                      _generalSelectedItems.clear();
                      _selectedContact = null;
                      _notesController.clear();
                      _refController.clear();
                    });
                    context.read<ReturnCubit>().resetState();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _isSales ? const Color(0xFFDC2626).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isSales ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                        width: _isSales ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_return_rounded,
                          size: 18,
                          color: _isSales ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retur Penjualan',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: _isSales ? FontWeight.w700 : FontWeight.w500,
                            color: _isSales ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isSales = false;
                      _loadedTransaction = null;
                      _generalSelectedItems.clear();
                      _selectedContact = null;
                      _notesController.clear();
                      _refController.clear();
                    });
                    context.read<ReturnCubit>().resetState();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: !_isSales ? const Color(0xFF0D9488).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isSales ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
                        width: !_isSales ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_rounded,
                          size: 18,
                          color: !_isSales ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retur Pembelian',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: !_isSales ? FontWeight.w700 : FontWeight.w500,
                            color: !_isSales ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
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
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isGeneralReturn ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isGeneralReturn
                      ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Dari Invoice Asal',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: !_isGeneralReturn ? FontWeight.w700 : FontWeight.w500,
                      color: !_isGeneralReturn ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isGeneralReturn ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isGeneralReturn
                      ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Retur Bebas (Manual)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: _isGeneralReturn ? FontWeight.w700 : FontWeight.w500,
                      color: _isGeneralReturn ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionReturnSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Box Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSales ? 'Nomor Referensi Penjualan' : 'Nomor Referensi Pembelian (PO)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _refController,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: _isSales ? 'Contoh: TRX-20260607-0001' : 'Contoh: PUR-20260607-0001',
                        hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0F172A), size: 20),
                          tooltip: 'Pindai Barcode',
                          onPressed: _showBarcodeScanner,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                      ),
                      onSubmitted: (val) => _searchRef(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _searchRef,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('CARI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_loadedTransaction != null) ...[
          const SizedBox(height: 14),
          _buildLoadedTransactionDetailsCard(),
          const SizedBox(height: 14),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan Transaksi Asal',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Ditemukan', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildMetaRow('No. Invoice', ref),
          _buildMetaRow('Tanggal', nowStr),
          _buildMetaRow(_isSales ? 'Pelanggan' : 'Supplier', _loadedContact?.name ?? (_isSales ? 'Pelanggan Umum' : 'Supplier')),
          _buildMetaRow('Total Belanja', CurrencyFormatter.format(grandTotal)),
        ],
      ),
    );
  }

  Widget _buildLoadedItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tentukan Kuantitas Barang yang Diretur',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _loadedItems.length,
            separatorBuilder: (context, index) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
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

              final String productName = product?.name ?? 'Produk ID: ${_isSales ? (item['orderItem'] as OrderItem).productId : (item['purchaseItem'] as PurchaseItem).productId}';
              final String unitName = unit?.name ?? 'Satuan';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Beli: ${origQty.toString().replaceAll(RegExp(r'\.0$'), '')} $unitName • Sudah Retur: ${alreadyReturned.toString().replaceAll(RegExp(r'\.0$'), '')} • Max Retur: ${maxQty.toString().replaceAll(RegExp(r'\.0$'), '')} $unitName',
                    style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Harga: ${CurrencyFormatter.format(price)}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0F172A), size: 22),
                            onPressed: maxQty <= 0
                                ? null
                                : () {
                                    if (currentReturnVal > 0) {
                                      setState(() {
                                        item['quantityToReturn'] = currentReturnVal - 1.0;
                                      });
                                    }
                                  },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentReturnVal.toString().replaceAll(RegExp(r'\.0$'), ''),
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0F172A), size: 22),
                            onPressed: maxQty <= 0
                                ? null
                                : () {
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
    );
  }

  Widget _buildGeneralReturnSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pemilihan Kontak (Customer/Supplier)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSales ? 'Pilih Pelanggan' : 'Pilih Supplier / Pemasok',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _isSales ? _showCustomerSearchDialog : _showSupplierSearchDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedContact?.name ?? (_isSales ? 'Pilih Pelanggan...' : 'Pilih Supplier...'),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: _selectedContact != null ? FontWeight.w600 : FontWeight.normal,
                          color: _selectedContact != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tambah Barang Retur
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daftar Barang Retur',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showProductSearchDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text('TAMBAH BARANG', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              if (_generalSelectedItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada barang yang ditambahkan.',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _generalSelectedItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
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
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              onPressed: () {
                                setState(() {
                                  _generalSelectedItems.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Dropdown Satuan
                            Container(
                              width: 95,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<ProductUnit>(
                                  value: selectedUnit,
                                  isExpanded: true,
                                  items: units.map((u) => DropdownMenuItem<ProductUnit>(
                                    value: u,
                                    child: Text(u.name, style: GoogleFonts.poppins(fontSize: 11.5)),
                                  )).toList(),
                                  onChanged: (val) async {
                                    if (val != null) {
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
                                style: GoogleFonts.poppins(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Qty',
                                  labelStyle: GoogleFonts.poppins(fontSize: 11),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: _isSales ? 'Harga Jual' : 'Harga Modal',
                                  labelStyle: GoogleFonts.poppins(fontSize: 11),
                                  prefixText: 'Rp ',
                                  prefixStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
      ],
    );
  }

  Widget _buildRefundConfigCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Konfigurasi Pengembalian (Refund)',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Text(
            'Metode Pengembalian:',
            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _refundMethod = 'cash'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _refundMethod == 'cash' ? const Color(0xFF059669).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _refundMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                        width: _refundMethod == 'cash' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_rounded, size: 16, color: _refundMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          'Uang Tunai (Cash)',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: _refundMethod == 'cash' ? FontWeight.w700 : FontWeight.w500,
                            color: _refundMethod == 'cash' ? const Color(0xFF059669) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _refundMethod = 'debt_reduction'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _refundMethod == 'debt_reduction' ? const Color(0xFF1A56DB).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _refundMethod == 'debt_reduction' ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
                        width: _refundMethod == 'debt_reduction' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_rounded, size: 16, color: _refundMethod == 'debt_reduction' ? const Color(0xFF1A56DB) : const Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _isSales ? 'Potong Piutang' : 'Potong Hutang',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: _refundMethod == 'debt_reduction' ? FontWeight.w700 : FontWeight.w500,
                              color: _refundMethod == 'debt_reduction' ? const Color(0xFF1A56DB) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            'Alasan Retur / Catatan',
            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            style: GoogleFonts.poppins(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Contoh: Barang cacat pabrik / salah varian ukuran',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    final double totalRefund = _totalRefundAmount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Refund Pengembalian',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  Text(
                    CurrencyFormatter.format(totalRefund),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _isSales ? const Color(0xFFDC2626) : const Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton(
              onPressed: _saveReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'SIMPAN RETUR',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
          ),
          const Text(': ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Pilih Pelanggan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau telepon...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    onChanged: (val) => setStateSheet(() => searchQuery = val.toLowerCase()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: BlocBuilder<CustomerCubit, CustomerState>(
                      builder: (context, state) {
                        if (state is CustomerLoading) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                        }
                        if (state is CustomerLoaded) {
                          final list = state.customers.where((c) => c.name.toLowerCase().contains(searchQuery)).toList();
                          if (list.isEmpty) {
                            return Center(child: Text('Pelanggan tidak ditemukan.', style: GoogleFonts.poppins(color: const Color(0xFF64748B))));
                          }
                          return ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final customer = list[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                                  child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'P', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1A56DB))),
                                ),
                                title: Text(customer.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(customer.phone ?? '-', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
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
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSupplierSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Pilih Supplier / Pemasok', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari supplier...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    onChanged: (val) => setStateSheet(() => searchQuery = val.toLowerCase()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: BlocBuilder<SupplierCubit, SupplierState>(
                      builder: (context, state) {
                        if (state is SupplierLoading) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                        }
                        if (state is SupplierLoaded) {
                          final list = state.suppliers.where((s) => s.name.toLowerCase().contains(searchQuery)).toList();
                          if (list.isEmpty) {
                            return Center(child: Text('Supplier tidak ditemukan.', style: GoogleFonts.poppins(color: const Color(0xFF64748B))));
                          }
                          return ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final supplier = list[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                  child: Text(supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488))),
                                ),
                                title: Text(supplier.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(supplier.phone ?? '-', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
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
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showProductSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Pilih Produk untuk Diretur', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk / barcode...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    onChanged: (val) => setStateSheet(() => searchQuery = val.toLowerCase()),
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
                            final Product p = row['product'] as Product;
                            return p.name.toLowerCase().contains(searchQuery) || (p.sku != null && p.sku!.toLowerCase().contains(searchQuery));
                          }).toList();
                          if (list.isEmpty) {
                            return Center(child: Text('Produk tidak ditemukan.', style: GoogleFonts.poppins(color: const Color(0xFF64748B))));
                          }
                          return ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final row = list[idx];
                              final Product product = row['product'] as Product;
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded, size: 20, color: Color(0xFF0F172A)),
                                ),
                                title: Text(product.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(product.sku ?? 'Tanpa Barcode', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                                onTap: () {
                                  _addGeneralProductItem(product);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
