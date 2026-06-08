import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../master/presentation/bloc/category_cubit.dart';
import '../../../master/presentation/bloc/customer_cubit.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';
import '../bloc/cart_cubit.dart';
import '../bloc/sales_cubit.dart';
import 'payment_page.dart';
import 'held_orders_page.dart';
import 'sales_history_page.dart';

class _UnitInputState {
  final ProductUnit unit;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  double qty;
  double price;

  _UnitInputState({
    required this.unit,
    required this.qtyController,
    required this.priceController,
    required this.qty,
    required this.price,
  });
}

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> with TickerProviderStateMixin {
  late TabController _mobileTabController;
  late AnimationController _fabAnimController;
  String _searchQuery = '';
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _catalogProducts = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Load data via Bloc
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesCubit>().loadProducts();
      context.read<CategoryCubit>().loadCategories();
      context.read<CustomerCubit>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    _fabAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showBarcodeScanner() {
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
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final code = barcodes.first.rawValue;
                        if (code != null) {
                          Navigator.pop(ctx);
                          _handleBarcodeScanned(code);
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

  void _handleBarcodeScanned(String barcode) {
    try {
      final match = _catalogProducts.firstWhere(
        (p) =>
            ((p['product'] as Product).barcode == barcode) ||
            ((p['product'] as Product).sku == barcode),
        orElse: () => <String, dynamic>{},
      );

      if (match.isNotEmpty) {
        final Product product = match['product'];
        final List<ProductUnit> units = List<ProductUnit>.from(match['units']);
        final List<ProductPrice> prices =
            List<ProductPrice>.from(match['prices']);
        context.read<CartCubit>().addToCart(product, units, prices);
        _showAddedToCartFeedback(product.name);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Produk tidak ditemukan untuk barcode tersebut.'),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  void _showAddedToCartFeedback(String name) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '+ $name ditambahkan',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
    // Switch to cart tab on mobile
    if (_mobileTabController.length == 2 && MediaQuery.of(context).size.width <= 720) {
      // Don't auto-switch, just show feedback
    }
  }

  void _showGlobalDiscountDialog() {
    final discController = TextEditingController();
    bool isPercentage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.discount_rounded,
                    color: AppConstants.warningColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Diskon Global',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: discController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      isPercentage ? 'Diskon (%)' : 'Diskon (Rupiah)',
                  prefixText: isPercentage ? null : 'Rp ',
                  suffixText: isPercentage ? '%' : null,
                  filled: true,
                  fillColor: AppConstants.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppConstants.primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppConstants.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => isPercentage = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isPercentage
                                ? AppConstants.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Nominal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: !isPercentage
                                    ? Colors.white
                                    : AppConstants.textLightColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => isPercentage = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isPercentage
                                ? AppConstants.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Persen (%)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isPercentage
                                    ? Colors.white
                                    : AppConstants.textLightColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'BATAL',
                style: TextStyle(color: AppConstants.textLightColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final d = double.tryParse(discController.text) ?? 0.0;
                context
                    .read<CartCubit>()
                    .applyGlobalDiscount(d, isPercentage: isPercentage);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('TERAPKAN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 720;
    final authState = context.read<AuthCubit>().state;
    User? currentUser;
    CashierSession? activeSession;
    if (authState is AuthAuthenticated) {
      currentUser = authState.user;
      activeSession = authState.session;
    }

    return BlocListener<CartCubit, CartState>(
      listener: (context, cartState) {
        if (cartState.items.isEmpty) {
          try {
            if (_mobileTabController.index != 0) {
              _mobileTabController.animateTo(0);
            }
          } catch (_) {}
        }
      },
      child: BlocBuilder<SalesCubit, SalesState>(
        builder: (context, state) {
          if (state is SalesProductsLoaded) {
            _catalogProducts = state.products;
          }

          return Scaffold(
            backgroundColor: AppConstants.backgroundColor,
            body: Column(
              children: [
                // ─── Top Bar Indigo ───
                _buildTopBar(currentUser),

                if (state is SalesLoading && _catalogProducts.isEmpty)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: SafeArea(
                      bottom: true,
                      top: false,
                      child: isTablet
                          ? _buildTabletLayout(currentUser, activeSession)
                          : _buildMobileLayout(currentUser, activeSession),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // TOP BAR — Flat Indigo header
  // ═════════════════════════════════════════════════
  Widget _buildTopBar(User? user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppConstants.primaryDarkColor, AppConstants.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Kasir POS',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user != null)
                    Text(
                      user.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Held orders badge
              BlocBuilder<CartCubit, CartState>(
                builder: (context, cart) {
                  return _buildTopBarAction(
                    icon: Icons.pause_circle_outline_rounded,
                    tooltip: 'Transaksi Ditahan',
                    onTap: () => _openHeldOrders(user),
                  );
                },
              ),
              _buildTopBarAction(
                icon: Icons.qr_code_scanner_rounded,
                tooltip: 'Scan Barcode',
                onTap: _showBarcodeScanner,
              ),
              _buildTopBarAction(
                icon: Icons.history_rounded,
                tooltip: 'Riwayat Transaksi',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesHistoryPage(),
                  ),
                ),
              ),
              _buildTopBarAction(
                icon: Icons.discount_outlined,
                tooltip: 'Diskon Global',
                onTap: _showGlobalDiscountDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  void _openHeldOrders(User? user) {
    if (user == null) return;
    final custState = context.read<CustomerCubit>().state;
    List<Customer> customers = [];
    if (custState is CustomerLoaded) customers = custState.customers;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HeldOrdersPage(
          user: user,
          allProducts: _catalogProducts,
          allCustomers: customers,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═════════════════════════════════════════════════
  Widget _buildMobileLayout(User? user, CashierSession? session) {
    return Column(
      children: [
        // Custom TabBar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _mobileTabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppConstants.primaryColor,
            unselectedLabelColor: AppConstants.textLightColor,
            labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.grid_view_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Produk'),
                  ],
                ),
              ),
              Tab(
                child: BlocBuilder<CartCubit, CartState>(
                  builder: (context, cart) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_bag_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('Keranjang'),
                        if (cart.items.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${cart.items.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _mobileTabController,
            children: [
              _buildCatalogPanel(),
              _buildCartPanel(user, session),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════
  // TABLET LAYOUT
  // ═════════════════════════════════════════════════
  Widget _buildTabletLayout(User? user, CashierSession? session) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 6,
          child: _buildCatalogPanel(),
        ),
        Container(
          width: 1,
          color: AppConstants.borderLightColor,
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: _buildCartPanel(user, session),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════
  // CATALOG PANEL — Product Grid
  // ═════════════════════════════════════════════════
  Widget _buildCatalogPanel() {
    var filtered = List<Map<String, dynamic>>.from(_catalogProducts);

    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) {
        final Product prod = p['product'];
        return prod.categoryId == _selectedCategoryId;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final Product prod = p['product'];
        return prod.name.toLowerCase().contains(_searchQuery) ||
            (prod.sku?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        return Column(
          children: [
            // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari produk atau scan barcode...',
                hintStyle: GoogleFonts.poppins(
                    color: AppConstants.textLightColor, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppConstants.textLightColor, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),

        // ── Category Chips ──
        BlocBuilder<CategoryCubit, CategoryState>(
          builder: (context, catState) {
            List<Category> cats = [];
            if (catState is CategoryLoaded) cats = catState.categories;

            return SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                children: [
                  _buildCategoryChip('Semua', null),
                  ...cats.map((c) => _buildCategoryChip(c.name, c.id)),
                ],
              ),
            );
          },
        ),

        // ── Products Grid ──
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada produk ditemukan',
                        style: GoogleFonts.poppins(
                            color: AppConstants.textLightColor, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildProductCard(item, cartState);
                  },
                ),
        ),
        
        // ── Bottom Summary ──
        if (cartState.items.isNotEmpty && MediaQuery.of(context).size.width <= 720)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total (${cartState.items.length} Item)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(cartState.grandTotal),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    _mobileTabController.animateTo(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text(
                    'Lihat Keranjang',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  });
}

  Widget _buildCategoryChip(String label, int? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategoryId = categoryId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primaryColor
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppConstants.primaryColor
                  : AppConstants.borderLightColor,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppConstants.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.white : AppConstants.textDarkColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item, CartState cartState) {
    final Product prod = item['product'];
    final List<ProductUnit> units = List<ProductUnit>.from(item['units'] ?? []);
    final List<ProductPrice> prices =
        List<ProductPrice>.from(item['prices'] ?? []);

    // Get base price
    ProductUnit? baseUnit;
    if (units.isNotEmpty) {
      baseUnit = units.cast<ProductUnit?>().firstWhere(
            (u) => u!.isBase,
            orElse: () => units.first,
          );
    }

    double basePrice = 0.0;
    String unitName = 'Pcs';
    if (baseUnit != null) {
      unitName = baseUnit.name;
      if (prices.isNotEmpty) {
        final priceObj = prices.cast<ProductPrice?>().firstWhere(
              (p) => p!.unitId == baseUnit!.id && p.priceTierId == 1,
              orElse: () => prices.first,
            );
        if (priceObj != null) basePrice = priceObj.price;
      }
    }

    // Product image
    Widget imageWidget;
    if (prod.imagePath != null &&
        prod.imagePath!.isNotEmpty &&
        File(prod.imagePath!).existsSync()) {
      imageWidget = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Image.file(
          File(prod.imagePath!),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else {
      // Fallback icon based on category
      imageWidget = Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          gradient: LinearGradient(
            colors: [
              AppConstants.primaryColor.withValues(alpha: 0.06),
              AppConstants.primaryColor.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.inventory_2_rounded,
            size: 36,
            color: AppConstants.primaryColor.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final bool isSelected = cartState.items.any((c) => c.product.id == prod.id);

    return GestureDetector(
      onTap: () {
        if (units.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Produk belum memiliki satuan unit.'),
              backgroundColor: AppConstants.warningColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
          return;
        }
        _showProductModal(context, item, cartState);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image / icon
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Positioned.fill(child: imageWidget),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppConstants.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Price badge
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor
                                .withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        CurrencyFormatter.format(basePrice),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppConstants.textDarkColor,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '/ $unitName',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppConstants.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (prod.sku != null && prod.sku!.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            prod.sku!,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: AppConstants.textLightColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductModal(BuildContext context, Map<String, dynamic> item, CartState cartState) {
    final Product prod = item['product'];
    final List<ProductUnit> units = List<ProductUnit>.from(item['units'] ?? []);
    final List<ProductPrice> prices = List<ProductPrice>.from(item['prices'] ?? []);

    // Helper functions to fetch qty and price for a specific unit
    double getQtyForUnit(ProductUnit unit) {
      final match = cartState.items.cast<CartItem?>().firstWhere(
        (c) => c!.product.id == prod.id && c.unit.id == unit.id,
        orElse: () => null,
      );
      return match?.quantity ?? 0.0;
    }

    double getPriceForUnit(ProductUnit unit, int tierId) {
      // If already in cart, use that price
      final match = cartState.items.cast<CartItem?>().firstWhere(
        (c) => c!.product.id == prod.id && c.unit.id == unit.id,
        orElse: () => null,
      );
      if (match != null) {
        return match.price;
      }
      // Otherwise get default price for tier
      if (prices.isNotEmpty) {
        final priceObj = prices.firstWhere(
          (p) => p.unitId == unit.id && p.priceTierId == tierId,
          orElse: () => prices.firstWhere(
            (p) => p.unitId == unit.id,
            orElse: () => prices.first,
          ),
        );
        return priceObj.price;
      }
      return 0.0;
    }

    // Determine initial selected price tier
    final existingInCart = cartState.items.where((c) => c.product.id == prod.id);
    int selectedItemTierId = existingInCart.isNotEmpty 
        ? existingInCart.first.priceTierId 
        : cartState.selectedPriceTierId;

    // Is the product completely new to the cart?
    final bool isProductNew = existingInCart.isEmpty;

    // Create unit states
    final List<_UnitInputState> unitStates = units.map((u) {
      double initialQty = getQtyForUnit(u);
      if (isProductNew && u.isBase && initialQty == 0.0) {
        initialQty = 1.0; // pre-fill base unit with 1.0
      }
      final double initialPrice = getPriceForUnit(u, selectedItemTierId);

      return _UnitInputState(
        unit: u,
        qty: initialQty,
        price: initialPrice,
        qtyController: TextEditingController(
          text: initialQty > 0 
              ? initialQty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '') 
              : '',
        ),
        priceController: TextEditingController(
          text: initialPrice.toStringAsFixed(0),
        ),
      );
    }).toList();

    // Check if there was any discount for this product in the cart
    double initialDiscount = 0.0;
    for (final c in existingInCart) {
      if (c.discountAmount > 0) {
        initialDiscount = c.discountAmount;
        break;
      }
    }

    final discController = TextEditingController(
      text: initialDiscount > 0 ? initialDiscount.toStringAsFixed(0) : '',
    );
    double discount = initialDiscount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Helper to rebuild default prices if price tier changes
          void updatePricesForTier(int tierId) {
            selectedItemTierId = tierId;
            for (var state in unitStates) {
              if (prices.isNotEmpty) {
                final priceObj = prices.firstWhere(
                  (p) => p.unitId == state.unit.id && p.priceTierId == tierId,
                  orElse: () => prices.firstWhere(
                    (p) => p.unitId == state.unit.id,
                    orElse: () => prices.first,
                  ),
                );
                state.price = priceObj.price;
                state.priceController.text = priceObj.price.toStringAsFixed(0);
              }
            }
          }

          final totalQty = unitStates.fold<double>(0.0, (sum, u) => sum + u.qty);

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prod.name,
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Multi-Satuan & Harga Manual',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppConstants.textLightColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price Tier Selector Row
                    Text(
                      'Tipe Harga',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                updatePricesForTier(1);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedItemTierId == 1
                                    ? AppConstants.primaryColor
                                    : AppConstants.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedItemTierId == 1
                                      ? AppConstants.primaryColor
                                      : AppConstants.borderLightColor,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Harga Umum',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedItemTierId == 1 ? Colors.white : AppConstants.textDarkColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                updatePricesForTier(2);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedItemTierId == 2
                                    ? AppConstants.primaryColor
                                    : AppConstants.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedItemTierId == 2
                                      ? AppConstants.primaryColor
                                      : AppConstants.borderLightColor,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Harga Grosir',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedItemTierId == 2 ? Colors.white : AppConstants.textDarkColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Units Qty & Price Editor List
                    Text(
                      'Input Jumlah & Harga Satuan',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unitStates.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, unitIndex) {
                        final uState = unitStates[unitIndex];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: uState.qty > 0 
                                  ? AppConstants.primaryColor.withValues(alpha: 0.5) 
                                  : AppConstants.borderLightColor,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uState.unit.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppConstants.textDarkColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Manual Price field
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: uState.priceController,
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Harga Manual',
                                        prefixText: 'Rp ',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppConstants.borderLightColor),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setModalState(() {
                                          uState.price = double.tryParse(val) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Qty Stepper
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppConstants.backgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_rounded, size: 18),
                                            onPressed: uState.qty > 0 ? () {
                                              setModalState(() {
                                                uState.qty = (uState.qty - 1).clamp(0.0, double.infinity);
                                                uState.qtyController.text = uState.qty > 0 
                                                    ? uState.qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '') 
                                                    : '';
                                              });
                                            } : null,
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: uState.qtyController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13, 
                                                fontWeight: FontWeight.bold,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                                border: InputBorder.none,
                                              ),
                                              onChanged: (val) {
                                                setModalState(() {
                                                  uState.qty = double.tryParse(val) ?? 0.0;
                                                });
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_rounded, size: 18),
                                            onPressed: () {
                                              setModalState(() {
                                                uState.qty++;
                                                uState.qtyController.text = uState.qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Global Discount Field
                    TextField(
                      controller: discController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Diskon per Item / Total Produk (Rupiah)',
                        prefixText: 'Rp ',
                        filled: true,
                        fillColor: AppConstants.backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        discount = double.tryParse(val) ?? 0.0;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save / Remove Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: totalQty <= 0 && !isProductNew
                              ? AppConstants.errorColor
                              : AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          // Process each unit state
                          bool addedAny = false;
                          for (int i = 0; i < unitStates.length; i++) {
                            final us = unitStates[i];
                            if (us.qty > 0) {
                              // Apply global discount to first active unit
                              final double unitDisc = !addedAny ? discount : 0.0;
                              context.read<CartCubit>().addToCart(
                                    prod,
                                    units,
                                    prices,
                                    unit: us.unit,
                                    quantity: us.qty,
                                    discount: unitDisc,
                                    priceTierId: selectedItemTierId,
                                    customPrice: us.price,
                                  );
                              addedAny = true;
                            } else {
                              context.read<CartCubit>().removeFromCart(prod.id, us.unit.id);
                            }
                          }
                          Navigator.pop(ctx);
                          if (isProductNew && addedAny) {
                            _showAddedToCartFeedback(prod.name);
                          }
                        },
                        child: Text(
                          totalQty <= 0 && !isProductNew 
                              ? 'Hapus dari Keranjang' 
                              : 'Simpan',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════
  // CART PANEL
  // ═════════════════════════════════════════════════
  Widget _buildCartPanel(User? user, CashierSession? session) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cart) {
        if (cart.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: AppConstants.primaryColor.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keranjang Kosong',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppConstants.textDarkColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih produk untuk memulai transaksi',
                  style: GoogleFonts.poppins(
                    color: AppConstants.textLightColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // Group cart items by product ID
        final Map<int, List<CartItem>> groupedItems = {};
        for (final item in cart.items) {
          groupedItems.putIfAbsent(item.product.id, () => []).add(item);
        }
        final groupList = groupedItems.values.toList();

        return Column(
          children: [
            // ── Customer & Hold Header ──
            _buildCartHeaderSection(user),

            // ── Cart Items ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: groupList.length,
                itemBuilder: (context, index) {
                  final group = groupList[index];
                  return _buildCartItemGroupCard(group, index, cart);
                },
              ),
            ),

            // ── Summary & Checkout ──
            _buildCartSummarySection(user, session, cart),
          ],
        );
      },
    );
  }

  Widget _buildCartItemGroupCard(List<CartItem> group, int index, CartState cart) {
    final firstItem = group.first;
    final product = firstItem.product;

    return Dismissible(
      key: Key('group-${product.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        context.read<CartCubit>().removeProductFromCart(product.id);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppConstants.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.borderLightColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Header (tap to edit details)
            InkWell(
              onTap: () {
                final cartState = context.read<CartCubit>().state;
                final catalogItem = {
                  'product': product,
                  'units': firstItem.availableUnits,
                  'prices': firstItem.pricingMatrix,
                };
                _showProductModal(context, catalogItem, cartState);
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Product image / thumbnail
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: product.imagePath != null &&
                              product.imagePath!.isNotEmpty &&
                              File(product.imagePath!).existsSync()
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(product.imagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: AppConstants.primaryColor.withValues(alpha: 0.5),
                                size: 18,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppConstants.textDarkColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${group.length} Satuan aktif',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppConstants.textLightColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppConstants.textLightColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            // List of active units
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: group.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, unitIndex) {
                final item = group[unitIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Left side: Unit name chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.unit.name,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Stepper controls
                      Container(
                        decoration: BoxDecoration(
                          color: AppConstants.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildQtyButton(
                              icon: item.quantity <= 1
                                  ? Icons.delete_outline_rounded
                                  : Icons.remove_rounded,
                              color: item.quantity <= 1
                                  ? AppConstants.errorColor
                                  : AppConstants.textDarkColor,
                              onTap: () {
                                if (item.quantity <= 1) {
                                  context.read<CartCubit>().removeFromCart(
                                        item.product.id,
                                        item.unit.id,
                                      );
                                } else {
                                  context.read<CartCubit>().updateQuantity(
                                        item.product.id,
                                        item.unit.id,
                                        item.quantity - 1,
                                      );
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                item.quantity
                                    .toStringAsFixed(3)
                                    .replaceAll(RegExp(r'\.?0+$'), ''),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            _buildQtyButton(
                              icon: Icons.add_rounded,
                              color: AppConstants.primaryColor,
                              onTap: () => context.read<CartCubit>().updateQuantity(
                                    item.product.id,
                                    item.unit.id,
                                    item.quantity + 1,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Right side: Price and subtotal details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(item.subtotal),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textDarkColor,
                            ),
                          ),
                          Text(
                            '@ ${CurrencyFormatter.format(item.price)}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: AppConstants.textLightColor,
                            ),
                          ),
                          if (item.discountAmount > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '-${CurrencyFormatter.format(item.discountAmount)}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppConstants.errorColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildQtyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildCartHeaderSection(User? user) {
    return BlocBuilder<CustomerCubit, CustomerState>(
      builder: (context, custState) {
        List<Customer> customers = [];
        if (custState is CustomerLoaded) customers = custState.customers;
        final cart = context.read<CartCubit>().state;

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                  color: AppConstants.borderLightColor.withValues(alpha: 0.7)),
            ),
          ),
          child: Row(
            children: [
              // Customer Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppConstants.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: cart.selectedCustomer?.id,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppConstants.textDarkColor,
                      ),
                      hint: Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 16,
                              color: AppConstants.textLightColor),
                          const SizedBox(width: 6),
                          Text(
                            'Pelanggan Umum',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppConstants.textLightColor,
                            ),
                          ),
                        ],
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 16, color: AppConstants.textLightColor),
                              const SizedBox(width: 6),
                              Text('Pelanggan Umum (Cash)',
                                  style: GoogleFonts.poppins(fontSize: 12)),
                            ],
                          ),
                        ),
                        ...customers.map((c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.person_rounded,
                                      size: 16,
                                      color: AppConstants.primaryColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(c.name,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        final cust = val == null
                            ? null
                            : customers.firstWhere((c) => c.id == val);
                        context.read<CartCubit>().selectCustomer(cust);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Hold button
              Material(
                color: AppConstants.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    if (user == null) return;
                    
                    final noteController = TextEditingController();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.warningColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.pause_circle_filled_rounded,
                                  color: AppConstants.warningColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Tahan Transaksi',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ],
                        ),
                        content: TextField(
                          controller: noteController,
                          decoration: InputDecoration(
                            labelText: 'Catatan / Atas Nama (Opsional)',
                            hintText: 'Misal: Meja 5, Budi, dst.',
                            filled: true,
                            fillColor: AppConstants.backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppConstants.primaryColor, width: 1.5),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'BATAL',
                              style: TextStyle(color: AppConstants.textLightColor),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('TAHAN'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      final timestamp = DateTime.now().microsecondsSinceEpoch.toString().substring(8);
                      final note = noteController.text.trim();
                      final ref = note.isNotEmpty
                          ? "$note (HLD-$timestamp)"
                          : "HLD-$timestamp";

                      final cartCubit = context.read<CartCubit>();
                      final messenger = ScaffoldMessenger.of(context);
                      await cartCubit.holdCart(
                          user.id, ref, getIt<SalesRepository>());
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Transaksi ditahan • $ref'),
                          backgroundColor: AppConstants.warningColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.pause_rounded,
                        color: AppConstants.warningColor, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Clear all
              Material(
                color: AppConstants.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    context.read<CartCubit>().clearCart();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.delete_sweep_outlined,
                        color: AppConstants.errorColor, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartSummarySection(
      User? user, CashierSession? session, CartState cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary rows
          _buildSummaryRow('Subtotal', CurrencyFormatter.format(cart.subtotal)),
          if (cart.discountAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Diskon',
              '- ${CurrencyFormatter.format(cart.discountAmount)}',
              valueColor: AppConstants.errorColor,
            ),
          ],
          if (cart.taxAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(
              'Pajak',
              CurrencyFormatter.format(cart.taxAmount),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppConstants.textDarkColor,
                ),
              ),
              Text(
                CurrencyFormatter.format(cart.grandTotal),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Checkout button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (user == null || session == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentPage(
                      user: user,
                      session: session,
                      cart: cart,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'BAYAR ${CurrencyFormatter.format(cart.grandTotal)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppConstants.textLightColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? AppConstants.textDarkColor,
          ),
        ),
      ],
    );
  }
}
