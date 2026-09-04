import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ConsignmentSupplierSummary {
  final Supplier supplier;
  final int totalProducts;
  final double totalPhysicalStock;
  final double unsettledSalesAmount;
  final double unsettledSupplierPayable;
  final double unsettledStoreCommission;
  final int unsettledSoldQty;

  ConsignmentSupplierSummary({
    required this.supplier,
    required this.totalProducts,
    required this.totalPhysicalStock,
    required this.unsettledSalesAmount,
    required this.unsettledSupplierPayable,
    required this.unsettledStoreCommission,
    required this.unsettledSoldQty,
  });
}

class ConsignmentUnsettledItem {
  final Product product;
  final ProductUnit unit;
  final double soldQty;
  final double averageSalePrice;
  final double totalSalesAmount;
  final double supplierRate; // Harga setor per unit atau hak bersih per unit
  final double supplierPayable; // soldQty * supplierRate
  final double storeCommission; // totalSalesAmount - supplierPayable

  ConsignmentUnsettledItem({
    required this.product,
    required this.unit,
    required this.soldQty,
    required this.averageSalePrice,
    required this.totalSalesAmount,
    required this.supplierRate,
    required this.supplierPayable,
    required this.storeCommission,
  });
}

class ConsignmentRepository {
  final AppDatabase _db;

  ConsignmentRepository(this._db);

  // 1. Mengambil ringkasan semua Supplier Konsinyasi
  Future<List<ConsignmentSupplierSummary>> getConsignmentSuppliersSummary() async {
    final suppliers = await _db.select(_db.suppliers).get();
    final List<ConsignmentSupplierSummary> summaries = [];

    for (var supplier in suppliers) {
      // Ambil produk konsinyasi milik supplier ini
      final products = await (_db.select(_db.products)
            ..where((tbl) => tbl.supplierId.equals(supplier.id) & tbl.isConsignment.equals(true)))
          .get();

      if (products.isEmpty) continue;

      final productIds = products.map((p) => p.id).toList();

      // Hitung total stok fisik aktif
      final invList = await (_db.select(_db.inventory)
            ..where((tbl) => tbl.productId.isIn(productIds)))
          .get();
      final totalStock = invList.fold<double>(0.0, (sum, item) => sum + item.quantity);

      // Hitung barang terjual yang belum di-settle
      final unsettledItems = await getUnsettledItemsForSupplier(supplier.id);

      double unsettledSales = 0.0;
      double unsettledPayable = 0.0;
      double unsettledComm = 0.0;
      int unsettledQty = 0;

      for (var item in unsettledItems) {
        unsettledSales += item.totalSalesAmount;
        unsettledPayable += item.supplierPayable;
        unsettledComm += item.storeCommission;
        unsettledQty += item.soldQty.toInt();
      }

      summaries.add(ConsignmentSupplierSummary(
        supplier: supplier,
        totalProducts: products.length,
        totalPhysicalStock: totalStock,
        unsettledSalesAmount: unsettledSales,
        unsettledSupplierPayable: unsettledPayable,
        unsettledStoreCommission: unsettledComm,
        unsettledSoldQty: unsettledQty,
      ));
    }

    return summaries;
  }

