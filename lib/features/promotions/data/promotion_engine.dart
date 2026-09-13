import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/pos/presentation/bloc/cart_cubit.dart';

class AppliedPromotion {
  final int promotionId;
  final String promoCode;
  final String promoName;
  final String promoType; // buy_x_get_y, min_purchase_discount, product_discount, purchase_with_purchase
  final double discountAmount;
  final int? getProductId;
  final double? getQuantity;
  final String? description;

  const AppliedPromotion({
    required this.promotionId,
    required this.promoCode,
    required this.promoName,
    required this.promoType,
    required this.discountAmount,
    this.getProductId,
    this.getQuantity,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'promotionId': promotionId,
      'promoCode': promoCode,
      'promoName': promoName,
      'promoType': promoType,
      'discountAmount': discountAmount,
      'getProductId': getProductId,
      'getQuantity': getQuantity,
      'description': description,
    };
  }
}

class PromotionEvaluationResult {
  final List<AppliedPromotion> appliedPromotions;
  final double totalPromoDiscount;

  const PromotionEvaluationResult({
    required this.appliedPromotions,
    required this.totalPromoDiscount,
  });
}

class PromotionEngine {
  /// Evaluasi seluruh promosi aktif terhadap keranjang belanja kasir
  static PromotionEvaluationResult evaluate({
    required List<Promotion> activePromotions,
    required List<CartItem> cartItems,
    Customer? selectedCustomer,
    String? manualPromoCode,
  }) {
    if (activePromotions.isEmpty || cartItems.isEmpty) {
      return const PromotionEvaluationResult(appliedPromotions: [], totalPromoDiscount: 0.0);
    }

    final List<AppliedPromotion> applied = [];
    final now = DateTime.now();

    // Raw subtotal keranjang (sebelum diskon manual cart)
    final double rawCartSubtotal =
        cartItems.fold(0.0, (sum, item) => sum + (item.quantity * item.price));

    for (final promo in activePromotions) {
      // 1. Cek status aktif dan periode waktu
      if (!promo.isActive) continue;
      if (promo.startDate.isAfter(now) || promo.endDate.isBefore(now)) continue;

      // 2. Cek hari aktif
      final currentWeekday = now.weekday.toString();
      if (!promo.activeDays.split(',').map((e) => e.trim()).contains(currentWeekday)) {
        continue;
      }

      // 3. Cek kode promo jika promosi mewajibkan kode kupon khusus
      final isAutoPromo = promo.code.isEmpty || promo.code.startsWith('AUTO');
      if (!isAutoPromo) {
        if (manualPromoCode == null ||
            manualPromoCode.trim().toUpperCase() != promo.code.trim().toUpperCase()) {
          continue;
        }
      }

      // 4. Cek pembatasan member only
      if (promo.memberOnly && selectedCustomer == null) {
        continue;
      }

      // 5. Evaluasi berdasarkan tipe promo
      switch (promo.type) {
        // --- 1. BELI X GRATIS Y (BOGO / Buy X Get Y) ---
        case 'buy_x_get_y':
          if (promo.buyProductId == null) continue;
          final minQty = promo.buyQuantity;
          final rewardQty = promo.getQuantity;
          if (minQty <= 0 || rewardQty <= 0) continue;

          // Cari produk pemicu di keranjang
          final buyItem = cartItems.cast<CartItem?>().firstWhere(
                (item) => item?.product.id == promo.buyProductId,
                orElse: () => null,
              );

          if (buyItem != null && buyItem.quantity >= minQty) {
            final isSameProduct = promo.getProductId == null || promo.getProductId == promo.buyProductId;
            
            if (isSameProduct) {
              // Contoh: Beli 1 Gratis 1 (produk sama). Total paket = minQty (1) + rewardQty (1) = 2
              final totalReqPerPackage = minQty + rewardQty;
              final multiplier = (buyItem.quantity / totalReqPerPackage).floor();

              if (multiplier > 0) {
                final freeQty = rewardQty * multiplier;
                final discAmount = freeQty * buyItem.price;

                applied.add(AppliedPromotion(
                  promotionId: promo.id,
                  promoCode: promo.code,
                  promoName: promo.name,
                  promoType: promo.type,
                  discountAmount: discAmount,
                  getProductId: promo.buyProductId,
                  getQuantity: freeQty,
                  description: 'Beli ${minQty.toInt()} Gratis ${rewardQty.toInt()} ${buyItem.product.name}',
                ));
              }
            } else {
              // Contoh: Beli Susu Gratis Biskuit (produk berbeda)
              final multiplier = (buyItem.quantity / minQty).floor();
              final rewardItem = cartItems.cast<CartItem?>().firstWhere(
                    (item) => item?.product.id == promo.getProductId,
                    orElse: () => null,
                  );

              if (multiplier > 0 && rewardItem != null) {
                final eligibleFreeQty = rewardQty * multiplier;
                final actualFreeQty = rewardItem.quantity > eligibleFreeQty ? eligibleFreeQty : rewardItem.quantity;
                final discAmount = actualFreeQty * rewardItem.price;

                if (discAmount > 0) {
                  applied.add(AppliedPromotion(
                    promotionId: promo.id,
                    promoCode: promo.code,
                    promoName: promo.name,
                    promoType: promo.type,
                    discountAmount: discAmount,
                    getProductId: promo.getProductId,
                    getQuantity: actualFreeQty,
                    description: 'Bonus Gratis ${actualFreeQty.toInt()} ${rewardItem.product.name}',
                  ));
                }
              }
            }
          }
          break;

        // --- 2. DISKON MINIMAL BELANJA (MIN PURCHASE DISCOUNT) ---
        case 'min_purchase_discount':
          final minPurchase = promo.minPurchaseAmount;
          if (rawCartSubtotal >= minPurchase && minPurchase > 0) {
            double disc = 0.0;
            if (promo.discountType == 'percentage') {
              final pct = promo.discountValue;
              disc = rawCartSubtotal * (pct / 100);
            } else {
              disc = promo.discountValue;
            }

            if (disc > 0) {
              applied.add(AppliedPromotion(
                promotionId: promo.id,
                promoCode: promo.code,
                promoName: promo.name,
                promoType: promo.type,
                discountAmount: disc,
                description: 'Diskon Belanja Min. Rp ${minPurchase.toStringAsFixed(0)}',
              ));
            }
          }
          break;

        // --- 3. DISKON KHUSUS PRODUK / KATEGORI ---
        case 'product_discount':
          double promoDisc = 0.0;
          for (final item in cartItems) {
            bool matches = false;
            if (promo.buyProductId != null && item.product.id == promo.buyProductId) {
              matches = true;
            } else if (promo.categoryId != null && item.product.categoryId == promo.categoryId) {
              matches = true;
            }

            if (matches) {
              if (promo.discountType == 'percentage') {
                final pct = promo.discountValue;
                promoDisc += (item.quantity * item.price) * (pct / 100);
              } else {
                final fixedPerUnit = promo.discountValue;
                promoDisc += item.quantity * fixedPerUnit;
              }
            }
          }

          if (promoDisc > 0) {
            applied.add(AppliedPromotion(
              promotionId: promo.id,
              promoCode: promo.code,
              promoName: promo.name,
              promoType: promo.type,
              discountAmount: promoDisc,
              description: 'Diskon Spesial Produk / Kategori',
            ));
          }
          break;

        // --- 4. TEBUS MURAH (PURCHASE WITH PURCHASE / PWP) ---
        case 'purchase_with_purchase':
          final minSpend = promo.minPurchaseAmount;
          if (rawCartSubtotal >= minSpend && promo.getProductId != null) {
            // Cek apakah produk tebus murah ada di keranjang
            final rewardItem = cartItems.cast<CartItem?>().firstWhere(
                  (item) => item?.product.id == promo.getProductId,
                  orElse: () => null,
                );

            if (rewardItem != null) {
              final normalPrice = rewardItem.price;
              final specialPrice = promo.specialPrice ?? 0.0;
              final diffPerItem = (normalPrice - specialPrice).clamp(0.0, double.infinity);
              final maxQty = promo.getQuantity;
              final eligibleQty = rewardItem.quantity > maxQty ? maxQty : rewardItem.quantity;
              final totalPwpDisc = diffPerItem * eligibleQty;

              if (totalPwpDisc > 0) {
                applied.add(AppliedPromotion(
                  promotionId: promo.id,
                  promoCode: promo.code,
                  promoName: promo.name,
                  promoType: promo.type,
                  discountAmount: totalPwpDisc,
                  getProductId: promo.getProductId,
                  getQuantity: eligibleQty,
                  description: 'Tebus Murah ${rewardItem.product.name} Rp ${specialPrice.toStringAsFixed(0)}',
                ));
              }
            }
          }
          break;
      }
    }

    final double totalPromoDiscount = applied.fold(0.0, (sum, p) => sum + p.discountAmount);

    return PromotionEvaluationResult(
      appliedPromotions: applied,
      totalPromoDiscount: totalPromoDiscount,
    );
  }
}
