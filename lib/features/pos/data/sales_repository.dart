import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class SalesRepository {
  final AppDatabase _db;

  SalesRepository(this._db);

  // Mengambil daftar produk lengkap beserta unit dan harga jualnya
  Future<List<Map<String, dynamic>>> getPosProducts() async {
    final products = await _db.select(_db.products).get();
    final List<Map<String, dynamic>> results = [];
    
    for (var product in products) {
      final units = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.productId.equals(product.id)))
          .get();
      final prices = await (_db.select(_db.productPrices)
            ..where((tbl) => tbl.productId.equals(product.id)))
          .get();
      results.add({
        'product': product,
        'units': units,
        'prices': prices,
      });
    }
    return results;
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
  }) async {
    return await _db.transaction(() async {
      // 1. Generate nomor referensi transaksi: TRX-YYYYMMDD-XXXX
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final countQuery = _db.select(_db.orders)
        ..where((tbl) => tbl.referenceNo.like('TRX-$dateStr-%'));
      final count = (await countQuery.get()).length + 1;
      final refNo = "TRX-$dateStr-${count.toString().padLeft(4, '0')}";

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

        await _db.into(_db.orderItems).insert(
              OrderItemsCompanion.insert(
                orderId: orderId,
                productId: product.id,
                unitId: unit.id,
                quantity: qty,
                price: price,
                discountAmount: Value(disc),
                subtotal: sub,
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
    final List<Map<String, dynamic>> itemsWithDetails = [];
    
    for (var item in items) {
      final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
      final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();
      itemsWithDetails.add({
        'item': item,
        'product': product,
        'unit': unit,
      });
    }

    final payments = await (_db.select(_db.orderPayments)..where((tbl) => tbl.orderId.equals(orderId))).get();
    
    Customer? customer;
    if (order.customerId != null) {
      customer = await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(order.customerId!))).getSingleOrNull();
    }

    final session = await (_db.select(_db.cashierSessions)..where((tbl) => tbl.id.equals(order.cashierSessionId))).getSingleOrNull();

    return {
      'order': order,
      'items': itemsWithDetails,
      'payments': payments,
      'customer': customer,
      'session': session,
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