  // 2. Mengambil item penjualan konsinyasi yang belum masuk settlement
  Future<List<ConsignmentUnsettledItem>> getUnsettledItemsForSupplier(
    int supplierId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Cari semua produk konsinyasi untuk supplier ini
    final products = await (_db.select(_db.products)
          ..where((tbl) => tbl.supplierId.equals(supplierId) & tbl.isConsignment.equals(true)))
        .get();

    if (products.isEmpty) return [];

    final productMap = {for (var p in products) p.id: p};
    final productIds = productMap.keys.toList();

    // Ambil semua order completed
    var ordersQuery = _db.select(_db.orders)
      ..where((tbl) => tbl.status.equals('completed'));

    if (startDate != null) {
      ordersQuery = ordersQuery..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      ordersQuery = ordersQuery..where((tbl) => tbl.createdAt.isSmallerOrEqualValue(endDate));
    }

    final orders = await ordersQuery.get();
    if (orders.isEmpty) return [];

    final orderIds = orders.map((o) => o.id).toList();

    // Ambil order items untuk produk-produk konsinyasi tersebut
    final orderItems = await (_db.select(_db.orderItems)
          ..where((tbl) => tbl.orderId.isIn(orderIds) & tbl.productId.isIn(productIds)))
        .get();

    if (orderItems.isEmpty) return [];

    // Ambil semua settlement items yang SUDAH pernah dibuat untuk mengecualikan kuantiti yang sudah di-settle
    final existingSettlementItems = await (_db.select(_db.consignmentSettlementItems)
          ..where((tbl) => tbl.productId.isIn(productIds)))
        .get();

    final alreadySettledQtyByProduct = <int, double>{};
    for (var sItem in existingSettlementItems) {
      alreadySettledQtyByProduct[sItem.productId] =
          (alreadySettledQtyByProduct[sItem.productId] ?? 0.0) + sItem.soldQty;
    }

    // Kelompokkan total order items per productId & unitId
    final Map<int, List<OrderItem>> groupedByProduct = {};
    for (var oi in orderItems) {
      groupedByProduct.putIfAbsent(oi.productId, () => []).add(oi);
    }

    final List<ConsignmentUnsettledItem> result = [];

    for (var entry in groupedByProduct.entries) {
      final pId = entry.key;
      final items = entry.value;
      final product = productMap[pId]!;

      final totalQtySold = items.fold<double>(0.0, (sum, i) => sum + i.quantity);
      final alreadySettledQty = alreadySettledQtyByProduct[pId] ?? 0.0;
      final netUnsettledQty = totalQtySold - alreadySettledQty;

      if (netUnsettledQty <= 0) continue;

      final totalRevenue = items.fold<double>(0.0, (sum, i) => sum + i.subtotal);
      final avgPrice = totalQtySold > 0 ? totalRevenue / totalQtySold : 0.0;
      final currentRevenue = avgPrice * netUnsettledQty;

      // Ambil unit info
      final unit = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.id.equals(items.first.unitId)))
          .getSingleOrNull() ??
          ProductUnit(id: items.first.unitId, productId: pId, name: 'Pcs', conversionFactor: 1.0, isBase: true, costPrice: 0.0);

      // Hitung hak penitip berdasarkan consignmentType
      double supplierRate = 0.0;
      double supplierPayable = 0.0;
      double storeCommission = 0.0;

      if (product.consignmentType == 'commission_percent') {
        final commRate = product.commissionRate; // misal 20%
        final commPerUnit = avgPrice * (commRate / 100.0);
        supplierRate = avgPrice - commPerUnit;
        supplierPayable = supplierRate * netUnsettledQty;
        storeCommission = commPerUnit * netUnsettledQty;
      } else {
        // 'fixed_cost' (harga setor tetap)
        supplierRate = product.commissionRate > 0 ? product.commissionRate : avgPrice * 0.8;
        supplierPayable = supplierRate * netUnsettledQty;
        storeCommission = currentRevenue - supplierPayable;
        if (storeCommission < 0) storeCommission = 0.0;
      }

