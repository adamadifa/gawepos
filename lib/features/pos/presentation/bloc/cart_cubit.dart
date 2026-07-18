import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/sales_repository.dart';

class CartItem {
  final Product product;
  final ProductUnit unit;
  final double quantity;
  final double price;
  final double discountAmount;
  final List<ProductUnit> availableUnits;
  final List<ProductPrice> pricingMatrix;
  final int appliedMinQty;

  CartItem({
    required this.product,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.discountAmount,
    required this.availableUnits,
    required this.pricingMatrix,
    required this.appliedMinQty,
  });

  CartItem copyWith({
    Product? product,
    ProductUnit? unit,
    double? quantity,
    double? price,
    double? discountAmount,
    List<ProductUnit>? availableUnits,
    List<ProductPrice>? pricingMatrix,
    int? appliedMinQty,
  }) {
    return CartItem(
      product: product ?? this.product,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discountAmount: discountAmount ?? this.discountAmount,
      availableUnits: availableUnits ?? this.availableUnits,
      pricingMatrix: pricingMatrix ?? this.pricingMatrix,
      appliedMinQty: appliedMinQty ?? this.appliedMinQty,
    );
  }

  double get subtotal => (quantity * price) - discountAmount;
}

class CartState {
  final List<CartItem> items;
  final Customer? selectedCustomer;
  final double globalDiscount;
  final bool isGlobalDiscountPercentage;
  final double taxPercentage;
  final int redeemedPoints;
  final double pointsDiscount;

  CartState({
    required this.items,
    this.selectedCustomer,
    this.globalDiscount = 0.0,
    this.isGlobalDiscountPercentage = false,
    this.taxPercentage = 0.0,
    this.redeemedPoints = 0,
    this.pointsDiscount = 0.0,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.subtotal);

  double get discountAmount {
    if (isGlobalDiscountPercentage) {
      return subtotal * (globalDiscount / 100);
    }
    return globalDiscount;
  }

  double get taxAmount => (subtotal - discountAmount) * (taxPercentage / 100);

  double get grandTotal => subtotal - discountAmount + taxAmount - pointsDiscount;

  CartState copyWith({
    List<CartItem>? items,
    Customer? selectedCustomer,
    double? globalDiscount,
    bool? isGlobalDiscountPercentage,
    double? taxPercentage,
    int? redeemedPoints,
    double? pointsDiscount,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      globalDiscount: globalDiscount ?? this.globalDiscount,
      isGlobalDiscountPercentage: isGlobalDiscountPercentage ?? this.isGlobalDiscountPercentage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      redeemedPoints: redeemedPoints ?? this.redeemedPoints,
      pointsDiscount: pointsDiscount ?? this.pointsDiscount,
    );
  }
}

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(CartState(items: []));

  void addToCart(Product product, List<ProductUnit> units, List<ProductPrice> prices, {
    ProductUnit? unit,
    double quantity = 1.0,
    double discount = 0.0,
    double? customPrice,
  }) {
    final targetUnit = unit ?? units.firstWhere((u) => u.isBase, orElse: () => units.first);
    final price = customPrice ?? _getPriceForUnit(targetUnit.id, prices, quantity: quantity);

    final existingIndex = state.items.indexWhere(
        (item) => item.product.id == product.id && item.unit.id == targetUnit.id);

    if (existingIndex >= 0) {
      final newItems = List<CartItem>.from(state.items);
      newItems[existingIndex] = newItems[existingIndex].copyWith(
        quantity: quantity,
        price: price,
        discountAmount: discount,
      );
      emit(state.copyWith(items: newItems));
    } else {
      final appliedQty = _getAppliedMinQty(targetUnit.id, prices, quantity: quantity);
      final newItems = List<CartItem>.from(state.items)
        ..add(CartItem(
          product: product,
          unit: targetUnit,
          quantity: quantity,
          price: price,
          discountAmount: discount,
          availableUnits: units,
          pricingMatrix: prices,
          appliedMinQty: appliedQty,
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
        final newPrice = _getPriceForUnit(unitId, item.pricingMatrix, quantity: quantity);
        final newAppliedMinQty = _getAppliedMinQty(unitId, item.pricingMatrix, quantity: quantity);
        return item.copyWith(quantity: quantity, price: newPrice, appliedMinQty: newAppliedMinQty);
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

  // Menghapus semua unit produk dari keranjang
  void removeProductFromCart(int productId) {
    final newItems = state.items
        .where((item) => item.product.id != productId)
        .toList();
    emit(state.copyWith(items: newItems));
  }

  void updateUnit(int productId, int oldUnitId, ProductUnit newUnit) {
    final newItems = state.items.map((item) {
      if (item.product.id == productId && item.unit.id == oldUnitId) {
        final newPrice = _getPriceForUnit(newUnit.id, item.pricingMatrix, quantity: item.quantity);
        final appliedQty = _getAppliedMinQty(newUnit.id, item.pricingMatrix, quantity: item.quantity);

        return item.copyWith(
          unit: newUnit,
          price: newPrice,
          appliedMinQty: appliedQty,
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

  // Memilih pelanggan
  void selectCustomer(Customer? customer) {
    emit(state.copyWith(
      selectedCustomer: customer,
      clearCustomer: customer == null,
      redeemedPoints: 0,
      pointsDiscount: 0.0,
    ));
  }

  void applyPointsRedemption(int points, double discountAmount) {
    emit(state.copyWith(
      redeemedPoints: points,
      pointsDiscount: discountAmount,
    ));
  }

  void clearPointsRedemption() {
    emit(state.copyWith(
      redeemedPoints: 0,
      pointsDiscount: 0.0,
    ));
  }

  void updateTaxPercentage(double percentage) {
    emit(state.copyWith(taxPercentage: percentage));
  }

  void clearCart() {
    emit(CartState(
      items: [],
      taxPercentage: state.taxPercentage,
    ));
  }

  double _getPriceForUnit(int unitId, List<ProductPrice> matrix, {required double quantity}) {
    final validPrices = matrix.where((p) => p.unitId == unitId && p.price > 0).toList();
    if (validPrices.isEmpty) return 0.0;

    final applicable = validPrices.where((p) => p.minQty <= quantity).toList();
    if (applicable.isNotEmpty) {
      applicable.sort((a, b) => b.minQty.compareTo(a.minQty));
      return applicable.first.price;
    }

    validPrices.sort((a, b) => a.minQty.compareTo(b.minQty));
    return validPrices.first.price;
  }

  int _getAppliedMinQty(int unitId, List<ProductPrice> matrix, {required double quantity}) {
    final validPrices = matrix.where((p) => p.unitId == unitId && p.price > 0).toList();
    if (validPrices.isEmpty) return 1;

    final applicable = validPrices.where((p) => p.minQty <= quantity).toList();
    if (applicable.isNotEmpty) {
      applicable.sort((a, b) => b.minQty.compareTo(a.minQty));
      return applicable.first.minQty;
    }

    validPrices.sort((a, b) => a.minQty.compareTo(b.minQty));
    return validPrices.first.minQty;
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
        'min_qty_applied': item.appliedMinQty,
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
        final int appliedMinQty = itemMap['min_qty_applied'] ?? 1;

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
            appliedMinQty: appliedMinQty,
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
