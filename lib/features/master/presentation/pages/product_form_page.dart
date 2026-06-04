import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
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

  // List of price tiers loaded from database
  List<PriceTier> _priceTiers = [];

  // Matrix Harga: map kunci "tempUnitId_priceTierId" -> controller price
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _loadPriceTiersAndData();
  }

  Future<void> _loadPriceTiersAndData() async {
    final repo = getIt<MasterRepository>();
    final tiers = await repo.getPriceTiers();
    setState(() {
      _priceTiers = tiers;
    });

    if (widget.existingProduct != null) {
      final product = widget.existingProduct!;
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

      // Load existing units & prices
      final complete = await repo.getProductComplete(product.id);
      if (complete != null) {
        final List<ProductUnit> dbUnits = complete['units'];
        final List<ProductPrice> dbPrices = complete['prices'];

        setState(() {
          for (var u in dbUnits) {
            final tempId = u.id; // Gunakan id DB asli sebagai temp ID
            if (tempId >= _tempUnitIdCounter) {
              _tempUnitIdCounter = tempId + 1;
            }

            _units.add({
              'id': tempId,
              'name': u.name,
              'conversion_factor': u.conversionFactor,
              'isBase': u.isBase,
              'nameController': TextEditingController(text: u.name),
              'factorController': TextEditingController(text: u.conversionFactor.toString()),
            });

            // Map prices
            for (var pt in _priceTiers) {
              final priceObj = dbPrices.firstWhere(
                (p) => p.unitId == u.id && p.priceTierId == pt.id,
                orElse: () => ProductPrice(id: 0, productId: product.id, unitId: u.id, priceTierId: pt.id, price: 0.0, minQty: 1),
              );

              final key = "${tempId}_${pt.id}";
              _priceControllers[key] = TextEditingController(text: priceObj.price.toStringAsFixed(0));
            }
          }
        });
      }
    } else {
      // Default: tambah satu Base Unit (Pcs)
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
      });

      // Hubungkan ke price matrix controllers
      for (var pt in _priceTiers) {
        final key = "${tempId}_${pt.id}";
        _priceControllers[key] = TextEditingController(text: '0');
      }
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
    
    final tempId = unit['id'] as int;
    setState(() {
      _units.removeAt(index);
      for (var pt in _priceTiers) {
        final key = "${tempId}_${pt.id}";
        _priceControllers.remove(key);
      }
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

      // Ambil harga matrix
      for (var pt in _priceTiers) {
        final key = "${tempId}_${pt.id}";
        final priceVal = double.tryParse(_priceControllers[key]?.text ?? '0') ?? 0.0;

        pricesCompanions.add(
          ProductPricesCompanion(
            unitId: drift.Value(tempId), // tempId
            priceTierId: drift.Value(pt.id),
            price: drift.Value(priceVal),
            minQty: const drift.Value(1),
            productId: const drift.Value(0), // Di-update oleh repo
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
    }
    for (var ctrl in _priceControllers.values) {
      ctrl.dispose();
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
                    decoration: const InputDecoration(
                      labelText: 'Barcode / UPC',
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

  // 4. Pricing Matrix Card
  Widget _buildPricingMatrixCard() {
    if (_priceTiers.isEmpty) {
      return const SizedBox();
    }

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
            _buildSectionHeader('Matriks Harga Jual'),
            const SizedBox(height: 12),
            const Text(
              'Masukkan harga jual untuk masing-masing Satuan Unit per Price Tier yang aktif.',
              style: TextStyle(fontSize: 12, color: AppConstants.textLightColor),
            ),
            const SizedBox(height: 16),
            ..._units.map((u) {
              final unitName = (u['nameController'] as TextEditingController).text;
              final isBase = u['isBase'] == true;
              final tempId = u['id'] as int;

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
                    Row(
                      children: _priceTiers.map((pt) {
                        final key = "${tempId}_${pt.id}";
                        final ctrl = _priceControllers[key];

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: TextFormField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: pt.name,
                                prefixText: 'Rp ',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
