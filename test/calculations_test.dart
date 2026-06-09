import 'package:flutter_test/flutter_test.dart';
import 'package:posmobile/features/pos/presentation/bloc/cart_cubit.dart';
import 'package:posmobile/core/database/app_database.dart';

void main() {
  group('Cart Calculations Test', () {
    // Mock Product & Unit
    final mockProduct1 = Product(
      id: 1,
      name: 'Product A',
      productType: 'goods',
      isStockManaged: true,
      minStockAlert: 0,
      isActive: true,
      allowManualPrice: false,
      createdAt: DateTime.now(),
    );

    final mockProduct2 = Product(
      id: 2,
      name: 'Product B',
      productType: 'goods',
      isStockManaged: true,
      minStockAlert: 0,
      isActive: true,
      allowManualPrice: false,
      createdAt: DateTime.now(),
    );

    final mockUnit = ProductUnit(
      id: 1,
      productId: 1,
      name: 'Pcs',
      conversionFactor: 1.0,
      isBase: true,
    );

    test('should calculate subtotal correctly with item discounts', () {
      final items = [
        CartItem(
          product: mockProduct1,
          unit: mockUnit,
          quantity: 2,
          price: 10000,
          discountAmount: 1000, // 2 * 10000 - 1000 = 19000
          availableUnits: [],
          pricingMatrix: [],
          appliedMinQty: 1,
        ),
        CartItem(
          product: mockProduct2,
          unit: mockUnit,
          quantity: 1,
          price: 5000,
          discountAmount: 0, // 1 * 5000 - 0 = 5000
          availableUnits: [],
          pricingMatrix: [],
          appliedMinQty: 1,
        ),
      ];

      final state = CartState(items: items);

      expect(state.subtotal, equals(24000));
    });

    test('should calculate global nominal discount correctly', () {
      final items = [
        CartItem(
          product: mockProduct1,
          unit: mockUnit,
          quantity: 2,
          price: 10000,
          discountAmount: 0, // subtotal = 20000
          availableUnits: [],
          pricingMatrix: [],
          appliedMinQty: 1,
        ),
      ];

      final state = CartState(
        items: items,
        globalDiscount: 5000,
        isGlobalDiscountPercentage: false,
      );

      expect(state.discountAmount, equals(5000));
      expect(state.grandTotal, equals(15000));
    });

    test('should calculate global percentage discount correctly', () {
      final items = [
        CartItem(
          product: mockProduct1,
          unit: mockUnit,
          quantity: 2,
          price: 10000,
          discountAmount: 0, // subtotal = 20000
          availableUnits: [],
          pricingMatrix: [],
          appliedMinQty: 1,
        ),
      ];

      final state = CartState(
        items: items,
        globalDiscount: 10, // 10%
        isGlobalDiscountPercentage: true,
      );

      expect(state.discountAmount, equals(2000));
      expect(state.grandTotal, equals(18000));
    });

    test('should calculate tax correctly based on subtotal after discount', () {
      final items = [
        CartItem(
          product: mockProduct1,
          unit: mockUnit,
          quantity: 2,
          price: 10000,
          discountAmount: 0, // subtotal = 20000
          availableUnits: [],
          pricingMatrix: [],
          appliedMinQty: 1,
        ),
      ];

      final state = CartState(
        items: items,
        globalDiscount: 2000, // discount 2000 => subtotal - discount = 18000
        isGlobalDiscountPercentage: false,
        taxPercentage: 11, // 11% of 18000 = 1980
      );

      expect(state.taxAmount, equals(1980));
      expect(state.grandTotal, equals(18000 + 1980)); // 19980
    });
  });
}
