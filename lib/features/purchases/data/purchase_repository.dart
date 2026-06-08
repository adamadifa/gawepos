import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class PurchaseRepository {
  final AppDatabase _db;

  PurchaseRepository(this._db);

  // Fetch all purchases (sorted newest first)
  Future<List<Map<String, dynamic>>> getPurchases() async {
    final purchases = await (_db.select(_db.purchases)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    final List<Map<String, dynamic>> results = [];
    for (var p in purchases) {
      final supplier = await (_db.select(_db.suppliers)
            ..where((tbl) => tbl.id.equals(p.supplierId)))
          .getSingleOrNull();
      results.add({
        'purchase': p,
        'supplier': supplier,
      });
    }
    return results;
  }

  // Get single purchase order details (items & supplier info)
  Future<Map<String, dynamic>?> getPurchaseDetails(int purchaseId) async {
    final purchase = await (_db.select(_db.purchases)
          ..where((tbl) => tbl.id.equals(purchaseId)))
        .getSingleOrNull();

    if (purchase == null) return null;

    final supplier = await (_db.select(_db.suppliers)
          ..where((tbl) => tbl.id.equals(purchase.supplierId)))
        .getSingleOrNull();

    final items = await (_db.select(_db.purchaseItems)
          ..where((tbl) => tbl.purchaseId.equals(purchaseId)))
        .get();

    final List<Map<String, dynamic>> itemDetails = [];
    for (var item in items) {
      final product = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(item.productId)))
          .getSingleOrNull();
      final unit = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.id.equals(item.unitId)))
          .getSingleOrNull();

      itemDetails.add({
        'item': item,
        'product': product,
        'unit': unit,
      });
    }

    return {
      'purchase': purchase,
      'supplier': supplier,
      'items': itemDetails,
    };
  }

  // Create a new purchase order
  Future<int> savePurchase({
    required int supplierId,
    required List<Map<String, dynamic>> items, // contains: productId, unitId, quantity, costPrice
    double discountAmount = 0.0,
    double taxAmount = 0.0,
    String paymentType = 'cash',
    double downPayment = 0.0,
  }) async {
    return await _db.transaction(() async {
      // 1. Generate Ref No: PUR-YYYYMMDD-XXXX
      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final countQuery = _db.select(_db.purchases)
        ..where((tbl) => tbl.referenceNo.like('PUR-$dateStr-%'));
      final count = (await countQuery.get()).length + 1;
      final refNo = "PUR-$dateStr-${count.toString().padLeft(4, '0')}";

      // Calculate Subtotal & Grand Total
      double subtotal = 0.0;
      for (var item in items) {
        final double qty = item['quantity'];
        final double cost = item['costPrice'];
        subtotal += (qty * cost);
      }
      final grandTotal = subtotal - discountAmount + taxAmount;

      // 2. Insert Purchase
      final purchaseId = await _db.into(_db.purchases).insert(
            PurchasesCompanion.insert(
              supplierId: supplierId,
              referenceNo: refNo,
              status: const Value('pending'),
              paymentType: Value(paymentType),
              subtotal: Value(subtotal),
              discountAmount: Value(discountAmount),
              taxAmount: Value(taxAmount),
              grandTotal: Value(grandTotal),
              downPayment: Value(downPayment),
              createdAt: Value(now),
            ),
          );

      // 3. Insert Purchase Items
      for (var item in items) {
        final int prodId = item['productId'];
        final int uniId = item['unitId'];
        final double qty = item['quantity'];
        final double cost = item['costPrice'];
        final itemSubtotal = qty * cost;

        await _db.into(_db.purchaseItems).insert(
              PurchaseItemsCompanion.insert(
                purchaseId: purchaseId,
                productId: prodId,
                unitId: uniId,
                quantity: qty,
                costPrice: cost,
                subtotal: itemSubtotal,
              ),
            );
      }

      return purchaseId;
    });
  }

  // Confirm receipt of purchase (Updates stock levels & logs history)
  Future<void> confirmReceive(int purchaseId) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      final purchase = await (_db.select(_db.purchases)
            ..where((tbl) => tbl.id.equals(purchaseId)))
          .getSingleOrNull();

      if (purchase == null) throw Exception('Purchase order not found');
      if (purchase.status == 'received') throw Exception('Order has already been received');

      // Update Purchase status
      await _db.update(_db.purchases).replace(
            purchase.copyWith(status: 'received'),
          );

      // Jika pembelian menggunakan sistem Hutang, catat ke SupplierDebts
      if (purchase.paymentType == 'debt') {
        final dp = purchase.downPayment;
        final statusVal = dp >= purchase.grandTotal ? 'paid' : (dp > 0 ? 'partial' : 'unpaid');
        
        final debtId = await _db.into(_db.supplierDebts).insert(
              SupplierDebtsCompanion.insert(
                supplierId: purchase.supplierId,
                purchaseId: Value(purchaseId),
                amount: purchase.grandTotal,
                paidAmount: Value(dp),
                status: Value(statusVal),
                createdAt: Value(now),
              ),
            );

        if (dp > 0) {
          await _db.into(_db.supplierDebtPayments).insert(
                SupplierDebtPaymentsCompanion.insert(
                  supplierDebtId: debtId,
                  amountPaid: dp,
                  paymentMethod: const Value('cash'),
                  createdAt: Value(now),
                ),
              );
        }
      }

      // Fetch items
      final items = await (_db.select(_db.purchaseItems)
            ..where((tbl) => tbl.purchaseId.equals(purchaseId)))
          .get();


      for (var item in items) {
        // Find existing inventory record
        final existingInventory = await (_db.select(_db.inventory)
              ..where((tbl) => tbl.productId.equals(item.productId) & tbl.unitId.equals(item.unitId)))
            .getSingleOrNull();

        if (existingInventory == null) {
          // Create new stock record
          await _db.into(_db.inventory).insert(
                InventoryCompanion.insert(
                  productId: item.productId,
                  unitId: item.unitId,
                  quantity: Value(item.quantity),
                ),
              );
        } else {
          // Increment stock quantity
          await _db.update(_db.inventory).replace(
                existingInventory.copyWith(
                  quantity: existingInventory.quantity + item.quantity,
                ),
              );
        }

        // Write to Stock Movements
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: item.productId,
                unitId: item.unitId,
                quantity: item.quantity,
                type: 'purchase',
                referenceNo: Value(purchase.referenceNo),
                notes: Value('Restok Pembelian Supplier Ref: ${purchase.referenceNo}'),
                createdAt: Value(now),
              ),
            );
      }
    });
  }

  // Get units for a product
  Future<List<ProductUnit>> getProductUnits(int productId) async {
    return await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.productId.equals(productId)))
        .get();
  }
}