      result.add(ConsignmentUnsettledItem(
        product: product,
        unit: unit,
        soldQty: netUnsettledQty,
        averageSalePrice: avgPrice,
        totalSalesAmount: currentRevenue,
        supplierRate: supplierRate,
        supplierPayable: supplierPayable,
        storeCommission: storeCommission,
      ));
    }

    return result;
  }

  // 3. Membuat Faktur Settlement Baru
  Future<int> createSettlement({
    required int supplierId,
    required DateTime startDate,
    required DateTime endDate,
    required List<ConsignmentUnsettledItem> items,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
  }) async {
    return await _db.transaction(() async {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final randSuffix = (now.microsecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final settlementNo = 'CSL-$dateStr-$randSuffix';

      double totalSoldQty = 0.0;
      double totalSales = 0.0;
      double totalComm = 0.0;
      double totalPayable = 0.0;

      for (var item in items) {
        totalSoldQty += item.soldQty;
        totalSales += item.totalSalesAmount;
        totalComm += item.storeCommission;
        totalPayable += item.supplierPayable;
      }

      String paymentStatus = 'unpaid';
      if (paidAmount >= totalPayable && totalPayable > 0) {
        paymentStatus = 'paid';
      } else if (paidAmount > 0) {
        paymentStatus = 'partial';
      }

      final settlementId = await _db.into(_db.consignmentSettlements).insert(
        ConsignmentSettlementsCompanion.insert(
          settlementNo: settlementNo,
          supplierId: supplierId,
          startDate: startDate,
          endDate: endDate,
          totalSoldQty: Value(totalSoldQty),
          totalSalesAmount: Value(totalSales),
          storeCommissionAmount: Value(totalComm),
          supplierPayableAmount: Value(totalPayable),
          paidAmount: Value(paidAmount),
          paymentStatus: Value(paymentStatus),
          paymentMethod: Value(paymentMethod),
          notes: Value(notes),
          createdAt: Value(now),
        ),
      );

      for (var item in items) {
        await _db.into(_db.consignmentSettlementItems).insert(
          ConsignmentSettlementItemsCompanion.insert(
            settlementId: settlementId,
            productId: item.product.id,
            unitId: item.unit.id,
            soldQty: item.soldQty,
            unitPrice: item.averageSalePrice,
            supplierRate: item.supplierRate,
            subtotalPayable: item.supplierPayable,
            subtotalCommission: item.storeCommission,
          ),
        );
      }

      return settlementId;
    });
  }

  // 4. Mengambil Riwayat Settlement
  Future<List<Map<String, dynamic>>> getSettlements({int? supplierId}) async {
    var query = _db.select(_db.consignmentSettlements).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.consignmentSettlements.supplierId)),
    ]);

    if (supplierId != null) {
      query = query..where(_db.consignmentSettlements.supplierId.equals(supplierId));
    }

    query = query..orderBy([OrderingTerm.desc(_db.consignmentSettlements.createdAt)]);

    final rows = await query.get();
    return rows.map((row) {
      return {
        'settlement': row.readTable(_db.consignmentSettlements),
        'supplier': row.readTable(_db.suppliers),
      };
    }).toList();
  }

  // 5. Mengambil Rincian Satu Settlement Lengkap
  Future<Map<String, dynamic>?> getSettlementDetail(int settlementId) async {
    final settlement = await (_db.select(_db.consignmentSettlements)
          ..where((tbl) => tbl.id.equals(settlementId)))
        .getSingleOrNull();

    if (settlement == null) return null;

    final supplier = await (_db.select(_db.suppliers)
          ..where((tbl) => tbl.id.equals(settlement.supplierId)))
        .getSingleOrNull();

    final itemRows = await (_db.select(_db.consignmentSettlementItems).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.consignmentSettlementItems.productId)),
      innerJoin(_db.productUnits, _db.productUnits.id.equalsExp(_db.consignmentSettlementItems.unitId)),
    ])..where(_db.consignmentSettlementItems.settlementId.equals(settlementId))).get();

    final items = itemRows.map((row) {
      return {
        'item': row.readTable(_db.consignmentSettlementItems),
        'product': row.readTable(_db.products),
        'unit': row.readTable(_db.productUnits),
      };
    }).toList();

    return {
      'settlement': settlement,
      'supplier': supplier,
      'items': items,
    };
  }

  // 6. Melakukan Pembayaran Tambahan / Pelunasan Settlement
  Future<bool> paySettlement(int settlementId, double paymentAmount, String paymentMethod) async {
    final settlement = await (_db.select(_db.consignmentSettlements)
          ..where((tbl) => tbl.id.equals(settlementId)))
        .getSingleOrNull();

    if (settlement == null) return false;

    final newPaid = settlement.paidAmount + paymentAmount;
    String newStatus = settlement.paymentStatus;

    if (newPaid >= settlement.supplierPayableAmount) {
      newStatus = 'paid';
    } else if (newPaid > 0) {
      newStatus = 'partial';
    }

    final updated = await (_db.update(_db.consignmentSettlements)
          ..where((tbl) => tbl.id.equals(settlementId)))
        .write(
      ConsignmentSettlementsCompanion(
        paidAmount: Value(newPaid),
        paymentStatus: Value(newStatus),
        paymentMethod: Value(paymentMethod),
      ),
    );

    return updated > 0;
  }

  // 7. Mengambil Data Monitoring Stok Fisik Produk Konsinyasi
  Future<List<Map<String, dynamic>>> getConsignmentStockReport() async {
    final query = _db.select(_db.products).join([
      innerJoin(_db.suppliers, _db.suppliers.id.equalsExp(_db.products.supplierId)),
      leftOuterJoin(_db.inventory, _db.inventory.productId.equalsExp(_db.products.id)),
    ])..where(_db.products.isConsignment.equals(true));

    final rows = await query.get();

    return rows.map((row) {
      return {
        'product': row.readTable(_db.products),
        'supplier': row.readTable(_db.suppliers),
        'inventory': row.readTableOrNull(_db.inventory),
      };
    }).toList();
  }
}
