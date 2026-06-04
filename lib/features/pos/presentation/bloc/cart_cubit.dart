import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/sales_repository.dart';

class CartItem {
  final Product product;
  final ProductUnit unit;
  final double quantity;
  final double price; // Harga per item setelah disesuaikan tier
  final double discountAmount; // Diskon nominal per item
  final List<ProductUnit> availableUnits;
  final List<ProductPrice> pricingMatrix;

  CartItem({
    required this.product,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.discountAmount,
    required this.availableUnits,
    required this.pricingMatrix,
  });

  CartItem copyWith({
    Product? product,
    ProductUnit? unit,
    double? quantity,
    double? price,
    double? discountAmount,
    List<ProductUnit>? availableUnits,
    List<ProductPrice>? pricingMatrix,
  }) {
    return CartItem(
      product: product ?? this.product,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discountAmount: discountAmount ?? this.discountAmount,
      availableUnits: availableUnits ?? this.availableUnits,
      pricingMatrix: pricingMatrix ?? this.pricingMatrix,
    );
  }

  double get subtotal => (quantity * price) - discountAmount;
}

class CartState {
  final List<CartItem> items;
  final Customer? selectedCustomer;
  final double globalDiscount; // Diskon global
  final bool isGlobalDiscountPercentage; // Persen atau nominal
  final double taxPercentage;

