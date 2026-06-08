import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ReturnRepository {
  final AppDatabase _db;

  ReturnRepository(this._db);

  // --- SALES RETURNS (RETUR PENJUALAN) ---

  // Ambil semua riwayat retur penjualan
  Future<List<Map<String, dynamic>>> getSalesReturns() async {
    final returns = await (_db.select(_db.salesReturns)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    final List<Map<String, dynamic>> results = [];
    for (var r in returns) {
      final customer = r.customerId != null
          ? await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(r.customerId!))).getSingleOrNull()
          : null;

      final order = r.orderId != null
          ? await (_db.select(_db.orders)..where((tbl) => tbl.id.equals(r.orderId!))).getSingleOrNull()
          : null;

      results.add({
        'return': r,
        'customer': customer,
        'order': order,
      });
    }
    return results;
  }

  // Ambil detail item dari satu transaksi retur penjualan
  Future<Map<String, dynamic>?> getSalesReturnDetails(int returnId) async {
    final ret = await (_db.select(_db.salesReturns)..where((tbl) => tbl.id.equals(returnId))).getSingleOrNull();
    if (ret == null) return null;

    final customer = ret.customerId != null
        ? await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(ret.customerId!))).getSingleOrNull()
        : null;

    final order = ret.orderId != null
        ? await (_db.select(_db.orders)..where((tbl) => tbl.id.equals(ret.orderId!))).getSingleOrNull()
        : null;

    final items = await (_db.select(_db.salesReturnItems)..where((tbl) => tbl.salesReturnId.equals(returnId))).get();
    final List<Map<String, dynamic>> itemDetails = [];

    for (var item in items) {
      final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
      final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();
      itemDetails.add({
        'item': item,
        'product': product,
        'unit': unit,
      });
    }

    return {
      'return': ret,
      'customer': customer,
      'order': order,
      'items': itemDetails,
    };
  }

  // Simpan transaksi Retur Penjualan secara atomik
  Future<int> saveSalesReturn({
    int? orderId,
    int? customerId,
    required int cashierSessionId,
    required List<Map<String, dynamic>> items, // contains: productId, unitId, quantity, price
    required double refundAmount,
    required String refundMethod, // 'cash' / 'debt_reduction'
    String? notes,
  }) async {
    return await _db.transaction(() async {
      final now = DateTime.now();
      
      // 1. Generate Ref No: RETS-YYYYMMDD-XXXX
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final countQuery = _db.select(_db.salesReturns)..where((tbl) => tbl.referenceNo.like('RETS-$dateStr-%'));
      final count = (await countQuery.get()).length + 1;
      final refNo = "RETS-$dateStr-${count.toString().padLeft(4, '0')}";

      // 2. Insert Sales Return
      final returnId = await _db.into(_db.salesReturns).insert(
            SalesReturnsCompanion.insert(
              orderId: Value(orderId),
              customerId: Value(customerId),
              cashierSessionId: cashierSessionId,
              referenceNo: refNo,
              refundAmount: Value(refundAmount),
              refundMethod: Value(refundMethod),
              notes: Value(notes),
              createdAt: Value(now),
            ),
          );

      // 3. Insert Items, Update Stock, & Log Stock Movement
      for (var item in items) {
        final int prodId = item['productId'];
        final int uniId = item['unitId'];
        final double qty = item['quantity'];
        final double price = item['price'];
        final double itemSubtotal = qty * price;

        // Save detail item
        await _db.into(_db.salesReturnItems).insert(
              SalesReturnItemsCompanion.insert(
                salesReturnId: returnId,
                productId: prodId,
                unitId: uniId,
                quantity: qty,
                price: price,
                subtotal: itemSubtotal,
              ),
            );

        // Check if stock managed
        final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(prodId))).getSingleOrNull();
        if (product != null && product.isStockManaged) {
          final existingInventory = await (_db.select(_db.inventory)
                ..where((tbl) => tbl.productId.equals(prodId) & tbl.unitId.equals(uniId)))
              .getSingleOrNull();

          if (existingInventory == null) {
            await _db.into(_db.inventory).insert(
                  InventoryCompanion.insert(
                    productId: prodId,
                    unitId: uniId,
                    quantity: Value(qty), // Stok bertambah karena diretur pelanggan
                  ),
                );
          } else {
            await _db.update(_db.inventory).replace(
                  existingInventory.copyWith(quantity: existingInventory.quantity + qty),
                );
          }

          // Stock movements log
          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  productId: prodId,
                  unitId: uniId,
                  quantity: qty, // Positif karena bertambah
                  type: 'sales_return',
                  referenceNo: Value(refNo),
                  notes: Value('Retur Penjualan Ref: $refNo'),
                  createdAt: Value(now),
                ),
              );
        }
      }

      // 4. Jika 'debt_reduction', kurangi piutang pelanggan
      if (refundMethod == 'debt_reduction' && orderId != null) {
        final debt = await (_db.select(_db.customerDebts)..where((tbl) => tbl.orderId.equals(orderId))).getSingleOrNull();
        if (debt != null) {
          final double newAmount = (debt.amount - refundAmount).clamp(0.0, double.infinity);
          final bool isLunas = debt.paidAmount >= newAmount;
          await _db.update(_db.customerDebts).replace(
                debt.copyWith(
                  amount: newAmount,
                  status: isLunas ? 'paid' : (debt.paidAmount > 0 ? 'partial' : 'unpaid'),
                ),
              );
        }
      }

      return returnId;
    });
  }

  // --- SUPPLIER RETURNS (RETUR PEMBELIAN) ---

  // Ambil semua riwayat retur pembelian
  Future<List<Map<String, dynamic>>> getPurchaseReturns() async {
    final returns = await (_db.select(_db.purchaseReturns)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    final List<Map<String, dynamic>> results = [];
    for (var r in returns) {
      final supplier = await (_db.select(_db.suppliers)..where((tbl) => tbl.id.equals(r.supplierId))).getSingleOrNull();
      final purchase = r.purchaseId != null
          ? await (_db.select(_db.purchases)..where((tbl) => tbl.id.equals(r.purchaseId!))).getSingleOrNull()
          : null;

      results.add({
        'return': r,
        'supplier': supplier,
        'purchase': purchase,
      });
    }
    return results;
  }

  // Ambil detail item dari satu transaksi retur pembelian
  Future<Map<String, dynamic>?> getPurchaseReturnDetails(int returnId) async {
    final ret = await (_db.select(_db.purchaseReturns)..where((tbl) => tbl.id.equals(returnId))).getSingleOrNull();
    if (ret == null) return null;

    final supplier = await (_db.select(_db.suppliers)..where((tbl) => tbl.id.equals(ret.supplierId))).getSingleOrNull();
    final purchase = ret.purchaseId != null
        ? await (_db.select(_db.purchases)..where((tbl) => tbl.id.equals(ret.purchaseId!))).getSingleOrNull()
        : null;

    final items = await (_db.select(_db.purchaseReturnItems)..where((tbl) => tbl.purchaseReturnId.equals(returnId))).get();
    final List<Map<String, dynamic>> itemDetails = [];

    for (var item in items) {
      final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
      final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();
      itemDetails.add({
        'item': item,
        'product': product,
        'unit': unit,
      });
    }

    return {
      'return': ret,
      'supplier': supplier,
      'purchase': purchase,
      'items': itemDetails,
    };
  }

  // Simpan transaksi Retur Pembelian secara atomik
  Future<int> savePurchaseReturn({
    int? purchaseId,
    required int supplierId,
    required int cashierSessionId,
    required List<Map<String, dynamic>> items, // contains: productId, unitId, quantity, costPrice
    required double refundAmount,
    required String refundMethod, // 'cash' / 'debt_reduction'
    String? notes,
  }) async {
    return await _db.transaction(() async {
      final now = DateTime.now();
      
      // 1. Generate Ref No: RETP-YYYYMMDD-XXXX
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final countQuery = _db.select(_db.purchaseReturns)..where((tbl) => tbl.referenceNo.like('RETP-$dateStr-%'));
      final count = (await countQuery.get()).length + 1;
      final refNo = "RETP-$dateStr-${count.toString().padLeft(4, '0')}";

      // 2. Insert Purchase Return
      final returnId = await _db.into(_db.purchaseReturns).insert(
            PurchaseReturnsCompanion.insert(
              purchaseId: Value(purchaseId),
              supplierId: supplierId,
              cashierSessionId: cashierSessionId,
              referenceNo: refNo,
              refundAmount: Value(refundAmount),
              refundMethod: Value(refundMethod),
              notes: Value(notes),
              createdAt: Value(now),
            ),
          );

      // 3. Insert Items, Update Stock, & Log Stock Movement
      for (var item in items) {
        final int prodId = item['productId'];
        final int uniId = item['unitId'];
        final double qty = item['quantity'];
        final double cost = item['costPrice'];
        final double itemSubtotal = qty * cost;

        // Save detail item
        await _db.into(_db.purchaseReturnItems).insert(
              PurchaseReturnItemsCompanion.insert(
                purchaseReturnId: returnId,
                productId: prodId,
                unitId: uniId,
                quantity: qty,
                costPrice: cost,
                subtotal: itemSubtotal,
              ),
            );

        // Update Stock (Mengurangi stok karena dikembalikan ke supplier)
        final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(prodId))).getSingleOrNull();
        if (product != null && product.isStockManaged) {
          final existingInventory = await (_db.select(_db.inventory)
                ..where((tbl) => tbl.productId.equals(prodId) & tbl.unitId.equals(uniId)))
              .getSingleOrNull();

          if (existingInventory == null) {
            await _db.into(_db.inventory).insert(
                  InventoryCompanion.insert(
                    productId: prodId,
                    unitId: uniId,
                    quantity: Value(-qty), // Negatif karena dikurangi dari toko
                  ),
                );
          } else {
            await _db.update(_db.inventory).replace(
                  existingInventory.copyWith(quantity: existingInventory.quantity - qty),
                );
          }

          // Stock movements log
          await _db.into(_db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  productId: prodId,
                  unitId: uniId,
                  quantity: -qty, // Negatif
                  type: 'purchase_return',
                  referenceNo: Value(refNo),
                  notes: Value('Retur Pembelian Supplier Ref: $refNo'),
                  createdAt: Value(now),
                ),
              );
        }
      }

      // 4. Jika 'debt_reduction', kurangi hutang ke supplier
      if (refundMethod == 'debt_reduction' && purchaseId != null) {
        final debt = await (_db.select(_db.supplierDebts)..where((tbl) => tbl.purchaseId.equals(purchaseId))).getSingleOrNull();
        if (debt != null) {
          final double newAmount = (debt.amount - refundAmount).clamp(0.0, double.infinity);
          final bool isLunas = debt.paidAmount >= newAmount;
          await _db.update(_db.supplierDebts).replace(
                debt.copyWith(
                  amount: newAmount,
                  status: isLunas ? 'paid' : (debt.paidAmount > 0 ? 'partial' : 'unpaid'),
                ),
              );
        }
      }

      return returnId;
    });
  }

  // Batal Retur Penjualan (Rollback & Hapus)
  Future<void> deleteSalesReturn(int returnId) async {
    await _db.transaction(() async {
      final ret = await (_db.select(_db.salesReturns)..where((tbl) => tbl.id.equals(returnId))).getSingleOrNull();
      if (ret == null) return;

      final items = await (_db.select(_db.salesReturnItems)..where((tbl) => tbl.salesReturnId.equals(returnId))).get();

      // 1. Revert Stock & Delete Stock Movements
      for (var item in items) {
        final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
        if (product != null && product.isStockManaged) {
          final existingInventory = await (_db.select(_db.inventory)
                ..where((tbl) => tbl.productId.equals(item.productId) & tbl.unitId.equals(item.unitId)))
              .getSingleOrNull();

          if (existingInventory != null) {
            await _db.update(_db.inventory).replace(
                  existingInventory.copyWith(
                    quantity: (existingInventory.quantity - item.quantity),
                  ),
                );
          }
        }
      }

      // Delete stock movements
      await (_db.delete(_db.stockMovements)..where((tbl) => tbl.referenceNo.equals(ret.referenceNo))).go();

      // 2. Revert Debt reduction
      if (ret.refundMethod == 'debt_reduction' && ret.orderId != null) {
        final debt = await (_db.select(_db.customerDebts)..where((tbl) => tbl.orderId.equals(ret.orderId!))).getSingleOrNull();
        if (debt != null) {
          final double newAmount = debt.amount + ret.refundAmount;
          final bool isLunas = debt.paidAmount >= newAmount;
          await _db.update(_db.customerDebts).replace(
                debt.copyWith(
                  amount: newAmount,
                  status: isLunas ? 'paid' : (debt.paidAmount > 0 ? 'partial' : 'unpaid'),
                ),
              );
        }
      }

      // 3. Delete from database
      await (_db.delete(_db.salesReturnItems)..where((tbl) => tbl.salesReturnId.equals(returnId))).go();
      await (_db.delete(_db.salesReturns)..where((tbl) => tbl.id.equals(returnId))).go();
    });
  }

  // Batal Retur Pembelian (Rollback & Hapus)
  Future<void> deletePurchaseReturn(int returnId) async {
    await _db.transaction(() async {
      final ret = await (_db.select(_db.purchaseReturns)..where((tbl) => tbl.id.equals(returnId))).getSingleOrNull();
      if (ret == null) return;

      final items = await (_db.select(_db.purchaseReturnItems)..where((tbl) => tbl.purchaseReturnId.equals(returnId))).get();

      // 1. Revert Stock & Delete Stock Movements
      for (var item in items) {
        final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
        if (product != null && product.isStockManaged) {
          final existingInventory = await (_db.select(_db.inventory)
                ..where((tbl) => tbl.productId.equals(item.productId) & tbl.unitId.equals(item.unitId)))
              .getSingleOrNull();

          if (existingInventory != null) {
            await _db.update(_db.inventory).replace(
                  existingInventory.copyWith(
                    quantity: (existingInventory.quantity + item.quantity),
                  ),
                );
          }
        }
      }

      // Delete stock movements
      await (_db.delete(_db.stockMovements)..where((tbl) => tbl.referenceNo.equals(ret.referenceNo))).go();

      // 2. Revert Debt reduction
      if (ret.refundMethod == 'debt_reduction' && ret.purchaseId != null) {
        final debt = await (_db.select(_db.supplierDebts)..where((tbl) => tbl.purchaseId.equals(ret.purchaseId!))).getSingleOrNull();
        if (debt != null) {
          final double newAmount = debt.amount + ret.refundAmount;
          final bool isLunas = debt.paidAmount >= newAmount;
          await _db.update(_db.supplierDebts).replace(
                debt.copyWith(
                  amount: newAmount,
                  status: isLunas ? 'paid' : (debt.paidAmount > 0 ? 'partial' : 'unpaid'),
                ),
              );
        }
      }

      // 3. Delete from database
      await (_db.delete(_db.purchaseReturnItems)..where((tbl) => tbl.purchaseReturnId.equals(returnId))).go();
      await (_db.delete(_db.purchaseReturns)..where((tbl) => tbl.id.equals(returnId))).go();
    });
  }
}
