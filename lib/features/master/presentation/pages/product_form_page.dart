import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/curved_header.dart';
import '../../data/master_repository.dart';
import '../bloc/product_cubit.dart';
import '../bloc/category_cubit.dart';
import '../bloc/brand_cubit.dart';

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

  String _productType = 'goods';
  bool _isStockManaged = true;
  int? _selectedCategoryId;
  int? _selectedBrandId;

  File? _imageFile;
  String? _existingImagePath;

  // Multi units repeater list
  // Kita simpan ID unit sementara (misal: 1000, 1001, dst) untuk mapping harga
  final List<Map<String, dynamic>> _units = [];
  int _tempUnitIdCounter = 1;

  bool _allowManualPrice = false;

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

            // Group prices by minQty
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
              'nameController': TextEditingController(text: u.name),
              'factorController': TextEditingController(text: u.conversionFactor.toString()),
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
        'nameController': TextEditingController(text: defaultName),
        'factorController': TextEditingController(text: isBase ? '1.0' : ''),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satuan dasar (Base Unit) tidak bisa dihapus.')),
      );
      return;
    }
    setState(() {
      for (var b in (unit['breaks'] as List)) {
        (b['minQtyController'] as TextEditingController).dispose();
        (b['priceController'] as TextEditingController).dispose();
      }
      _units.removeAt(index);
    });
  }

  void _addBreakRow(int unitIndex) {
    setState(() {
      final unit = _units[unitIndex];
      (unit['breaks'] as List).add({
        'minQtyController': TextEditingController(text: '1'),
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMd)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppConstants.primaryColor),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppConstants.primaryColor),
              title: const Text('Galeri Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
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
                    'Scan Barcode Produk',
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
                          setState(() {
                            _barcodeController.text = code;
                          });
                          Navigator.pop(ctx);
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
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Validasi apakah setidaknya ada 1 base unit
    final hasBase = _units.any((u) => u['isBase'] == true);
    if (!hasBase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harus ada setidaknya satu Satuan Dasar (Base Unit).')),
      );
      return;
    }

    // Bangun Companion List
    final List<ProductUnitsCompanion> unitsCompanions = [];
    final List<ProductPricesCompanion> pricesCompanions = [];

    for (var u in _units) {
      final name = (u['nameController'] as TextEditingController).text.trim();
      final factor = double.tryParse((u['factorController'] as TextEditingController).text) ?? 1.0;
      final tempId = u['id'] as int;

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama satuan tidak boleh kosong.')),
        );
        return;
      }

      unitsCompanions.add(
        ProductUnitsCompanion(
          id: drift.Value(tempId), // Kirim tempId agar dipetakan di repository
          name: drift.Value(name),
          conversionFactor: drift.Value(factor),
          isBase: drift.Value(u['isBase'] == true),
          productId: const drift.Value(0), // Di-update oleh repo
        ),
      );

      // Ambil quantity breaks
      final breaks = u['breaks'] as List;
      for (var b in breaks) {
        final minQty = int.tryParse((b['minQtyController'] as TextEditingController).text) ?? 1;
        final priceVal = double.tryParse((b['priceController'] as TextEditingController).text) ?? 0.0;

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
    for (var u in _units) {
      (u['nameController'] as TextEditingController).dispose();
      (u['factorController'] as TextEditingController).dispose();
      for (var b in (u['breaks'] as List)) {
        (b['minQtyController'] as TextEditingController).dispose();
        (b['priceController'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductCubit, ProductState>(
      listener: (context, state) {
        if (state is ProductSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk berhasil disimpan.')),
          );
          Navigator.pop(context);
        }
        if (state is ProductError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppConstants.errorColor),
          );
        }
      },
      child: Scaffold(
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
                          widget.existingProduct == null ? 'Tambah Produk Baru' : 'Ubah Produk',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Container
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildBasicInfoCard(),
                          const SizedBox(height: 16),
                          _buildImageCard(),
                          const SizedBox(height: 16),
                          _buildUnitRepeaterCard(),
                          const SizedBox(height: 16),
                          _buildPricingMatrixCard(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Save Action
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppConstants.borderLightColor)),
                    ),
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        widget.existingProduct == null ? 'SIMPAN PRODUK' : 'UPDATE PRODUK',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Basic Info Card
  Widget _buildBasicInfoCard() {
    return Card(
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
            _buildSectionHeader('Informasi Dasar'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Produk *',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Nama produk wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barcode / UPC',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: AppConstants.primaryColor),
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Category & Brand Pickers
            BlocBuilder<CategoryCubit, CategoryState>(
              builder: (context, catState) {
                List<Category> cats = [];
                if (catState is CategoryLoaded) cats = catState.categories;
                return DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tanpa Kategori')),
                    ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                );
              },
            ),
            const SizedBox(height: 12),
            BlocBuilder<BrandCubit, BrandState>(
              builder: (context, brandState) {
                List<Brand> brands = [];
                if (brandState is BrandLoaded) brands = brandState.brands;
                return DropdownButtonFormField<int>(
                  value: _selectedBrandId,
                  decoration: const InputDecoration(labelText: 'Merek / Brand'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tanpa Merek')),
                    ...brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (val) => setState(() => _selectedBrandId = val),
                );
              },
            ),
            const SizedBox(height: 12),
            // Type & Inventory Options
            DropdownButtonFormField<String>(
              value: _productType,
              decoration: const InputDecoration(labelText: 'Tipe Produk'),
              items: const [
                DropdownMenuItem(value: 'goods', child: Text('Barang Fisik')),
                DropdownMenuItem(value: 'service', child: Text('Jasa / Layanan')),
              ],
              onChanged: (val) => setState(() {
                _productType = val ?? 'goods';
                if (_productType == 'service') {
                  _isStockManaged = false;
                }
              }),
            ),
            if (_productType == 'goods') ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kelola Stok Inventori'),
                value: _isStockManaged,
                onChanged: (val) => setState(() => _isStockManaged = val),
              ),
              if (_isStockManaged)
                TextFormField(
                  controller: _minStockController,
                  decoration: const InputDecoration(
                    labelText: 'Peringatan Stok Minimum',
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Izinkan Input Harga Manual di POS'),
                subtitle: const Text('Kasir bisa mengubah harga saat transaksi'),
                value: _allowManualPrice,
                onChanged: (val) => setState(() => _allowManualPrice = val),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 2. Image Picker Card
  Widget _buildImageCard() {
    return Card(
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
            _buildSectionHeader('Foto Produk'),
            const SizedBox(height: 16),
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover),
              )
            else if (_existingImagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                child: Image.file(File(_existingImagePath!), height: 180, fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => Container(
                          height: 100,
                          color: AppConstants.backgroundColor,
                          child: const Icon(Icons.broken_image, size: 40),
                        )),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(Icons.add_a_photo_outlined, size: 40, color: AppConstants.textLightColor),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.photo_camera),
              label: const Text('PILIH FOTO PRODUK'),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Multi Unit Repeater Card
  Widget _buildUnitRepeaterCard() {
    return Card(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Satuan Multi-Unit'),
                TextButton.icon(
                  onPressed: () => _addUnitRow(isBase: false, defaultName: ''),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Satuan'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _units.length,
              itemBuilder: (context, index) {
                final u = _units[index];
                final isBase = u['isBase'] == true;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Base unit indicator
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isBase
                              ? AppConstants.primaryColor.withValues(alpha: 0.1)
                              : AppConstants.backgroundColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isBase ? 'Base' : 'Sub',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isBase ? AppConstants.primaryColor : AppConstants.textLightColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Unit name input
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: u['nameController'],
                          decoration: const InputDecoration(
                            labelText: 'Nama Unit (e.g. Pcs, Box)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onChanged: (val) {
                            setState(() {
                              u['name'] = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Conversion Factor input
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: u['factorController'],
                          enabled: !isBase,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Isi Konversi',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      // Delete action
                      if (!isBase)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => _removeUnitRow(index),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingMatrixCard() {
    return Card(
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
            _buildSectionHeader('Harga Bertingkat (Quantity Break)'),
            const SizedBox(height: 12),
            const Text(
              'Atur harga berbeda berdasarkan jumlah pembelian.',
              style: TextStyle(fontSize: 12, color: AppConstants.textLightColor),
            ),
            const SizedBox(height: 16),
            ..._units.map((u) {
              final unitName = (u['nameController'] as TextEditingController).text;
              final isBase = u['isBase'] == true;
              final unitIndex = _units.indexOf(u);
              final breaks = u['breaks'] as List;

              if (unitName.trim().isEmpty) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Satuan: $unitName ${isBase ? "(Satuan Dasar)" : ""}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ...breaks.asMap().entries.map((entry) {
                      final i = entry.key;
                      final b = entry.value;
                      final qtyCtrl = b['minQtyController'] as TextEditingController;
                      final priceCtrl = b['priceController'] as TextEditingController;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Text('Qty \u2265 ', style: TextStyle(fontSize: 13)),
                            SizedBox(
                              width: 50,
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  prefixText: 'Rp ',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            if (breaks.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppConstants.errorColor),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _removeBreakRow(unitIndex, i),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _addBreakRow(unitIndex),
                      child: Row(
                        children: [
                          const Icon(Icons.add_circle_outline, size: 16, color: AppConstants.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Tambah Break',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppConstants.textDarkColor,
          ),
        ),
      ],
    );
  }
}