  CartState({
    required this.items,
    this.selectedCustomer,
    this.globalDiscount = 0.0,
    this.isGlobalDiscountPercentage = false,
    this.taxPercentage = 0.0,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get discountAmount {
    if (isGlobalDiscountPercentage) {
      return subtotal * (globalDiscount / 100);
    }
    return globalDiscount;
  }

  double get taxAmount => (subtotal - discountAmount) * (taxPercentage / 100);

  double get grandTotal => subtotal - discountAmount + taxAmount;

  CartState copyWith({
    List<CartItem>? items,
    Customer? selectedCustomer,
    double? globalDiscount,
    bool? isGlobalDiscountPercentage,
    double? taxPercentage,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      globalDiscount: globalDiscount ?? this.globalDiscount,
      isGlobalDiscountPercentage: isGlobalDiscountPercentage ?? this.isGlobalDiscountPercentage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
    );
  }
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartState(items: []));

  // Menambah produk ke keranjang
  void addToCart(Product product, List<ProductUnit> units, List<ProductPrice> prices, {ProductUnit? unit, double quantity = 1.0, double discount = 0.0}) {
    final targetUnit = unit ?? units.firstWhere((u) => u.isBase, orElse: () => units.first);
    
    final existingIndex = state.items.indexWhere(
        (item) => item.product.id == product.id && item.unit.id == targetUnit.id);
    
    if (existingIndex >= 0) {
      // Jika produk sudah ada dengan unit ini, tambah qty
      final item = state.items[existingIndex];
      updateQuantity(product.id, targetUnit.id, item.quantity + quantity);
      if (discount > 0) {
        applyItemDiscount(product.id, targetUnit.id, item.discountAmount + discount);
      }
    } else {
      // Hitung harga default berdasarkan Price Tier pelanggan terpilih
      final tierId = state.selectedCustomer != null ? 2 : 1; // 2 = Grosir, 1 = Umum
      final price = _getPriceForUnit(targetUnit.id, prices, tierId: tierId);

      final newItems = List<CartItem>.from(state.items)
        ..add(CartItem(
          product: product,
          unit: targetUnit,
          quantity: quantity,
          price: price,
          discountAmount: discount,
          availableUnits: units,
          pricingMatrix: prices,
        ));
      
      emit(state.copyWith(items: newItems));
    }
  }

  // Mengubah kuantitas item
  void updateQuantity(int productId, int unitId, double quantity) {
    if (quantity <= 0) {
      removeFromCart(productId, unitId);
      return;
    }

    final newItems = state.items.map((item) {
      if (item.product.id == productId && item.unit.id == unitId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: newItems));
  }

  // Menghapus item dari keranjang
  void removeFromCart(int productId, int unitId) {
    final newItems = state.items
        .where((item) => !(item.product.id == productId && item.unit.id == unitId))
        .toList();
    emit(state.copyWith(items: newItems));
  }

  // Mengubah Satuan Unit item (misal Pcs -> Dus)
  void updateUnit(int productId, int oldUnitId, ProductUnit newUnit) {
    final newItems = state.items.map((item) {
      if (item.product.id == productId && item.unit.id == oldUnitId) {
        final tierId = state.selectedCustomer != null ? 2 : 1; // 2 = Grosir, 1 = Umum
        final newPrice = _getPriceForUnit(newUnit.id, item.pricingMatrix, tierId: tierId);

        return item.copyWith(
          unit: newUnit,
          price: newPrice,
        );
      }
      return item;
    }).toList();

    emit(state.copyWith(items: newItems));
  }

  // Menerapkan diskon per item
  void applyItemDiscount(int productId, int unitId, double discount) {
    final newItems = state.items.map((item) {
      if (item.product.id == productId && item.unit.id == unitId) {
        return item.copyWith(discountAmount: discount);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: newItems));
  }

  // Menerapkan diskon global
  void applyGlobalDiscount(double discount, {required bool isPercentage}) {
    emit(state.copyWith(
      globalDiscount: discount,
      isGlobalDiscountPercentage: isPercentage,
    ));
  }

  // Memilih pelanggan & otomatis update harga berdasarkan Price Tier
  void selectCustomer(Customer? customer) {
    // Di sini kita asumsikan jika customer != null maka menggunakan Price Tier Grosir (ID 2),
    // jika null menggunakan Price Tier Umum (ID 1).
    final tierId = customer != null ? 2 : 1;

    final newItems = state.items.map((item) {
      final newPrice = _getPriceForUnit(item.unit.id, item.pricingMatrix, tierId: tierId);
      return item.copyWith(price: newPrice);
    }).toList();

    emit(state.copyWith(
      selectedCustomer: customer,
      clearCustomer: customer == null,
      items: newItems,
    ));
  }

  // Update persentase pajak
  void updateTaxPercentage(double percentage) {
    emit(state.copyWith(taxPercentage: percentage));
  }

  // Bersihkan keranjang
  void clearCart() {
    emit(CartState(items: [], taxPercentage: state.taxPercentage));
  }

  // Mengambil harga unit berdasarkan price matrix & price tier
  double _getPriceForUnit(int unitId, List<ProductPrice> matrix, {required int tierId}) {
    final priceObj = matrix.firstWhere(
      (p) => p.unitId == unitId && p.priceTierId == tierId,
      orElse: () => matrix.firstWhere(
        (p) => p.unitId == unitId,
        orElse: () => ProductPrice(id: 0, productId: 0, unitId: unitId, priceTierId: tierId, price: 0.0, minQty: 1),
      ),
    );
    return priceObj.price;
  }

  // Tahan transaksi (Hold)
  Future<void> holdCart(int userId, String refNo, SalesRepository repo) async {
    if (state.items.isEmpty) return;

    // Serialisasi data keranjang ke JSON
    final cartList = state.items.map((item) {
      return {
        'product_id': item.product.id,
        'unit_id': item.unit.id,
        'quantity': item.quantity,
        'price': item.price,
        'discount_amount': item.discountAmount,
      };
    }).toList();

    final jsonStr = jsonEncode({
      'items': cartList,
      'global_discount': state.globalDiscount,
      'is_global_discount_percentage': state.isGlobalDiscountPercentage,
    });

    await repo.holdOrder(
      userId: userId,
      referenceNo: refNo,
      cartDataJson: jsonStr,
      customerId: state.selectedCustomer?.id,
    );

    clearCart();
  }

  // Ambil transaksi ditahan (Recall)
  void recallCart(
    PosHeldOrder heldOrder,
    List<Map<String, dynamic>> allPosProducts,
    List<Customer> allCustomers,
  ) {
    try {
      final data = jsonDecode(heldOrder.cartData) as Map<String, dynamic>;
      final itemsData = data['items'] as List<dynamic>;
      final globalDisc = (data['global_discount'] as num?)?.toDouble() ?? 0.0;
      final isPercentage = data['is_global_discount_percentage'] as bool? ?? false;

      // Temukan customer
      Customer? customer;
      if (heldOrder.customerId != null) {
        customer = allCustomers.firstWhere((c) => c.id == heldOrder.customerId, orElse: () => allCustomers.first);
      }

      final List<CartItem> recalledItems = [];

      for (var itemMap in itemsData) {
        final int productId = itemMap['product_id'];
        final int unitId = itemMap['unit_id'];
        final double qty = (itemMap['quantity'] as num).toDouble();
        final double price = (itemMap['price'] as num).toDouble();
        final double disc = (itemMap['discount_amount'] as num).toDouble();

        // Temukan detail produk di cache
        final prodMap = allPosProducts.firstWhere(
          (p) => (p['product'] as Product).id == productId,
          orElse: () => {},
        );

        if (prodMap.isNotEmpty) {
          final Product product = prodMap['product'];
          final List<ProductUnit> units = List<ProductUnit>.from(prodMap['units']);
          final List<ProductPrice> prices = List<ProductPrice>.from(prodMap['prices']);
          final unit = units.firstWhere((u) => u.id == unitId, orElse: () => units.first);

          recalledItems.add(CartItem(
            product: product,
            unit: unit,
            quantity: qty,
            price: price,
            discountAmount: disc,
            availableUnits: units,
            pricingMatrix: prices,
          ));
        }
      }

      emit(CartState(
        items: recalledItems,
        selectedCustomer: customer,
        globalDiscount: globalDisc,
        isGlobalDiscountPercentage: isPercentage,
        taxPercentage: state.taxPercentage,
      ));
    } catch (e) {
      // ignore
    }
  }
}
