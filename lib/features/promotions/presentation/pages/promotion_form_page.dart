import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../master/data/master_repository.dart';
import '../../../pos/presentation/bloc/cart_cubit.dart';
import '../../data/promotion_repository.dart';
import '../bloc/promotion_cubit.dart';

class PromotionFormPage extends StatefulWidget {
  final Promotion? promotion;

  const PromotionFormPage({super.key, this.promotion});

  @override
  State<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends State<PromotionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _minSpendController;
  late TextEditingController _discountValController;
  late TextEditingController _buyQtyController;
  late TextEditingController _rewardQtyController;
  late TextEditingController _specialPriceController;

  String _promoType = 'buy_x_get_y'; // buy_x_get_y, min_purchase_discount, product_discount, purchase_with_purchase
  String _discountType = 'nominal'; // nominal, percentage
  bool _memberOnly = false;
  bool _isActive = true;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59).add(const Duration(days: 30));

  Product? _selectedBuyProduct;
  Category? _selectedBuyCategory;
  Product? _selectedRewardProduct;

  List<Product> _allProducts = [];
  List<Category> _allCategories = [];
  bool _isLoadingMaster = true;

  @override
  void initState() {
    super.initState();
    final p = widget.promotion;

    _nameController = TextEditingController(text: p?.name ?? '');
    _codeController = TextEditingController(text: p?.code ?? '');
    _minSpendController = TextEditingController(
      text: p != null && p.minPurchaseAmount > 0 ? p.minPurchaseAmount.toStringAsFixed(0) : '',
    );
    _discountValController = TextEditingController(
      text: p != null && p.discountValue > 0 ? p.discountValue.toStringAsFixed(0) : '',
    );
    _buyQtyController = TextEditingController(
      text: p != null ? p.buyQuantity.toStringAsFixed(0) : '1',
    );
    _rewardQtyController = TextEditingController(
      text: p != null ? p.getQuantity.toStringAsFixed(0) : '1',
    );
    _specialPriceController = TextEditingController(
      text: p?.specialPrice != null ? p!.specialPrice!.toStringAsFixed(0) : '',
    );

    if (p != null) {
      _promoType = p.type;
      _discountType = p.discountType;
      _memberOnly = p.memberOnly;
      _isActive = p.isActive;
      _startDate = p.startDate;
      _endDate = p.endDate;
    }

    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    try {
      final masterRepo = getIt<MasterRepository>();
      final allProds = await masterRepo.getProducts();
      // Hanya tampilkan produk siap jual / reguler, jangan tampilkan bahan racikan mentah (raw_material)
      final prods = allProds
          .where((p) => p.productType != 'raw_material' && p.isActive)
          .toList();
      final cats = await masterRepo.getCategories();

      if (mounted) {
        setState(() {
          _allProducts = prods;
          _allCategories = cats;

          if (widget.promotion != null) {
            if (widget.promotion!.buyProductId != null) {
              _selectedBuyProduct = prods.cast<Product?>().firstWhere(
                    (item) => item?.id == widget.promotion!.buyProductId,
                    orElse: () => null,
                  );
            }
            if (widget.promotion!.categoryId != null) {
              _selectedBuyCategory = cats.cast<Category?>().firstWhere(
                    (item) => item?.id == widget.promotion!.categoryId,
                    orElse: () => null,
                  );
            }
            if (widget.promotion!.getProductId != null) {
              _selectedRewardProduct = prods.cast<Product?>().firstWhere(
                    (item) => item?.id == widget.promotion!.getProductId,
                    orElse: () => null,
                  );
            }
          }
          _isLoadingMaster = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMaster = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _minSpendController.dispose();
    _discountValController.dispose();
    _buyQtyController.dispose();
    _rewardQtyController.dispose();
    _specialPriceController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _openProductPicker({required bool isReward}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _allProducts.where((p) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              final matchesName = p.name.toLowerCase().contains(q);
              final matchesBarcode = p.barcode != null && p.barcode!.toLowerCase().contains(q);
              final matchesSku = p.sku != null && p.sku!.toLowerCase().contains(q);
              return matchesName || matchesBarcode || matchesSku;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isReward ? 'Pilih Produk Bonus / Hadiah' : 'Pilih Produk Pemicu',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau barcode...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('Produk tidak ditemukan',
                                    style: GoogleFonts.poppins(color: Colors.grey)))
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final p = filtered[idx];
                                  return ListTile(
                                    title: Text(p.name,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    subtitle: Text('SKU: ${p.sku ?? "-"}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 11, color: Colors.grey)),
                                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                                    onTap: () {
                                      setState(() {
                                        if (isReward) {
                                          _selectedRewardProduct = p;
                                        } else {
                                          _selectedBuyProduct = p;
                                        }
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
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
      },
    );
  }

  void _savePromotion() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    String code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      code = 'AUTO_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    double minSpend = double.tryParse(_minSpendController.text.replaceAll('.', '')) ?? 0.0;
    double discVal = double.tryParse(_discountValController.text.replaceAll('.', '')) ?? 0.0;
    double buyQty = double.tryParse(_buyQtyController.text) ?? 1.0;
    double rewardQty = double.tryParse(_rewardQtyController.text) ?? 1.0;
    double? specialPrice = double.tryParse(_specialPriceController.text.replaceAll('.', ''));

    // Validasi kondisi per tipe
    if (_promoType == 'buy_x_get_y' && _selectedBuyProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk utama untuk Promo Beli X Gratis Y!')),
      );
      return;
    }

    if (_promoType == 'purchase_with_purchase') {
      if (_selectedRewardProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih produk tebus murah!')),
        );
        return;
      }
      if (specialPrice == null || specialPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masukkan harga tebus murah yang valid!')),
        );
        return;
      }
    }

    final companion = PromotionsCompanion(
      id: widget.promotion != null ? drift.Value(widget.promotion!.id) : const drift.Value.absent(),
      name: drift.Value(name),
      code: drift.Value(code),
      type: drift.Value(_promoType),
      minPurchaseAmount: drift.Value(minSpend),
      discountType: drift.Value(_discountType),
      discountValue: drift.Value(discVal),
      buyProductId: drift.Value(_selectedBuyProduct?.id),
      buyQuantity: drift.Value(buyQty),
      getProductId: drift.Value(_selectedRewardProduct?.id ?? _selectedBuyProduct?.id),
      getQuantity: drift.Value(rewardQty),
      specialPrice: drift.Value(specialPrice),
      categoryId: drift.Value(_selectedBuyCategory?.id),
      memberOnly: drift.Value(_memberOnly),
      startDate: drift.Value(_startDate),
      endDate: drift.Value(_endDate),
      isActive: drift.Value(_isActive),
      createdAt: widget.promotion != null ? drift.Value(widget.promotion!.createdAt) : drift.Value(DateTime.now()),
    );

    final cubit = context.read<PromotionCubit>();
    if (widget.promotion == null) {
      cubit.createPromotion(companion).then((ok) async {
        if (ok && mounted) {
          final activePromos = await getIt<PromotionRepository>().getActivePromotions();
          if (mounted) {
            context.read<CartCubit>().setActivePromotions(activePromos);
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Program promosi berhasil dibuat!'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }
      });
    } else {
      cubit.updatePromotion(companion).then((ok) async {
        if (ok && mounted) {
          final activePromos = await getIt<PromotionRepository>().getActivePromotions();
          if (mounted) {
            context.read<CartCubit>().setActivePromotions(activePromos);
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Program promosi berhasil diperbarui!'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.promotion == null ? 'Tambah Program Promo' : 'Edit Program Promo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: _savePromotion,
              icon: const Icon(Icons.save_rounded, size: 18, color: AppConstants.primaryColor),
              label: Text(
                'Simpan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppConstants.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingMaster
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── INFORMASI DASAR ─────────────────────────────────────
                  _buildSectionHeader('Informasi Dasar Promosi', Icons.campaign_rounded),
                  const SizedBox(height: 10),
                  _buildCardContainer(
                    children: [
                      // Nama Promo
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(
                          'Nama Promo (Wajib)',
                          'Contoh: Promo Merdeka Beli 1 Gratis 1',
                          Icons.local_offer_outlined,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Nama promo tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 12),

                      // Tipe Promosi Dropdown
                      DropdownButtonFormField<String>(
                        value: _promoType,
                        isExpanded: true,
                        decoration: _inputDecoration('Tipe Program Promo', '', Icons.category_outlined),
                        items: const [
                          DropdownMenuItem(
                            value: 'buy_x_get_y',
                            child: Text(
                              'Beli X Gratis Y (BOGO)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'min_purchase_discount',
                            child: Text(
                              'Diskon Minimal Belanja Toko',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'product_discount',
                            child: Text(
                              'Diskon Spesifik Produk / Kategori',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'purchase_with_purchase',
                            child: Text(
                              'Tebus Murah (PWP)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _promoType = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Kode Kupon / Voucher (Opsional)
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 1),
                        decoration: _inputDecoration(
                          'Kode Kupon (Opsional)',
                          'Kosongkan jika otomatis aktif tanpa kupon',
                          Icons.qr_code_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── ATURAN SPESIFIK BERDASARKAN TIPE ───────────────────
                  _buildSectionHeader('Aturan & Ketentuan Promo', Icons.rule_rounded),
                  const SizedBox(height: 10),
                  _buildCardContainer(
                    children: [
                      if (_promoType == 'buy_x_get_y') ...[
                        _buildProductSelectorTile(
                          title: 'Produk Yang Dibeli (Pemicu)',
                          subtitle: _selectedBuyProduct?.name ?? 'Klik untuk pilih produk',
                          icon: Icons.shopping_basket_outlined,
                          onTap: () => _openProductPicker(isReward: false),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _buyQtyController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Beli Min. Qty', '1', Icons.numbers_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _rewardQtyController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Gratis Qty', '1', Icons.card_giftcard_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildProductSelectorTile(
                          title: 'Produk Hadiah Gratis',
                          subtitle: _selectedRewardProduct?.name ?? (_selectedBuyProduct?.name ?? 'Sama dengan produk dibeli'),
                          icon: Icons.redeem_rounded,
                          onTap: () => _openProductPicker(isReward: true),
                        ),
                      ] else if (_promoType == 'min_purchase_discount') ...[
                        TextFormField(
                          controller: _minSpendController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDecoration('Minimal Total Belanja (Rp)', '100.000', Icons.payments_outlined),
                          validator: (v) => v == null || v.isEmpty ? 'Masukkan minimal belanja' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<String>(
                                value: _discountType,
                                isExpanded: true,
                                decoration: _inputDecoration('Jenis Potongan', '', Icons.percent_rounded),
                                items: const [
                                  DropdownMenuItem(value: 'nominal', child: Text('Nominal (Rp)', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'percentage', child: Text('Persen (%)', overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _discountType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: _discountValController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration(
                                  _discountType == 'percentage' ? 'Nilai (%)' : 'Nilai (Rp)',
                                  _discountType == 'percentage' ? '10' : '15.000',
                                  Icons.discount_outlined,
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Masukkan nilai' : null,
                              ),
                            ),
                          ],
                        ),
                      ] else if (_promoType == 'product_discount') ...[
                        _buildProductSelectorTile(
                          title: 'Pilih Produk Sasaran (Spesifik)',
                          subtitle: _selectedBuyProduct?.name ?? 'Klik untuk pilih produk',
                          icon: Icons.inventory_2_outlined,
                          onTap: () => _openProductPicker(isReward: false),
                        ),
                        const SizedBox(height: 10),
                        if (_allCategories.isNotEmpty)
                          DropdownButtonFormField<int?>(
                            value: _selectedBuyCategory?.id,
                            isExpanded: true,
                            decoration: _inputDecoration('Atau Pilih Kategori', '', Icons.category_outlined),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Tidak dipilih (Per Produk Saja)', overflow: TextOverflow.ellipsis),
                              ),
                              ..._allCategories.map(
                                (c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedBuyCategory = val == null
                                    ? null
                                    : _allCategories.firstWhere((c) => c.id == val);
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: DropdownButtonFormField<String>(
                                value: _discountType,
                                isExpanded: true,
                                decoration: _inputDecoration('Jenis Diskon', '', Icons.percent_rounded),
                                items: const [
                                  DropdownMenuItem(value: 'percentage', child: Text('Persen (%)', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'nominal', child: Text('Nominal (Rp)', overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _discountType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: _discountValController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Nilai Potongan', '10', Icons.discount_outlined),
                                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                              ),
                            ),
                          ],
                        ),
                      ] else if (_promoType == 'purchase_with_purchase') ...[
                        TextFormField(
                          controller: _minSpendController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Syarat Min. Belanja (Rp)', '50.000', Icons.shopping_bag_outlined),
                        ),
                        const SizedBox(height: 12),
                        _buildProductSelectorTile(
                          title: 'Produk Yang Ditebus Murah',
                          subtitle: _selectedRewardProduct?.name ?? 'Pilih produk tebus murah',
                          icon: Icons.stars_rounded,
                          onTap: () => _openProductPicker(isReward: true),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _specialPriceController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Harga Tebus (Rp)', '5.000', Icons.price_change_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _rewardQtyController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Maks. Tebus Qty', '1', Icons.pin_outlined),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── JADWAL & STATUS ────────────────────────────────────
                  _buildSectionHeader('Periode & Pengaturan', Icons.calendar_month_rounded),
                  const SizedBox(height: 10),
                  _buildCardContainer(
                    children: [
                      // Periode Tanggal
                      InkWell(
                        onTap: _selectDateRange,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range_rounded, color: AppConstants.primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Periode Berlaku',
                                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Hak Pelanggan
                      DropdownButtonFormField<bool>(
                        value: _memberOnly,
                        isExpanded: true,
                        decoration: _inputDecoration('Target Pelanggan', '', Icons.group_outlined),
                        items: const [
                          DropdownMenuItem(value: false, child: Text('Semua Pelanggan & Umum', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: true, child: Text('Khusus Member / Terdaftar', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _memberOnly = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Status Aktif Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Aktifkan Program Promosi',
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            _isActive ? 'Promo akan otomatis dievaluasi di kasir POS' : 'Promo dinonaktifkan sementara',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                        value: _isActive,
                        activeThumbColor: AppConstants.primaryColor,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0F172A)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderLightColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildProductSelectorTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppConstants.primaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600),
      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
