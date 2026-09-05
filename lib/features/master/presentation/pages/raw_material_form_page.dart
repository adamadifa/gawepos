import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../data/master_repository.dart';

class RawMaterialFormPage extends StatefulWidget {
  final Product? existingProduct;
  const RawMaterialFormPage({super.key, this.existingProduct});

  @override
  State<RawMaterialFormPage> createState() => _RawMaterialFormPageState();
}

class _RawMaterialFormPageState extends State<RawMaterialFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _initialStockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');

  int? _selectedCategoryId;
  String _selectedUnitName = 'Gram';
  final List<String> _commonUnits = [
    'Gram',
    'Kg',
    'Ml',
    'Liter',
    'Pcs',
    'Lembar',
    'Sachet',
    'Botol',
    'Kaleng',
    'Dus',
  ];
  final TextEditingController _customUnitController = TextEditingController();
  bool _isCustomUnit = false;

  bool _isLoading = false;
  bool _isSaving = false;
  List<Category> _categories = [];

  // Existing data if editing
  ProductUnit? _existingUnit;
  InventoryData? _existingInventory;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final repo = getIt<MasterRepository>();
      _categories = await repo.getCategories();

      if (widget.existingProduct != null) {
        final product = widget.existingProduct!;
        _nameController.text = product.name;
        _selectedCategoryId = product.categoryId;
        _minStockController.text = product.minStockAlert.toString();

        final complete = await repo.getProductComplete(product.id);
        if (complete != null) {
          final units = complete['units'] as List<ProductUnit>;
          if (units.isNotEmpty) {
            _existingUnit = units.first;
            _costPriceController.text = _existingUnit!.costPrice.toStringAsFixed(0);
            if (_commonUnits.contains(_existingUnit!.name)) {
              _selectedUnitName = _existingUnit!.name;
              _isCustomUnit = false;
            } else {
              _isCustomUnit = true;
              _customUnitController.text = _existingUnit!.name;
            }
          }
        }

        // Load existing stock
        final db = getIt<AppDatabase>();
        final invList = await (db.select(db.inventory)
              ..where((tbl) => tbl.productId.equals(product.id)))
            .get();
        if (invList.isNotEmpty) {
          _existingInventory = invList.first;
          _initialStockController.text = _existingInventory!.quantity.toStringAsFixed(0);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _initialStockController.dispose();
    _minStockController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final finalUnitName = _isCustomUnit
        ? _customUnitController.text.trim()
        : _selectedUnitName;

    if (finalUnitName.isEmpty) {
      _showSnackbar('Nama satuan unit wajib diisi', isError: true);
      return;
    }

    final costPrice = double.tryParse(_costPriceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final initialStock = double.tryParse(_initialStockController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    final minStock = int.tryParse(_minStockController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    setState(() => _isSaving = true);
    final repo = getIt<MasterRepository>();
    final db = getIt<AppDatabase>();

    try {
      if (widget.existingProduct == null) {
        // ─── INSERT BARU ──────────────────────────────────────────
        final productComp = ProductsCompanion.insert(
          name: _nameController.text.trim(),
          productType: const drift.Value('raw_material'),
          businessSegment: const drift.Value('fnb'),
          isStockManaged: const drift.Value(true),
          minStockAlert: drift.Value(minStock),
          categoryId: drift.Value(_selectedCategoryId),
          isActive: const drift.Value(true),
          hasRecipe: const drift.Value(false),
        );

        final unitComp = ProductUnitsCompanion(
          id: const drift.Value(1),
          name: drift.Value(finalUnitName),
          conversionFactor: const drift.Value(1.0),
          isBase: const drift.Value(true),
          costPrice: drift.Value(costPrice),
          productId: const drift.Value(0),
        );

        // Price default untuk kompatibilitas matrix (tidak dipakai di POS kasir)
        final priceComp = ProductPricesCompanion(
          unitId: const drift.Value(1),
          priceTierId: const drift.Value(1),
          price: drift.Value(costPrice),
          minQty: const drift.Value(1),
          productId: const drift.Value(0),
        );

        final newProdId = await repo.insertProductComplete(
          product: productComp,
          units: [unitComp],
          prices: [priceComp],
        );

        // Jika ada stok awal > 0, buat catatan saldo stok & mutasi
        if (initialStock > 0) {
          final savedUnits = await (db.select(db.productUnits)
                ..where((tbl) => tbl.productId.equals(newProdId)))
              .get();
          final baseUnitId = savedUnits.first.id;

          await db.into(db.inventory).insert(
            InventoryCompanion.insert(
              productId: newProdId,
              unitId: baseUnitId,
              quantity: drift.Value(initialStock),
            ),
          );

          await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: newProdId,
              unitId: baseUnitId,
              quantity: initialStock,
              type: 'opname',
              notes: const drift.Value('Saldo stok awal bahan baku'),
            ),
          );
        }
      } else {
        // ─── UPDATE ───────────────────────────────────────────────
        final p = widget.existingProduct!;
        final updatedProduct = p.copyWith(
          name: _nameController.text.trim(),
          categoryId: drift.Value(_selectedCategoryId),
          minStockAlert: minStock,
        );

        await db.update(db.products).replace(updatedProduct);

        if (_existingUnit != null) {
          final updatedUnit = _existingUnit!.copyWith(
            name: finalUnitName,
            costPrice: costPrice,
          );
          await db.update(db.productUnits).replace(updatedUnit);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        _showSnackbar(
          widget.existingProduct == null
              ? 'Bahan baku "${_nameController.text}" berhasil ditambahkan!'
              : 'Bahan baku berhasil diperbarui!',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal menyimpan: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProduct != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Ubah Bahan Baku' : 'Tambah Bahan Baku',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Banner Info Singkat
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.eco_rounded, color: Color(0xFF059669), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Master Bahan Baku & Racikan',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: const Color(0xFF065F46),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Bahan mentah ini akan otomatis digunakan untuk menyusun resep menu dan memotong stok saat pesanan kasir diproses.',
                                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF047857)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card Informasi Utama
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Informasi Bahan',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Nama Bahan
                                Text(
                                  'Nama Bahan Baku *',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  style: GoogleFonts.poppins(fontSize: 13.5),
                                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama bahan wajib diisi' : null,
                                  decoration: InputDecoration(
                                    hintText: 'Contoh: Biji Kopi Arabika, Susu Fresh Milk, Sirup Karamel',
                                    hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12),
                                    prefixIcon: const Icon(Icons.eco_outlined, color: Color(0xFF059669), size: 20),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Kategori
                                Text(
                                  'Kategori Bahan (Opsional)',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int?>(
                                  value: (_selectedCategoryId != null && _categories.any((c) => c.id == _selectedCategoryId))
                                      ? _selectedCategoryId
                                      : null,
                                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF64748B), size: 18),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('Tanpa Kategori')),
                                    ..._categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                                  ],
                                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card Satuan & Harga Beli/Modal
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.scale_rounded, color: Color(0xFF059669), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Satuan Takaran & Harga Beli',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Pilihan Satuan Cepat
                                Text(
                                  'Pilih Satuan Pengukuran *',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ..._commonUnits.map((unit) {
                                      final isSelected = !_isCustomUnit && _selectedUnitName == unit;
                                      return ChoiceChip(
                                        label: Text(unit),
                                        labelStyle: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? Colors.white : const Color(0xFF334155),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF059669),
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              _selectedUnitName = unit;
                                              _isCustomUnit = false;
                                            });
                                          }
                                        },
                                      );
                                    }),
                                    ChoiceChip(
                                      label: const Text('Satuan Lainnya...'),
                                      labelStyle: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: _isCustomUnit ? FontWeight.w700 : FontWeight.w500,
                                        color: _isCustomUnit ? Colors.white : const Color(0xFF334155),
                                      ),
                                      selected: _isCustomUnit,
                                      selectedColor: const Color(0xFF059669),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() => _isCustomUnit = true);
                                        }
                                      },
                                    ),
                                  ],
                                ),

                                if (_isCustomUnit) ...[
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _customUnitController,
                                    style: GoogleFonts.poppins(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Tulis nama satuan (misal: Slop, Pack, Porsi)',
                                      hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Harga Beli / Modal
                                Text(
                                  'Harga Beli / Modal per ${_isCustomUnit ? (_customUnitController.text.isEmpty ? "Satuan" : _customUnitController.text) : _selectedUnitName}',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _costPriceController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    prefixText: 'Rp ',
                                    prefixStyle: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                                    hintText: '0',
                                    hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 13),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card Stok Awal & Peringatan Minimum
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined, color: Color(0xFF059669), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Inventori & Peringatan Stok',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    if (!isEditing) ...[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Stok Awal Fisik',
                                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: _initialStockController,
                                              keyboardType: TextInputType.number,
                                              style: GoogleFonts.poppins(fontSize: 13.5),
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                suffixText: _isCustomUnit ? _customUnitController.text : _selectedUnitName,
                                                suffixStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Peringatan Minimum',
                                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: _minStockController,
                                            keyboardType: TextInputType.number,
                                            style: GoogleFonts.poppins(fontSize: 13.5),
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              suffixText: _isCustomUnit ? _customUnitController.text : _selectedUnitName,
                                              suffixStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                              filled: true,
                                              fillColor: const Color(0xFFF8FAFC),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Save Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                      border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                    ),
                    child: SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? 'SIMPAN PERUBAHAN' : 'SIMPAN BAHAN BAKU',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
