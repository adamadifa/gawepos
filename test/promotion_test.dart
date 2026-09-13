import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/pos/presentation/bloc/cart_cubit.dart';
import 'package:posmobile/features/promotions/data/promotion_engine.dart';
import 'package:posmobile/features/pos/data/sales_repository.dart';

void main() {
  late AppDatabase db;
  late SalesRepository salesRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    salesRepo = SalesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('PromotionEngine: Evaluasi Diskon Minimal Belanja Toko', () {
    final promo = Promotion(
      id: 1,
      name: 'Diskon Belanja Rp 50.000',
      code: 'AUTO_1',
      type: 'min_purchase_discount',
      discountType: 'nominal',
      discountValue: 10000.0,
      minPurchaseAmount: 50000.0,
      buyQuantity: 1.0,
      getQuantity: 1.0,
      memberOnly: false,
      activeDays: '1,2,3,4,5,6,7',
      maxUsageCount: 0,
      currentUsageCount: 0,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 1)),
      isActive: true,
      createdAt: DateTime.now(),
    );

    final product = Product(
      id: 10,
      name: 'Beras Premium 5kg',
      sku: 'BRS-01',
      hasRecipe: false,
      isStockManaged: true,
      productType: 'standard',
      createdAt: DateTime.now(),
      isActive: true,
      commissionRate: 0.0,
      businessSegment: 'retail',
      isConsignment: false,
      allowManualPrice: false,
      minStockAlert: 0,
    );
    final unit = ProductUnit(id: 1, productId: 10, name: 'Pcs', conversionFactor: 1.0, costPrice: 50000, isBase: true);

    final cartItems = [
      CartItem(
        product: product,
        unit: unit,
        quantity: 1,
        price: 65000,
        discountAmount: 0,
        availableUnits: [unit],
        pricingMatrix: [],
        appliedMinQty: 1,
      ),
    ];

    final result = PromotionEngine.evaluate(
      activePromotions: [promo],
      cartItems: cartItems,
    );

    expect(result.appliedPromotions.length, 1);
    expect(result.totalPromoDiscount, 10000.0);
    expect(result.appliedPromotions.first.promoName, 'Diskon Belanja Rp 50.000');
  });

  test('PromotionEngine: Evaluasi Beli 2 Gratis 1 (BOGO)', () {
    final promo = Promotion(
      id: 2,
      name: 'Beli 2 Gratis 1 Susu UHT',
      code: 'AUTO_2',
      type: 'buy_x_get_y',
      discountType: 'nominal',
      discountValue: 0.0,
      minPurchaseAmount: 0.0,
      buyProductId: 20,
      buyQuantity: 2.0,
      getProductId: 20,
      getQuantity: 1.0,
      memberOnly: false,
      activeDays: '1,2,3,4,5,6,7',
      maxUsageCount: 0,
      currentUsageCount: 0,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 1)),
      isActive: true,
      createdAt: DateTime.now(),
    );

    final product = Product(
      id: 20,
      name: 'Susu UHT 1L',
      sku: 'SSU-01',
      hasRecipe: false,
      isStockManaged: true,
      productType: 'standard',
      createdAt: DateTime.now(),
      isActive: true,
      commissionRate: 0.0,
      businessSegment: 'retail',
      isConsignment: false,
      allowManualPrice: false,
      minStockAlert: 0,
    );
    final unit = ProductUnit(id: 2, productId: 20, name: 'Kotak', conversionFactor: 1.0, costPrice: 15000, isBase: true);

    // Kasir memasukkan 3 pcs susu (2 dibeli + 1 gratis diambil dari rak)
    final cartItems = [
      CartItem(
        product: product,
        unit: unit,
        quantity: 3,
        price: 18000,
        discountAmount: 0,
        availableUnits: [unit],
        pricingMatrix: [],
        appliedMinQty: 1,
      ),
    ];

    final result = PromotionEngine.evaluate(
      activePromotions: [promo],
      cartItems: cartItems,
    );

    expect(result.appliedPromotions.length, 1);
    expect(result.totalPromoDiscount, 18000.0); // 1 free item price
  });

  test('SalesRepository: Kartu Stok dan Transaksi Pemotongan Stok Akurat untuk Promo', () async {
    // 1. Setup Outlet & Cashier User
    await db.into(db.outlets).insert(
          OutletsCompanion.insert(
            name: 'Toko Retail Sukses',
            address: const drift.Value('Jl. Raya'),
          ),
        );
    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            username: 'kasir1',
            name: 'Kasir Satu',
            pinHash: '1234',
            role: const drift.Value('cashier'),
          ),
        );
    final sessionId = await db.into(db.cashierSessions).insert(
          CashierSessionsCompanion.insert(
            userId: userId,
            openingCash: 100000,
            openTime: DateTime.now(),
            status: const drift.Value('open'),
          ),
        );

    // 2. Setup Produk & Saldo Stok Awal 10 Pcs
    final prodId = await db.into(db.products).insert(
          ProductsCompanion.insert(
            name: 'Biskuit Cokelat',
            sku: const drift.Value('BSK-01'),
            isStockManaged: const drift.Value(true),
          ),
        );
    final unitId = await db.into(db.productUnits).insert(
          ProductUnitsCompanion.insert(
            productId: prodId,
            name: 'Pcs',
            conversionFactor: const drift.Value(1.0),
            costPrice: const drift.Value(8000),
            isBase: const drift.Value(true),
          ),
        );

    await db.into(db.inventory).insert(
          InventoryCompanion.insert(
            productId: prodId,
            unitId: unitId,
            quantity: const drift.Value(10.0), // Saldo awal 10
          ),
        );

    final product = Product(
      id: prodId,
      name: 'Biskuit Cokelat',
      sku: 'BSK-01',
      hasRecipe: false,
      isStockManaged: true,
      productType: 'standard',
      createdAt: DateTime.now(),
      isActive: true,
      commissionRate: 0.0,
      businessSegment: 'retail',
      isConsignment: false,
      allowManualPrice: false,
      minStockAlert: 0,
    );
    final unit = ProductUnit(id: unitId, productId: prodId, name: 'Pcs', conversionFactor: 1.0, costPrice: 8000, isBase: true);

    final promoId = await db.into(db.promotions).insert(
          PromotionsCompanion.insert(
            name: 'Beli 2 Gratis 1',
            code: 'BOGO_BISKUIT',
            type: 'buy_x_get_y',
            buyProductId: drift.Value(prodId),
            buyQuantity: const drift.Value(2.0),
            getProductId: drift.Value(prodId),
            getQuantity: const drift.Value(1.0),
            startDate: DateTime.now().subtract(const Duration(days: 1)),
            endDate: DateTime.now().add(const Duration(days: 1)),
          ),
        );

    // 3. Simpan transaksi Beli 2 Gratis 1 (Total keluar 3 pcs dari rak)
    final orderId = await salesRepo.saveOrder(
      userId: userId,
      cashierSessionId: sessionId,
      subtotal: 30000,
      discountAmount: 10000, // Potongan 1 item gratis
      taxAmount: 0,
      grandTotal: 20000,
      paidAmount: 20000,
      changeAmount: 0,
      cartItems: [
        {
          'product': product,
          'unit': unit,
          'quantity': 3.0,
          'price': 10000.0,
          'discountAmount': 10000.0,
          'appliedMinQty': 1,
        }
      ],
      payments: [
        {'method': 'cash', 'amount': 20000.0, 'referenceId': null}
      ],
      appliedPromotions: [
        {
          'promotionId': promoId,
          'promoCode': 'BOGO_BISKUIT',
          'promoName': 'Beli 2 Gratis 1',
          'discountAmount': 10000.0,
        }
      ],
    );

    expect(orderId, greaterThan(0));

    // 4. Verifikasi sisa stok di tabel Inventory berkurang tepat 3 pcs (10 - 3 = 7)
    final inventory = await (db.select(db.inventory)
          ..where((t) => t.productId.equals(prodId) & t.unitId.equals(unitId)))
        .getSingle();
    expect(inventory.quantity, 7.0);

    // 5. Verifikasi log mutasi di StockMovements mencatat -3 pcs
    final movements = await (db.select(db.stockMovements)
          ..where((t) => t.productId.equals(prodId)))
        .get();
    expect(movements.length, 1);
    expect(movements.first.quantity, -3.0);
    expect(movements.first.type, 'sale');

    // 6. Verifikasi OrderPromotions tercatat
    final orderPromos = await (db.select(db.orderPromotions)
          ..where((t) => t.orderId.equals(orderId)))
        .get();
    expect(orderPromos.length, 1);
    expect(orderPromos.first.promotionName, 'Beli 2 Gratis 1');
    expect(orderPromos.first.discountAmount, 10000.0);
  });
}
