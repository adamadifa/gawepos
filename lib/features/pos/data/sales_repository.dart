import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class SalesRepository {
  final AppDatabase _db;

  SalesRepository(this._db);

  // Mengambil daftar produk lengkap beserta unit dan harga jualnya
  Future<List<Map<String, dynamic>>> getPosProducts() async {
    final products = await _db.select(_db.products).get();
    final brands = await _db.select(_db.brands).get();
    final categories = await _db.select(_db.categories).get();
    final brandMap = {for (final b in brands) b.id: b.name};
    final categoryMap = {for (final c in categories) c.id: c.name};

    if (products.isEmpty) return [];

    final productIds = products.map((p) => p.id).toList();
    final allUnits = await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.productId.isIn(productIds)))
        .get();
    final allPrices = await (_db.select(_db.productPrices)
          ..where((tbl) => tbl.productId.isIn(productIds)))
        .get();

    final unitsByProduct = <int, List<ProductUnit>>{};
    for (var u in allUnits) {
      unitsByProduct.putIfAbsent(u.productId, () => []).add(u);
    }
    final pricesByProduct = <int, List<ProductPrice>>{};
    for (var p in allPrices) {
      pricesByProduct.putIfAbsent(p.productId, () => []).add(p);
    }

    return products.map((product) {
      return {
        'product': product,
        'units': unitsByProduct[product.id] ?? [],
        'prices': pricesByProduct[product.id] ?? [],
        'brandName': brandMap[product.brandId],
        'categoryName': categoryMap[product.categoryId],
      };
    }).toList();
  }

  // Menyimpan pesanan lengkap secara atomik dalam satu transaksi database Drift
  Future<int> saveOrder({
    required int userId,
    required int cashierSessionId,
    required double subtotal,
    required double discountAmount,
    required double taxAmount,
    required double grandTotal,
    required double paidAmount,
    required double changeAmount,
    required List<Map<String, dynamic>> cartItems,
    required List<Map<String, dynamic>> payments,
    double downPayment = 0.0,
    int? customerId,
    String? notes,
    int pointsEarned = 0,
    int pointsRedeemed = 0,
    double pointsDiscount = 0.0,
  }) async {
    return await _db.transaction(() async {
      // 1. Generate nomor referensi transaksi: TRX-YYYYMMDD-XXXX
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final countQuery = _db.selectOnly(_db.orders)
        ..addColumns([_db.orders.id.count()])
        ..where(_db.orders.referenceNo.like('TRX-$dateStr-%'));
      final count = (await countQuery.getSingle()).read<int>(_db.orders.id.count()) ?? 0;
      final refNo = "TRX-$dateStr-${(count + 1).toString().padLeft(4, '0')}";

      final isDebt = payments.any((p) => p['method'] == 'debt');
      final paymentStatusValue = isDebt 
          ? (downPayment >= grandTotal ? 'paid' : (downPayment > 0 ? 'partial' : 'unpaid')) 
          : 'paid';
      final paidAmountValue = isDebt ? downPayment : paidAmount;
      final changeAmountValue = isDebt ? 0.0 : changeAmount;

      // 2. Insert Orders
      final orderId = await _db.into(_db.orders).insert(
            OrdersCompanion.insert(
              userId: userId,
              cashierSessionId: cashierSessionId,
              referenceNo: refNo,
              subtotal: Value(subtotal),
              discountAmount: Value(discountAmount),
              taxAmount: Value(taxAmount),
              grandTotal: Value(grandTotal),
              paidAmount: Value(paidAmountValue),
              changeAmount: Value(changeAmountValue),
              customerId: Value(customerId),
              notes: Value(notes),
              createdAt: Value(now),
              status: const Value('completed'),
              paymentStatus: Value(paymentStatusValue),
            ),
          );

      // 2b. If payment method is Debt, insert to CustomerDebts
      if (isDebt && customerId != null) {
        final debtId = await _db.into(_db.customerDebts).insert(
              CustomerDebtsCompanion.insert(
                customerId: customerId,
                orderId: Value(orderId),
                amount: grandTotal, // Simpan total awal bon sebelum dikurangi DP
                paidAmount: Value(downPayment),
                status: Value(downPayment >= grandTotal ? 'paid' : (downPayment > 0 ? 'partial' : 'unpaid')),
                createdAt: Value(now),
              ),
            );

        // Jika ada DP, masukkan ke dalam histori pembayaran cicilan
        if (downPayment > 0) {
          await _db.into(_db.customerDebtPayments).insert(
                CustomerDebtPaymentsCompanion.insert(
                  customerDebtId: debtId,
                  amountPaid: downPayment,
                  paymentMethod: const Value('cash'), // DP dicatat sebagai Tunai
                  createdAt: Value(now),
                ),
              );
        }
      }

      // 3. Insert Order Items & Update Stok
      for (var item in cartItems) {
        final Product product = item['product'];
        final ProductUnit unit = item['unit'];
        final double qty = item['quantity'];
        final double price = item['price'];
        final double disc = item['discountAmount'] ?? 0.0;
        final double sub = (qty * price) - disc;
        final int minQty = item['appliedMinQty'] ?? 1;

        await _db.into(_db.orderItems).insert(
              OrderItemsCompanion.insert(
                orderId: orderId,
                productId: product.id,
                unitId: unit.id,
                quantity: qty,
                price: price,
                discountAmount: Value(disc),
                subtotal: sub,
                minQtyApplied: Value(minQty),
              ),
            );

        // Jika produk mengelola stok, update stok
        if (product.isStockManaged) {
          final existingStock = await (_db.select(_db.inventory)
                ..where((tbl) => tbl.productId.equals(product.id) & tbl.unitId.equals(unit.id)))
              .getSingleOrNull();

          if (existingStock == null) {
            await _db.into(_db.inventory).insert(
                  InventoryCompanion.insert(
                    productId: product.id,
                    unitId: unit.id,
                    quantity: Value(-qty),
                  ),
                );
          } else {
            await _db.update(_db.inventory).replace(
                  existingStock.copyWith(quantity: existingStock.quantity - qty),
                );
          }

          // Catat log pergerakan stok
          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  productId: product.id,
                  unitId: unit.id,
                  quantity: -qty,
                  type: 'sale',
                  referenceNo: Value(refNo),
                  notes: Value('Penjualan POS Ref: $refNo'),
                  createdAt: Value(now),
                ),
              );
        }
      }

      // 4. Insert Payments
      for (var p in payments) {
        await _db.into(_db.orderPayments).insert(
              OrderPaymentsCompanion.insert(
                orderId: orderId,
                paymentMethod: p['method'],
                amount: p['amount'],
                referenceId: Value(p['referenceId']),
              ),
            );
      }

      // 5. Insert Point Transactions (jika pelanggan dipilih & points_enabled)
      if (customerId != null && (pointsEarned > 0 || pointsRedeemed > 0)) {
        if (pointsEarned > 0) {
          await _db.into(_db.pointTransactions).insert(
                PointTransactionsCompanion.insert(
                  customerId: customerId,
                  orderId: Value(orderId),
                  type: 'earn',
                  points: pointsEarned,
                  description: Value('Transaksi $refNo'),
                  createdAt: Value(now),
                ),
              );
        }
        if (pointsRedeemed > 0) {
          await _db.into(_db.pointTransactions).insert(
                PointTransactionsCompanion.insert(
                  customerId: customerId,
                  orderId: Value(orderId),
                  type: 'redeem',
                  points: -pointsRedeemed,
                  description: Value('Penukaran poin transaksi $refNo'),
                  createdAt: Value(now),
                ),
              );
        }
        // Update saldo poin pelanggan
        final customer = await (_db.select(_db.customers)
              ..where((tbl) => tbl.id.equals(customerId)))
            .getSingle();
        await _db.update(_db.customers).replace(
              customer.copyWith(
                pointsBalance: customer.pointsBalance + pointsEarned - pointsRedeemed,
              ),
            );
      }

      return orderId;
    });
  }

  // Tahan transaksi
  Future<void> holdOrder({
    required int userId,
    required String referenceNo,
    required String cartDataJson,
    int? customerId,
  }) async {
    await _db.into(_db.posHeldOrders).insert(
          PosHeldOrdersCompanion.insert(
            userId: userId,
            referenceNo: referenceNo,
            cartData: cartDataJson,
            customerId: Value(customerId),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  // Ambil transaksi ditahan
  Future<List<PosHeldOrder>> getHeldOrders(int userId) async {
    return await (_db.select(_db.posHeldOrders)
          ..where((tbl) => tbl.userId.equals(userId)))
        .get();
  }

  // Hapus transaksi ditahan
  Future<void> deleteHeldOrder(int id) async {
    await (_db.delete(_db.posHeldOrders)..where((tbl) => tbl.id.equals(id))).go();
  }

  // --- SETTINGS HELPERS ---
  Future<String?> getSetting(String key) async {
    final row = await (_db.select(_db.settings)..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> saveSetting(String key, String value) async {
    await _db.into(_db.settings).insert(
          SettingsCompanion(
            key: Value(key),
            value: Value(value),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  // --- POINTS SETTINGS ---
  Future<Map<String, int>> getPointsSettings() async {
    final enabled = await getSetting('points_enabled');
    final earnRate = await getSetting('points_earn_rate');
    final redeemValue = await getSetting('points_redeem_value');
    final minRedeem = await getSetting('points_min_redeem');
    return {
      'enabled': enabled == '1' ? 1 : 0,
      'earnRate': int.tryParse(earnRate ?? '1000') ?? 1000,
      'redeemValue': int.tryParse(redeemValue ?? '10') ?? 10,
      'minRedeem': int.tryParse(minRedeem ?? '100') ?? 100,
    };
  }

  Future<int> getCustomerPointsBalance(int customerId) async {
    final customer = await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.equals(customerId)))
        .getSingleOrNull();
    return customer?.pointsBalance ?? 0;
  }

  // --- COMPLETED ORDERS HELPERS ---
  Future<List<Order>> getRecentOrders({int limit = 50}) async {
    return await (_db.select(_db.orders)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  Future<Map<String, dynamic>?> getOrderDetails(int orderId) async {
    final order = await (_db.select(_db.orders)..where((tbl) => tbl.id.equals(orderId))).getSingleOrNull();
    if (order == null) return null;

    final items = await (_db.select(_db.orderItems)..where((tbl) => tbl.orderId.equals(orderId))).get();

    final productIds = items.map((i) => i.productId).toSet().toList();
    final unitIds = items.map((i) => i.unitId).toSet().toList();
    final products = await (_db.select(_db.products)
          ..where((tbl) => tbl.id.isIn(productIds)))
        .get();
    final units = await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.id.isIn(unitIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};
    final unitMap = {for (var u in units) u.id: u};

    final itemsWithDetails = items.map((item) {
      return {
        'item': item,
        'product': productMap[item.productId],
        'unit': unitMap[item.unitId],
      };
    }).toList();

    final payments = await (_db.select(_db.orderPayments)..where((tbl) => tbl.orderId.equals(orderId))).get();
    
    Customer? customer;
    if (order.customerId != null) {
      customer = await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(order.customerId!))).getSingleOrNull();
    }

    final session = await (_db.select(_db.cashierSessions)..where((tbl) => tbl.id.equals(order.cashierSessionId))).getSingleOrNull();

    final pointTxns = await (_db.select(_db.pointTransactions)
          ..where((tbl) => tbl.orderId.equals(orderId)))
        .get();
    int pointsEarned = 0;
    int pointsRedeemed = 0;
    for (var txn in pointTxns) {
      if (txn.type == 'earn') pointsEarned += txn.points;
      if (txn.type == 'redeem') pointsRedeemed += txn.points.abs();
    }

    return {
      'order': order,
      'items': itemsWithDetails,
      'payments': payments,
      'customer': customer,
      'session': session,
      'pointsEarned': pointsEarned,
      'pointsRedeemed': pointsRedeemed,
    };
  }

  // Membatalkan transaksi (void) secara atomik
  Future<void> voidOrder(int orderId) async {
    await _db.transaction(() async {
      // 1. Ambil order
      final order = await (_db.select(_db.orders)
            ..where((tbl) => tbl.id.equals(orderId)))
          .getSingleOrNull();
      if (order == null || order.status == 'void') return;

      // Validasi sesi kasir aktif
      final session = await (_db.select(_db.cashierSessions)
            ..where((tbl) => tbl.id.equals(order.cashierSessionId)))
          .getSingleOrNull();
      if (session == null || session.status != 'open') {
        throw Exception('Transaksi hanya bisa dibatalkan saat sesi kasir bersangkutan masih aktif.');
      }

      // 2. Update status order menjadi void
      await (_db.update(_db.orders)
            ..where((tbl) => tbl.id.equals(orderId)))
          .write(const OrdersCompanion(status: Value('void')));

      // 3. Ambil item-item belanjaan untuk mengembalikan stok
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.equals(orderId)))
          .get();

      final now = DateTime.now();

      for (var item in items) {
        final product = await (_db.select(_db.products)
              ..where((tbl) => tbl.id.equals(item.productId)))
            .getSingleOrNull();

        if (product != null && product.isStockManaged) {
          // Tambahkan stok kembali ke Inventory
          final existingStock = await (_db.select(_db.inventory)
                ..where((tbl) => tbl.productId.equals(product.id) & tbl.unitId.equals(item.unitId)))
              .getSingleOrNull();

          if (existingStock == null) {
            await _db.into(_db.inventory).insert(
                  InventoryCompanion.insert(
                    productId: product.id,
                    unitId: item.unitId,
                    quantity: Value(item.quantity),
                  ),
                );
          } else {
            await _db.update(_db.inventory).replace(
                  existingStock.copyWith(quantity: existingStock.quantity + item.quantity),
                );
          }

          // Catat log pengembalian stok
          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  productId: product.id,
                  unitId: item.unitId,
                  quantity: item.quantity,
                  type: 'void_revert',
                  referenceNo: Value(order.referenceNo),
                  notes: Value('Pembatalan Transaksi Ref: ${order.referenceNo}'),
                  createdAt: Value(now),
                ),
              );
        }
      }

      // 4. Hapus hutang pelanggan terkait jika ada (otomatis meng-cascade ke histori cicilan)
      await (_db.delete(_db.customerDebts)
            ..where((tbl) => tbl.orderId.equals(orderId)))
          .go();
    });
  }
}
