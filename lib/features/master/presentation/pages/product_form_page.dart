import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../data/master_repository.dart';
import '../bloc/product_cubit.dart';
import '../bloc/category_cubit.dart';
import '../bloc/brand_cubit.dart';
import '../bloc/supplier_cubit.dart';

class ProductFormPage extends StatefulWidget {
  final Product? existingProduct;
  const ProductFormPage({super.key, this.existingProduct});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descController = TextEditingController();
  final _minStockController = TextEditingController(text: '0');
  final _consignmentRateController = TextEditingController(text: '0');

  String _productType = 'goods';
  bool _isStockManaged = true;
  int? _selectedCategoryId;
  int? _selectedBrandId;

  // Konsinyasi State
  bool _isConsignment = false;
  int? _selectedSupplierId;
  String _consignmentType = 'commission_percent'; // 'commission_percent' / 'fixed_cost'

  File? _imageFile;
  String? _existingImagePath;

  // Multi units repeater list
  final List<Map<String, dynamic>> _units = [];
  int _tempUnitIdCounter = 1;

  bool _allowManualPrice = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPriceTiersAndData();
  }

  Future<void> _loadPriceTiersAndData() async {
    if (widget.existingProduct != null) {
      final product = widget.existingProduct!;
      final repo = getIt<MasterRepository>();
      _nameController.text = product.name;
      _skuController.text = product.sku ?? '';
      _barcodeController.text = product.barcode ?? '';
      _descController.text = product.description ?? '';
      _minStockController.text = product.minStockAlert.toString();
      _productType = product.productType;
      _isStockManaged = product.isStockManaged;
      _selectedCategoryId = product.categoryId;
      _selectedBrandId = product.brandId;
      _existingImagePath = product.imagePath;
      _allowManualPrice = product.allowManualPrice;
      _isConsignment = product.isConsignment;
      _selectedSupplierId = product.supplierId;
      _consignmentType = product.consignmentType ?? 'commission_percent';
      _consignmentRateController.text = product.commissionRate.toStringAsFixed(product.consignmentType == 'fixed_cost' ? 0 : 1);

      final complete = await repo.getProductComplete(product.id);
      if (complete != null) {
        final List<ProductUnit> dbUnits = complete['units'];
        final List<ProductPrice> dbPrices = complete['prices'];

        setState(() {
          for (var u in dbUnits) {
            final tempId = u.id;
            if (tempId >= _tempUnitIdCounter) {
              _tempUnitIdCounter = tempId + 1;
            }

            final priceMap = <int, double>{};
            for (var p in dbPrices.where((p) => p.unitId == u.id && p.price > 0)) {
              priceMap[p.minQty] = p.price;
            }
            if (priceMap.isEmpty) priceMap[1] = 0.0;

            final breaks = priceMap.entries.map((e) {
              return {
                'minQtyController': TextEditingController(text: e.key.toString()),
                'priceController': TextEditingController(text: e.value.toStringAsFixed(0)),
              };
            }).toList();

            _units.add({
              'id': tempId,
              'name': u.name,
              'conversion_factor': u.conversionFactor,
              'isBase': u.isBase,
              'costPrice': u.costPrice,
              'nameController': TextEditingController(text: u.name),
              'factorController': TextEditingController(text: u.conversionFactor.toString()),
              'costController': TextEditingController(text: u.costPrice > 0 ? u.costPrice.toStringAsFixed(0) : '0'),
              'breaks': breaks,
            });
          }
        });
      }
    } else {
      _addUnitRow(isBase: true, defaultName: 'Pcs');
    }
  }

  void _addUnitRow({bool isBase = false, String defaultName = ''}) {
    final tempId = _tempUnitIdCounter++;
    setState(() {
      _units.add({
        'id': tempId,
        'name': defaultName,
        'conversion_factor': 1.0,
        'isBase': isBase,
        'costPrice': 0.0,
        'nameController': TextEditingController(text: defaultName),
        'factorController': TextEditingController(text: isBase ? '1' : ''),
        'costController': TextEditingController(text: '0'),
        'breaks': <Map<String, dynamic>>[
          {
            'minQtyController': TextEditingController(text: '1'),
            'priceController': TextEditingController(text: '0'),
          },
        ],
      });
    });
  }

  void _removeUnitRow(int index) {
    final unit = _units[index];
    if (unit['isBase'] == true) {
      _showAppSnackbar('Satuan dasar (Base Unit) tidak bisa dihapus.', isError: true);
      return;
    }
    setState(() {
      for (var b in (unit['breaks'] as List)) {
        (b['minQtyController'] as TextEditingController).dispose();
        (b['priceController'] as TextEditingController).dispose();
      }
      (unit['nameController'] as TextEditingController).dispose();
      (unit['factorController'] as TextEditingController).dispose();
      (unit['costController'] as TextEditingController).dispose();
      _units.removeAt(index);
    });
  }

  void _addBreakRow(int unitIndex) {
    setState(() {
      final unit = _units[unitIndex];
      (unit['breaks'] as List).add({
        'minQtyController': TextEditingController(text: '2'),
        'priceController': TextEditingController(text: '0'),
      });
    });
  }

  void _removeBreakRow(int unitIndex, int breakIndex) {
    setState(() {
      final unit = _units[unitIndex];
      final breaks = unit['breaks'] as List;
      final b = breaks[breakIndex];
      (b['minQtyController'] as TextEditingController).dispose();
      (b['priceController'] as TextEditingController).dispose();
      breaks.removeAt(breakIndex);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1000);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showAppSnackbar('Gagal mengambil gambar: $e', isError: true);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Unggah foto produk untuk mempermudah identifikasi di kasir',
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppConstants.primaryColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.camera_alt_rounded, color: AppConstants.primaryColor, size: 30),
                            const SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppConstants.primaryColor, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.photo_library_rounded, color: Color(0xFF334155), size: 30),
                            const SizedBox(height: 8),
                            Text(
                              'Galeri Foto',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF334155), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_imageFile != null || _existingImagePath != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _imageFile = null;
                        _existingImagePath = null;
                      });
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.errorColor),
                    label: Text(
                      'Hapus Foto',
                      style: GoogleFonts.poppins(color: AppConstants.errorColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _scanBarcode() {
    bool scanned = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppConstants.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Barcode / QR',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Arahkan kamera ke kode batang produk',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      MobileScanner(
                        onDetect: (capture) {
                          if (scanned) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final code = barcodes.first.rawValue;
                            if (code != null && code.isNotEmpty) {
                              scanned = true;
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _barcodeController.text = code;
                              });
                              Navigator.pop(ctx);
                            }
                          }
                        },
                      ),
                      Center(
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppConstants.primaryLightColor, width: 2.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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
        backgroundColor: isError ? AppConstants.errorColor : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      _showAppSnackbar('Mohon lengkapi data yang wajib diisi (*)', isError: true);
      return;
    }

    // Validasi Base Unit
    final hasBase = _units.any((u) => u['isBase'] == true);
    if (!hasBase) {
      _showAppSnackbar('Harus ada setidaknya satu Satuan Dasar (Base Unit).', isError: true);
      return;
    }

    final List<ProductUnitsCompanion> unitsCompanions = [];
    final List<ProductPricesCompanion> pricesCompanions = [];

    for (var u in _units) {
      final name = (u['nameController'] as TextEditingController).text.trim();
      final factor = double.tryParse((u['factorController'] as TextEditingController).text) ?? 1.0;
      final costVal = double.tryParse((u['costController'] as TextEditingController).text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      final tempId = u['id'] as int;

      if (name.isEmpty) {
        _showAppSnackbar('Nama satuan unit tidak boleh kosong.', isError: true);
        return;
      }

      unitsCompanions.add(
        ProductUnitsCompanion(
          id: drift.Value(tempId),
          name: drift.Value(name),
          conversionFactor: drift.Value(factor),
          isBase: drift.Value(u['isBase'] == true),
          costPrice: drift.Value(costVal),
          productId: const drift.Value(0),
        ),
      );

      final breaks = u['breaks'] as List;
      for (var b in breaks) {
        final minQty = int.tryParse((b['minQtyController'] as TextEditingController).text) ?? 1;
        final priceVal = double.tryParse((b['priceController'] as TextEditingController).text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

        pricesCompanions.add(
          ProductPricesCompanion(
            unitId: drift.Value(tempId),
            priceTierId: const drift.Value(1),
            price: drift.Value(priceVal),
            minQty: drift.Value(minQty),
            productId: const drift.Value(0),
          ),
        );
      }
    }

    if (_isConsignment && _selectedSupplierId == null) {
      _showAppSnackbar('Pilih Mitra Penitip / Pemasok untuk produk konsinyasi', isError: true);
      return;
    }

    final rateVal = double.tryParse(_consignmentRateController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;

    setState(() => _isSaving = true);

    context.read<ProductCubit>().saveProduct(
      existingProduct: widget.existingProduct,
      name: _nameController.text.trim(),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      categoryId: _selectedCategoryId,
      brandId: _selectedBrandId,
      imagePath: _existingImagePath,
      productType: _productType,
      isStockManaged: _isStockManaged,
      minStockAlert: int.tryParse(_minStockController.text) ?? 0,
      allowManualPrice: _allowManualPrice,
      isConsignment: _isConsignment,
      supplierId: _isConsignment ? _selectedSupplierId : null,
      consignmentType: _isConsignment ? _consignmentType : null,
      commissionRate: _isConsignment ? rateVal : 0.0,
      units: unitsCompanions,
      prices: pricesCompanions,
      newImageFile: _imageFile,
    );
  }

  @override
  void dispose() {
      _nameController.dispose();
      _skuController.dispose();
      _barcodeController.dispose();
      _descController.dispose();
      _minStockController.dispose();
      _consignmentRateController.dispose();
      for (var u in _units) {
        (u['nameController'] as TextEditingController).dispose();
        (u['factorController'] as TextEditingController).dispose();
        (u['costController'] as TextEditingController).dispose();
        for (var b in (u['breaks'] as List)) {
          (b['minQtyController'] as TextEditingController).dispose();
          (b['priceController'] as TextEditingController).dispose();
        }
      }
      super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProduct != null;

    return BlocListener<ProductCubit, ProductState>(
      listener: (context, state) {
        if (state is ProductSaved) {
          setState(() => _isSaving = false);
          _showAppSnackbar(isEditing ? 'Data produk berhasil diperbarui!' : 'Produk baru berhasil ditambahkan!');
          Navigator.pop(context);
        }
        if (state is ProductError) {
          setState(() => _isSaving = false);
          _showAppSnackbar(state.message, isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEditing ? 'Ubah Detail Produk' : 'Tambah Produk Baru',
            style: GoogleFonts.poppins(
              color: const Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE2E8F0), height: 1),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      _buildHeaderHeroCard(),
                      const SizedBox(height: 16),
                      _buildBasicInfoSection(),
                      const SizedBox(height: 16),
                      _buildUnitsAndPricingSection(),
                      const SizedBox(height: 16),
                      _buildInventoryAndSettingsSection(),
                      const SizedBox(height: 16),
                      _buildConsignmentSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom Save Floating Action Bar
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
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      disabledBackgroundColor: AppConstants.primaryColor.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isEditing ? 'SIMPAN PERUBAHAN' : 'SIMPAN PRODUK',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header Visual Hero Card dengan Foto & Tipe Produk
  Widget _buildHeaderHeroCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Foto Thumbnail
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _buildImagePreviewWidget(),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Ringkasan Info & Tipe Produk Selector
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipe Produk',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTypeChip(
                      label: 'Barang Fisik',
                      icon: Icons.inventory_2_outlined,
                      isSelected: _productType == 'goods',
                      onTap: () {
                        setState(() {
                          _productType = 'goods';
                          _isStockManaged = true;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildTypeChip(
                      label: 'Jasa',
                      icon: Icons.design_services_outlined,
                      isSelected: _productType == 'service',
                      onTap: () {
                        setState(() {
                          _productType = 'service';
                          _isStockManaged = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _productType == 'goods' ? 'Memiliki stok fisik & pelacakan gudang' : 'Layanan / non-fisik (tanpa stok)',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppConstants.primaryColor : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppConstants.primaryColor : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviewWidget() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover);
    }
    if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      return Image.file(
        File(_existingImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (c, o, s) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8), size: 30),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF94A3B8), size: 28),
          const SizedBox(height: 2),
          Text(
            'Upload',
            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // Bagian 1: Detail Informasi Utama
  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'Informasi Utama',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk
          _buildInputField(
            label: 'Nama Produk',
            isRequired: true,
            controller: _nameController,
            hintText: 'Contoh: Kopi Susu Aren 250ml',
            prefixIcon: Icons.shopping_bag_outlined,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nama produk wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // SKU & Barcode Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Kode SKU',
                  controller: _skuController,
                  hintText: 'SKU-001',
                  prefixIcon: Icons.tag_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: 'Barcode / UPC',
                  controller: _barcodeController,
                  hintText: '899...',
                  prefixIcon: Icons.qr_code_rounded,
                  suffixWidget: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppConstants.primaryColor, size: 20),
                    onPressed: _scanBarcode,
                    tooltip: 'Scan Barcode',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kategori & Brand
          Row(
            children: [
              Expanded(
                child: BlocBuilder<CategoryCubit, CategoryState>(
                  builder: (context, catState) {
                    List<Category> cats = [];
                    if (catState is CategoryLoaded) cats = catState.categories;
                    return _buildDropdownField<int?>(
                      label: 'Kategori',
                      icon: Icons.category_outlined,
                      value: _selectedCategoryId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tanpa Kategori')),
                        ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BlocBuilder<BrandCubit, BrandState>(
                  builder: (context, brandState) {
                    List<Brand> brands = [];
                    if (brandState is BrandLoaded) brands = brandState.brands;
                    return _buildDropdownField<int?>(
                      label: 'Merek / Brand',
                      icon: Icons.branding_watermark_outlined,
                      value: _selectedBrandId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tanpa Merek')),
                        ...brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedBrandId = val),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Deskripsi
          _buildInputField(
            label: 'Deskripsi Produk (Opsional)',
            controller: _descController,
            hintText: 'Tuliskan catatan rasa, varian, atau spesifikasi...',
            maxLines: 2,
            prefixIcon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }

  // Bagian 2: Satuan & Pengaturan Harga Jual (Quantity Breaks)
  Widget _buildUnitsAndPricingSection() {
    return _buildSectionCard(
      title: 'Satuan & Harga Jual',
      icon: Icons.payments_outlined,
      action: TextButton.icon(
        onPressed: () => _addUnitRow(isBase: false, defaultName: ''),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Tambah Satuan', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          foregroundColor: AppConstants.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          visualDensity: VisualDensity.compact,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tentukan satuan penjualan (misal: Pcs, Dus, Pack) dan harga jual per kuantitas.',
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Daftar Kartu Satuan
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _units.length,
            separatorBuilder: (c, i) => const SizedBox(height: 14),
            itemBuilder: (context, unitIndex) {
              final u = _units[unitIndex];
              final isBase = u['isBase'] == true;
              final breaks = u['breaks'] as List;

              return Container(
                decoration: BoxDecoration(
                  color: isBase ? const Color(0xFFF8FAFC) : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isBase ? AppConstants.primaryColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                    width: isBase ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isBase ? AppConstants.primaryColor : const Color(0xFF64748B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBase ? 'SATUAN DASAR' : 'SATUAN TURUNAN',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!isBase)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.errorColor, size: 20),
                            onPressed: () => _removeUnitRow(unitIndex),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Hapus Satuan',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Unit Inputs (Nama & Konversi)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInputField(
                            label: 'Nama Satuan',
                            isRequired: true,
                            controller: u['nameController'],
                            hintText: isBase ? 'Pcs / Cup / Porsi' : 'Dus / Pack / Box',
                            prefixIcon: Icons.straighten_rounded,
                            onChanged: (val) => setState(() => u['name'] = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildInputField(
                            label: isBase ? 'Faktor Konversi' : 'Isi Satuan Dasar',
                            controller: u['factorController'],
                            enabled: !isBase,
                            hintText: isBase ? '1' : 'Contoh: 12',
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.calculate_outlined,
                            helperText: isBase ? 'Nilai tetap 1' : '1 ${_units[unitIndex]['nameController'].text.isEmpty ? 'Unit' : _units[unitIndex]['nameController'].text} = X ${_units.first['nameController'].text.isEmpty ? 'Base' : _units.first['nameController'].text}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Harga Beli / Modal Dasar
                    _buildInputField(
                      label: 'Harga Beli / Modal Dasar (HPP Master)',
                      controller: u['costController'],
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.shopping_bag_outlined,
                      helperText: 'Digunakan sebagai dasar HPP & Laba jika belum ada data transaksi pembelian.',
                    ),
                    const SizedBox(height: 14),

                    // Matriks Harga Bertingkat
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Harga Jual (Quantity Break)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _addBreakRow(unitIndex),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppConstants.primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tambah Tier',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          ...breaks.asMap().entries.map((entry) {
                            final breakIndex = entry.key;
                            final b = entry.value;
                            final qtyCtrl = b['minQtyController'] as TextEditingController;
                            final priceCtrl = b['priceController'] as TextEditingController;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Min Beli \u2265',
                                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 55,
                                    height: 40,
                                    child: TextFormField(
                                      controller: qtyCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 40,
                                      child: TextFormField(
                                        controller: priceCtrl,
                                        keyboardType: TextInputType.number,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: 'Rp ',
                                          prefixStyle: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (breaks.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppConstants.errorColor),
                                      onPressed: () => _removeBreakRow(unitIndex, breakIndex),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Bagian 3: Pengaturan Stok & Fleksibilitas Kasir
  Widget _buildInventoryAndSettingsSection() {
    return _buildSectionCard(
      title: 'Inventori & Kasir POS',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_productType == 'goods') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_rounded, color: AppConstants.primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola Stok Inventori',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Catat stok masuk/keluar saat penjualan & restock',
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isStockManaged,
                    activeColor: AppConstants.primaryColor,
                    onChanged: (val) => setState(() => _isStockManaged = val),
                  ),
                ],
              ),
            ),
            if (_isStockManaged) ...[
              const SizedBox(height: 12),
              _buildInputField(
                label: 'Peringatan Stok Minimum',
                controller: _minStockController,
                hintText: '0',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.warning_amber_rounded,
                helperText: 'Aplikasi akan memberi notifikasi saat stok menyentuh angka ini',
              ),
            ],
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.price_change_outlined, color: Color(0xFF334155), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input Harga Bebas di POS',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        'Kasir dapat mengubah harga secara langsung di layar kasir',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _allowManualPrice,
                  activeColor: AppConstants.primaryColor,
                  onChanged: (val) => setState(() => _allowManualPrice = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable Section Card Wrapper
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppConstants.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // Reusable Input Field
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
    bool isRequired = false,
    bool enabled = true,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    Widget? suffixWidget,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.errorColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            helperText: helperText,
            helperStyle: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
            helperMaxLines: 2,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1))
                : null,
            suffixIcon: suffixWidget,
            filled: true,
            fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // Reusable Dropdown Field
  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // Bagian 5: Pengaturan Konsinyasi (Titip Jual)
  Widget _buildConsignmentSection() {
    return _buildSectionCard(
      title: 'Skema Konsinyasi (Titip Jual)',
      icon: Icons.handshake_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Switch Konsinyasi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isConsignment ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isConsignment ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isConsignment ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: _isConsignment ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Produk Titipan Konsinyasi',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Barang milik mitra/supplier yang dibayar setelah terjual',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isConsignment,
                  activeColor: const Color(0xFF16A34A),
                  onChanged: (val) {
                    setState(() => _isConsignment = val);
                  },
                ),
              ],
            ),
          ),

          if (_isConsignment) ...[
            const SizedBox(height: 16),
            // Dropdown Supplier / Mitra Penitip
            BlocBuilder<SupplierCubit, SupplierState>(
              builder: (context, supState) {
                List<Supplier> suppliers = [];
                if (supState is SupplierLoaded) {
                  suppliers = supState.suppliers;
                }
                return _buildDropdownField<int?>(
                  label: 'Mitra Penitip / Pemasok',
                  icon: Icons.person_pin_circle_outlined,
                  value: _selectedSupplierId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('-- Pilih Mitra Penitip --'),
                    ),
                    ...suppliers.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedSupplierId = val),
                );
              },
            ),
            const SizedBox(height: 14),

            // Model Bagi Hasil
            Text(
              'Skema Bagi Hasil',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _consignmentType = 'commission_percent'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _consignmentType == 'commission_percent'
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _consignmentType == 'commission_percent'
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFCBD5E1),
                          width: _consignmentType == 'commission_percent' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.percent_rounded,
                            size: 16,
                            color: _consignmentType == 'commission_percent'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Komisi Toko (%)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _consignmentType == 'commission_percent'
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
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
                    onTap: () => setState(() => _consignmentType = 'fixed_cost'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _consignmentType == 'fixed_cost'
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _consignmentType == 'fixed_cost'
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFCBD5E1),
                          width: _consignmentType == 'fixed_cost' ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 16,
                            color: _consignmentType == 'fixed_cost'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Harga Setor (Rp)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _consignmentType == 'fixed_cost'
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
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

            // Input Nilai Komisi / Harga Setor
            _buildInputField(
              label: _consignmentType == 'commission_percent'
                  ? 'Persentase Komisi Toko (%)'
                  : 'Harga Setor Tetap ke Penitip (Rp/pcs)',
              controller: _consignmentRateController,
              keyboardType: TextInputType.number,
              hintText: _consignmentType == 'commission_percent' ? 'Contoh: 15' : 'Contoh: 8000',
              prefixIcon: _consignmentType == 'commission_percent'
                  ? Icons.pie_chart_outline_rounded
                  : Icons.attach_money_rounded,
              helperText: _consignmentType == 'commission_percent'
                  ? 'Toko mendapat persentase dari harga jual, sisanya menjadi hak penitip'
                  : 'Penitip menerima nominal tetap ini per item yang terjual',
            ),
          ],
        ],
      ),
    );
  }
}
