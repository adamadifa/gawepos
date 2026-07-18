import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ReportsRepository {
  final AppDatabase _db;

  ReportsRepository(this._db);

  // Helper: Get cost price for a product/unit
  Future<double> getProductCostPrice(int productId, int unitId, double fallbackSellPrice) async {
    final purchaseItem = await (_db.select(_db.purchaseItems)
          ..where((tbl) => tbl.productId.equals(productId) & tbl.unitId.equals(unitId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.id, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    if (purchaseItem != null) {
      return purchaseItem.costPrice;
    }
    // Fallback: 60% of the sale price
    return fallbackSellPrice * 0.6;
  }

  // Get Summary & Stats with optional date range
  Future<Map<String, dynamic>> getDashboardData({DateTime? start, DateTime? end}) async {
    final now = DateTime.now();
    final startOfDay = start ?? DateTime(now.year, now.month, now.day);
    final endOfDay = end ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // --- Aggregate penjualan (1 query vs N+1) ---
    final aggQuery = _db.selectOnly(_db.orders)
      ..addColumns([
        _db.orders.subtotal.sum(),
        _db.orders.discountAmount.sum(),
        _db.orders.taxAmount.sum(),
        _db.orders.grandTotal.sum(),
        _db.orders.id.count(),
      ])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(startOfDay) &
             _db.orders.createdAt.isSmallerOrEqualValue(endOfDay) &
             _db.orders.status.equals('completed'));
    final aggRow = await aggQuery.getSingle();

    double totalGrossSales = aggRow.read<double>(_db.orders.subtotal.sum()) ?? 0.0;
    double totalDiscount = aggRow.read<double>(_db.orders.discountAmount.sum()) ?? 0.0;
    double totalTax = aggRow.read<double>(_db.orders.taxAmount.sum()) ?? 0.0;
    double totalNetSales = aggRow.read<double>(_db.orders.grandTotal.sum()) ?? 0.0;
    final transactionCount = aggRow.read<int>(_db.orders.id.count()) ?? 0;

    // --- Hitung HPP batch (1 query untuk semua items) ---
    final todayOrders = await (_db.select(_db.orders)
        ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startOfDay) &
                         tbl.createdAt.isSmallerOrEqualValue(endOfDay) &
                         tbl.status.equals('completed')))
      .get();
    final todayOrderIds = todayOrders.map((o) => o.id).toList();

    double totalHpp = 0.0;
    if (todayOrderIds.isNotEmpty) {
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.isIn(todayOrderIds)))
          .get();
      totalHpp = await _calculateBatchHpp(items);
    }

    // --- Returns (aggregate) ---
    final retAgg = _db.selectOnly(_db.salesReturns)
      ..addColumns([_db.salesReturns.refundAmount.sum()])
      ..where(_db.salesReturns.createdAt.isBiggerOrEqualValue(startOfDay) &
              _db.salesReturns.createdAt.isSmallerOrEqualValue(endOfDay));
    final retRow = await retAgg.getSingle();
    double totalSalesReturns = retRow.read<double>(_db.salesReturns.refundAmount.sum()) ?? 0.0;

    double totalReturnedHpp = 0.0;
    if (totalSalesReturns > 0) {
      final todaySalesReturns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startOfDay) &
                           tbl.createdAt.isSmallerOrEqualValue(endOfDay))
        ).get();
      final returnIds = todaySalesReturns.map((r) => r.id).toList();

      if (returnIds.isNotEmpty) {
        final retItems = await (_db.select(_db.salesReturnItems)
              ..where((tbl) => tbl.salesReturnId.isIn(returnIds)))
            .get();
        totalReturnedHpp = await _calculateBatchHpp(retItems);
      }
    }

    totalNetSales = totalNetSales - totalSalesReturns;
    totalHpp = totalHpp - totalReturnedHpp;
    final grossProfit = totalNetSales - totalHpp;

    // --- Expenses (aggregate) ---
    final expAgg = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.amount.sum()])
      ..where(_db.expenses.date.isBiggerOrEqualValue(startOfDay) &
              _db.expenses.date.isSmallerOrEqualValue(endOfDay));
    final expRow = await expAgg.getSingle();
    final totalExpenses = expRow.read<double>(_db.expenses.amount.sum()) ?? 0.0;
    final netProfit = grossProfit - totalExpenses;

    // --- Last 7 days trend (optimasi: 2 query total) ---
    final weekStart = now.subtract(const Duration(days: 6));
    final startWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final endWeek = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final weekOrders = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startWeek) &
                           tbl.createdAt.isSmallerOrEqualValue(endWeek) &
                           tbl.status.equals('completed'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc)]))
        .get();

    final weekReturns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startWeek) &
                           tbl.createdAt.isSmallerOrEqualValue(endWeek))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc)]))
        .get();

    final List<Map<String, dynamic>> trendData = [];
    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final daySales = weekOrders
          .where((o) => o.createdAt.isAfter(dayStart.subtract(const Duration(seconds: 1))) && o.createdAt.isBefore(dayEnd.add(const Duration(seconds: 1))))
          .fold<double>(0.0, (sum, o) => sum + o.grandTotal);
      final dayRet = weekReturns
          .where((r) => r.createdAt.isAfter(dayStart.subtract(const Duration(seconds: 1))) && r.createdAt.isBefore(dayEnd.add(const Duration(seconds: 1))))
          .fold<double>(0.0, (sum, r) => sum + r.refundAmount);
      final total = (daySales - dayRet).clamp(0.0, double.infinity);

      trendData.add({
        'day': '${targetDate.day}/${targetDate.month}',
        'amount': total,
      });
    }

    // --- Best Sellers (1 query items, batch fetch products) ---
    final List<Map<String, dynamic>> bestSellers = [];
    if (todayOrderIds.isNotEmpty) {
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.isIn(todayOrderIds)))
          .get();

      final Map<int, double> productQtyMap = {};
      for (var item in items) {
        productQtyMap[item.productId] = (productQtyMap[item.productId] ?? 0) + item.quantity;
      }

      final sortedProductIds = productQtyMap.keys.toList()
        ..sort((a, b) => productQtyMap[b]!.compareTo(productQtyMap[a]!));

      final top5Ids = sortedProductIds.take(5).toList();
      if (top5Ids.isNotEmpty) {
        final products = await (_db.select(_db.products)
              ..where((tbl) => tbl.id.isIn(top5Ids)))
            .get();
        final productMap = {for (var p in products) p.id: p};
        for (var prodId in top5Ids) {
          final prod = productMap[prodId];
          if (prod != null) {
            bestSellers.add({
              'name': prod.name,
              'qty': productQtyMap[prodId],
            });
          }
        }
      }
    }

    // --- Low Stock Alert (batch fetch) ---
    final List<Map<String, dynamic>> lowStockAlerts = [];
    final activeProducts = await (_db.select(_db.products)
          ..where((tbl) => tbl.isStockManaged.equals(true) & tbl.isActive.equals(true)))
        .get();

    if (activeProducts.isNotEmpty) {
      final activeProductIds = activeProducts.map((p) => p.id).toList();
      final allUnits = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.productId.isIn(activeProductIds)))
          .get();
      final allInventory = await (_db.select(_db.inventory)
            ..where((tbl) => tbl.productId.isIn(activeProductIds)))
          .get();

      final invMap = <String, InventoryData>{};
      for (var inv in allInventory) {
        invMap['${inv.productId}_${inv.unitId}'] = inv;
      }
      final unitsByProduct = <int, List<ProductUnit>>{};
      for (var u in allUnits) {
        unitsByProduct.putIfAbsent(u.productId, () => []).add(u);
      }

      for (var p in activeProducts) {
        final units = unitsByProduct[p.id] ?? [];
        for (var u in units) {
          final inv = invMap['${p.id}_${u.id}'];
          final currentQty = inv?.quantity ?? 0.0;
          if (currentQty <= p.minStockAlert) {
            lowStockAlerts.add({
              'product': p,
              'unit': u,
              'currentStock': currentQty,
              'minAlert': p.minStockAlert,
            });
          }
        }
      }
    }

    return {
      'grossSales': totalGrossSales,
      'discount': totalDiscount,
      'tax': totalTax,
      'netSales': totalNetSales,
      'hpp': totalHpp,
      'grossProfit': grossProfit,
      'expenses': totalExpenses,
      'netProfit': netProfit,
      'transactionCount': transactionCount,
      'trend': trendData,
      'bestSellers': bestSellers,
      'lowStock': lowStockAlerts,
    };
  }

  // Helper: batch hitung HPP untuk list of items (order items / return items)
  Future<double> _calculateBatchHpp(List<dynamic> items) async {
    if (items.isEmpty) return 0.0;

    // Extract unique product/unit pairs
    final productUnitPairs = <String>{};
    for (var item in items) {
      productUnitPairs.add('${item.productId}_${item.unitId}');
    }

    double totalHpp = 0.0;
    for (var pair in productUnitPairs) {
      final parts = pair.split('_');
      final productId = int.parse(parts[0]);
      final unitId = int.parse(parts[1]);

      final cost = await getProductCostPrice(productId, unitId, 0.0);
      final qty = items
          .where((i) => i.productId == productId && i.unitId == unitId)
          .fold<double>(0.0, (sum, i) => sum + i.quantity);
      totalHpp += qty * cost;
    }
    return totalHpp;
  }

  // Get Custom range Laba Rugi Report
  Future<Map<String, dynamic>> getPnLReport(DateTime start, DateTime end) async {
    // Aggregate query
    final agg = _db.selectOnly(_db.orders)
      ..addColumns([
        _db.orders.subtotal.sum(),
        _db.orders.discountAmount.sum(),
        _db.orders.taxAmount.sum(),
        _db.orders.grandTotal.sum(),
      ])
      ..where(_db.orders.createdAt.isBiggerOrEqualValue(start) &
              _db.orders.createdAt.isSmallerOrEqualValue(end) &
              _db.orders.status.equals('completed'));
    final row = await agg.getSingle();

    double totalGrossSales = row.read<double>(_db.orders.subtotal.sum()) ?? 0.0;
    double totalDiscount = row.read<double>(_db.orders.discountAmount.sum()) ?? 0.0;
    double totalTax = row.read<double>(_db.orders.taxAmount.sum()) ?? 0.0;
    double totalNetSales = row.read<double>(_db.orders.grandTotal.sum()) ?? 0.0;
    double totalHpp = 0.0;

    final pnlOrders = await (_db.select(_db.orders)
        ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) &
                         tbl.createdAt.isSmallerOrEqualValue(end) &
                         tbl.status.equals('completed'))
    ).get();
    final orderIds = pnlOrders.map((o) => o.id).toList();

    if (orderIds.isNotEmpty) {
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.isIn(orderIds)))
          .get();
      totalHpp = await _calculateBatchHpp(items);
    }

    // Fetch Sales Returns
    final retAgg = _db.selectOnly(_db.salesReturns)
      ..addColumns([_db.salesReturns.refundAmount.sum()])
      ..where(_db.salesReturns.createdAt.isBiggerOrEqualValue(start) &
              _db.salesReturns.createdAt.isSmallerOrEqualValue(end));
    final retRow = await retAgg.getSingle();
    final totalSalesReturns = retRow.read<double>(_db.salesReturns.refundAmount.sum()) ?? 0.0;

    double totalReturnedHpp = 0.0;
    if (totalSalesReturns > 0) {
      final pnlReturns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) &
                           tbl.createdAt.isSmallerOrEqualValue(end))
        ).get();
      final returnIds = pnlReturns.map((r) => r.id).toList();

      if (returnIds.isNotEmpty) {
        final retItems = await (_db.select(_db.salesReturnItems)
              ..where((tbl) => tbl.salesReturnId.isIn(returnIds)))
            .get();
        totalReturnedHpp = await _calculateBatchHpp(retItems);
      }
    }

    totalNetSales = totalNetSales - totalSalesReturns;
    totalHpp = totalHpp - totalReturnedHpp;
    final grossProfit = totalNetSales - totalHpp;

    final expAgg = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.amount.sum()])
      ..where(_db.expenses.date.isBiggerOrEqualValue(start) &
              _db.expenses.date.isSmallerOrEqualValue(end));
    final expRow = await expAgg.getSingle();
    final totalExpenses = expRow.read<double>(_db.expenses.amount.sum()) ?? 0.0;
    final netProfit = grossProfit - totalExpenses;

    return {
      'grossSales': totalGrossSales,
      'discount': totalDiscount,
      'tax': totalTax,
      'netSales': totalNetSales,
      'hpp': totalHpp,
      'grossProfit': grossProfit,
      'expenses': totalExpenses,
      'netProfit': netProfit,
      'salesReturns': totalSalesReturns,
    };
  }

  // Get Cashier Shift Reconciliation reports
  Future<List<Map<String, dynamic>>> getShiftReports() async {
    final sessions = await (_db.select(_db.cashierSessions)
          ..where((tbl) => tbl.status.equals('closed'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.closeTime, mode: OrderingMode.desc)]))
        .get();

    final List<Map<String, dynamic>> result = [];
    for (var s in sessions) {
      final user = await (_db.select(_db.users)
            ..where((tbl) => tbl.id.equals(s.userId)))
          .getSingleOrNull();

      final endTime = s.closeTime ?? DateTime.now();

      // Get all orders completed in this session
      final orders = await (_db.select(_db.orders)
            ..where((tbl) => tbl.cashierSessionId.equals(s.id) & tbl.status.equals('completed')))
          .get();

      double totalCash = 0.0;
      double totalQris = 0.0;
      double totalCard = 0.0;
      double totalTransfer = 0.0;

      if (orders.isNotEmpty) {
        final orderIds = orders.map((o) => o.id).toList();
        final payments = await (_db.select(_db.orderPayments)
              ..where((tbl) => tbl.orderId.isIn(orderIds)))
            .get();

        for (var p in payments) {
          if (p.paymentMethod == 'cash') {
            totalCash += p.amount;
          } else if (p.paymentMethod == 'qris') {
            totalQris += p.amount;
          } else if (p.paymentMethod == 'card') {
            totalCard += p.amount;
          } else if (p.paymentMethod == 'transfer') {
            totalTransfer += p.amount;
          }
        }
      }

      // Get Cash Debt Payments in this session
      final debtPayments = await (_db.select(_db.customerDebtPayments)
            ..where((tbl) => tbl.createdAt.isBetweenValues(s.openTime, endTime) & tbl.paymentMethod.equals('cash')))
          .get();
      final totalCashDebtPayments = debtPayments.fold(0.0, (sum, item) => sum + item.amountPaid);

      // Get Supplier Debt Payments in this session
      final supplierDebtPayments = await (_db.select(_db.supplierDebtPayments)
            ..where((tbl) => tbl.createdAt.isBetweenValues(s.openTime, endTime) & tbl.paymentMethod.equals('cash')))
          .get();
      final totalCashSupplierDebtPayments = supplierDebtPayments.fold(0.0, (sum, item) => sum + item.amountPaid);

      // Get Expenses in this session
      final expenses = await (_db.select(_db.expenses)
            ..where((tbl) => tbl.date.isBetweenValues(s.openTime, endTime)))
          .get();
      final totalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

      // Get Sales Returns in session
      final salesReturns = await (_db.select(_db.salesReturns)
            ..where((tbl) => tbl.createdAt.isBetweenValues(s.openTime, endTime) & tbl.refundMethod.equals('cash')))
          .get();
      final totalSalesReturns = salesReturns.fold(0.0, (sum, item) => sum + item.refundAmount);

      // Get Purchase Returns in session
      final purchaseReturns = await (_db.select(_db.purchaseReturns)
            ..where((tbl) => tbl.createdAt.isBetweenValues(s.openTime, endTime) & tbl.refundMethod.equals('cash')))
          .get();
      final totalPurchaseReturns = purchaseReturns.fold(0.0, (sum, item) => sum + item.refundAmount);

      result.add({
        'session': s,
        'cashierName': user?.name ?? 'Kasir Tidak Dikenal',
        'paymentDetails': {
          'cash': totalCash,
          'qris': totalQris,
          'card': totalCard,
          'transfer': totalTransfer,
        },
        'cashSources': {
          'opening': s.openingCash,
          'sales': totalCash,
          'debts': totalCashDebtPayments,
          'supplierDebts': totalCashSupplierDebtPayments,
          'expenses': totalExpenses,
          'salesReturns': totalSalesReturns,
          'purchaseReturns': totalPurchaseReturns,
        }
      });
    }

    return result;
  }

  // 1. Transaction Report (Laporan Transaksi)
  Future<List<Map<String, dynamic>>> getTransactionReport(DateTime start, DateTime end) async {
    final ordersList = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed'))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    if (ordersList.isEmpty) return [];

    final customerIds = ordersList.where((o) => o.customerId != null).map((o) => o.customerId!).toSet().toList();
    final orderIds = ordersList.map((o) => o.id).toList();

    final customers = customerIds.isEmpty ? [] : await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.isIn(customerIds)))
        .get();
    final customerMap = {for (var c in customers) c.id: c};

    final allPayments = await (_db.select(_db.orderPayments)
          ..where((tbl) => tbl.orderId.isIn(orderIds)))
        .get();
    final paymentsByOrder = <int, List<OrderPayment>>{};
    for (var p in allPayments) {
      paymentsByOrder.putIfAbsent(p.orderId, () => []).add(p);
    }

    final allItems = await (_db.select(_db.orderItems)
          ..where((tbl) => tbl.orderId.isIn(orderIds)))
        .get();
    final itemsByOrder = <int, List<OrderItem>>{};
    for (var item in allItems) {
      itemsByOrder.putIfAbsent(item.orderId, () => []).add(item);
    }

    final productIds = allItems.map((i) => i.productId).toSet().toList();
    final unitIds = allItems.map((i) => i.unitId).toSet().toList();
    final products = productIds.isEmpty ? [] : await (_db.select(_db.products)
          ..where((tbl) => tbl.id.isIn(productIds)))
        .get();
    final units = unitIds.isEmpty ? [] : await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.id.isIn(unitIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};
    final unitMap = {for (var u in units) u.id: u};

    return ordersList.map((order) {
      final customer = customerMap[order.customerId];
      final payments = paymentsByOrder[order.id] ?? [];
      final paymentMethods = payments.map((p) => p.paymentMethod).join(', ');
      final items = itemsByOrder[order.id] ?? [];

      final itemDetails = items.map((item) {
        return {
          'productName': productMap[item.productId]?.name ?? 'Produk Tidak Dikenal',
          'unitName': unitMap[item.unitId]?.name ?? '',
          'quantity': item.quantity,
          'price': item.price,
          'subtotal': item.subtotal,
        };
      }).toList();

      return {
        'order': order,
        'customerName': customer?.name ?? 'Umum',
        'paymentMethods': paymentMethods.isEmpty ? 'Tunai' : paymentMethods,
        'items': itemDetails,
      };
    }).toList();
  }

  // 2. Product Sales Report (Laporan Penjualan per Produk)
  Future<List<Map<String, dynamic>>> getProductSalesReport(DateTime start, DateTime end) async {
    final prodSalesOrders = await (_db.select(_db.orders)
        ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed'))
    ).get();
    final orderIds = prodSalesOrders.map((o) => o.id).toList();

    if (orderIds.isEmpty) return [];

    final items = await (_db.select(_db.orderItems)
          ..where((tbl) => tbl.orderId.isIn(orderIds)))
        .get();

    final uniqueProductIds = items.map((i) => i.productId).toSet().toList();
    final uniqueUnitIds = items.map((i) => i.unitId).toSet().toList();

    final products = uniqueProductIds.isEmpty ? [] : await (_db.select(_db.products)
          ..where((tbl) => tbl.id.isIn(uniqueProductIds)))
        .get();
    final units = uniqueUnitIds.isEmpty ? [] : await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.id.isIn(uniqueUnitIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};
    final unitMap = {for (var u in units) u.id: u};

    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in items) {
      final key = '${item.productId}_${item.unitId}';
      if (!productStats.containsKey(key)) {
        final cost = await getProductCostPrice(item.productId, item.unitId, item.price);

        productStats[key] = {
          'productName': productMap[item.productId]?.name ?? 'Produk Tidak Dikenal',
          'unitName': unitMap[item.unitId]?.name ?? '',
          'quantity': 0.0,
          'revenue': 0.0,
          'cost': cost,
          'profit': 0.0,
        };
      }

      final stats = productStats[key]!;
      final qty = item.quantity;
      final revenue = item.subtotal - item.discountAmount;
      final totalCost = qty * (stats['cost'] as double);
      final profit = revenue - totalCost;

      stats['quantity'] = (stats['quantity'] as double) + qty;
      stats['revenue'] = (stats['revenue'] as double) + revenue;
      stats['profit'] = (stats['profit'] as double) + profit;
    }

    final sortedList = productStats.values.toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    return sortedList;
  }

  // 3. Customer Sales Report (Laporan Penjualan per Pelanggan)
  Future<List<Map<String, dynamic>>> getCustomerSalesReport(DateTime start, DateTime end) async {
    final ordersList = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed')))
        .get();

    if (ordersList.isEmpty) return [];

    final custIds = ordersList.where((o) => o.customerId != null).map((o) => o.customerId!).toSet().toList();
    final customers = custIds.isEmpty ? [] : await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.isIn(custIds)))
        .get();
    final customerMap = {for (var c in customers) c.id: c.name};

    final Map<int?, Map<String, dynamic>> customerStats = {};
    for (var order in ordersList) {
      final custId = order.customerId;
      if (!customerStats.containsKey(custId)) {
        customerStats[custId] = {
          'customerId': custId,
          'customerName': customerMap[custId] ?? 'Pelanggan Umum',
          'transactionCount': 0,
          'totalSpent': 0.0,
        };
      }
      final stats = customerStats[custId]!;
      stats['transactionCount'] = (stats['transactionCount'] as int) + 1;
      stats['totalSpent'] = (stats['totalSpent'] as double) + order.grandTotal;
    }

    final sortedList = customerStats.values.toList()
      ..sort((a, b) => (b['totalSpent'] as double).compareTo(a['totalSpent'] as double));

    return sortedList;
  }

  // 4. Expenses Report (Laporan Biaya)
  Future<List<Expense>> getExpensesReport(DateTime start, DateTime end) async {
    return await (_db.select(_db.expenses)
          ..where((tbl) => tbl.date.isBiggerOrEqualValue(start) & tbl.date.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.date, mode: OrderingMode.desc)]))
        .get();
  }

  // 5. Purchase Transaction Report (Laporan Transaksi Pembelian)
  Future<List<Map<String, dynamic>>> getPurchaseReport(DateTime start, DateTime end) async {
    final purchasesList = await (_db.select(_db.purchases)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    if (purchasesList.isEmpty) return [];

    final supplierIds = purchasesList.map((p) => p.supplierId).toSet().toList();
    final suppliers = await (_db.select(_db.suppliers)
          ..where((tbl) => tbl.id.isIn(supplierIds)))
        .get();
    final supplierMap = {for (var s in suppliers) s.id: s.name};

    return purchasesList.map((p) {
      return {
        'purchase': p,
        'supplierName': supplierMap[p.supplierId] ?? 'Tanpa Supplier',
      };
    }).toList();
  }

  // 6. Product Purchase Report (Laporan Pembelian per Produk)
  Future<List<Map<String, dynamic>>> getProductPurchaseReport(DateTime start, DateTime end) async {
    final prodPurchOrders = await (_db.select(_db.purchases)
        ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
    ).get();
    final purchaseIds = prodPurchOrders.map((p) => p.id).toList();

    if (purchaseIds.isEmpty) return [];

    final items = await (_db.select(_db.purchaseItems)
          ..where((tbl) => tbl.purchaseId.isIn(purchaseIds)))
        .get();

    final uniqueProductIds = items.map((i) => i.productId).toSet().toList();
    final uniqueUnitIds = items.map((i) => i.unitId).toSet().toList();

    final products = uniqueProductIds.isEmpty ? [] : await (_db.select(_db.products)
          ..where((tbl) => tbl.id.isIn(uniqueProductIds)))
        .get();
    final units = uniqueUnitIds.isEmpty ? [] : await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.id.isIn(uniqueUnitIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};
    final unitMap = {for (var u in units) u.id: u};

    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in items) {
      final key = '${item.productId}_${item.unitId}';
      if (!productStats.containsKey(key)) {
        productStats[key] = {
          'productName': productMap[item.productId]?.name ?? 'Produk Tidak Dikenal',
          'unitName': unitMap[item.unitId]?.name ?? '',
          'quantity': 0.0,
          'totalCost': 0.0,
        };
      }

      final stats = productStats[key]!;
      stats['quantity'] = (stats['quantity'] as double) + item.quantity;
      stats['totalCost'] = (stats['totalCost'] as double) + item.subtotal;
    }

    final sortedList = productStats.values.toList()
      ..sort((a, b) => (b['totalCost'] as double).compareTo(a['totalCost'] as double));

    return sortedList;
  }

  // Get Customer Debts (Piutang) Report with optional date range
  Future<List<Map<String, dynamic>>> getCustomerDebtsReport({DateTime? start, DateTime? end}) async {
    final query = _db.select(_db.customerDebts)
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);
    if (start != null) query.where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start));
    if (end != null) query.where((tbl) => tbl.createdAt.isSmallerOrEqualValue(end));

    final list = await query.get();
    if (list.isEmpty) return [];

    final customerIds = list.map((d) => d.customerId).toSet().toList();
    final orderIds = list.where((d) => d.orderId != null).map((d) => d.orderId!).toSet().toList();

    final customers = await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.isIn(customerIds)))
        .get();
    final orders = orderIds.isEmpty ? [] : await (_db.select(_db.orders)
          ..where((tbl) => tbl.id.isIn(orderIds)))
        .get();
    final customerMap = {for (var c in customers) c.id: c.name};
    final orderMap = {for (var o in orders) o.id: o.referenceNo};

    return list.map((debt) {
      return {
        'debt': debt,
        'customerName': customerMap[debt.customerId] ?? 'Pelanggan Umum',
        'referenceNo': debt.orderId != null ? (orderMap[debt.orderId] ?? '-') : '-',
      };
    }).toList();
  }

  // Get Supplier Debts (Hutang) Report with optional date range
  Future<List<Map<String, dynamic>>> getSupplierDebtsReport({DateTime? start, DateTime? end}) async {
    final query = _db.select(_db.supplierDebts)
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);
    if (start != null) query.where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start));
    if (end != null) query.where((tbl) => tbl.createdAt.isSmallerOrEqualValue(end));

    final list = await query.get();
    if (list.isEmpty) return [];

    final supplierIds = list.map((d) => d.supplierId).toSet().toList();
    final purchaseIds = list.where((d) => d.purchaseId != null).map((d) => d.purchaseId!).toSet().toList();

    final suppliers = await (_db.select(_db.suppliers)
          ..where((tbl) => tbl.id.isIn(supplierIds)))
        .get();
    final purchases = purchaseIds.isEmpty ? [] : await (_db.select(_db.purchases)
          ..where((tbl) => tbl.id.isIn(purchaseIds)))
        .get();
    final supplierMap = {for (var s in suppliers) s.id: s.name};
    final purchaseMap = {for (var p in purchases) p.id: p.referenceNo};

    return list.map((debt) {
      return {
        'debt': debt,
        'supplierName': supplierMap[debt.supplierId] ?? 'Supplier Umum',
        'referenceNo': debt.purchaseId != null ? (purchaseMap[debt.purchaseId] ?? '-') : '-',
      };
    }).toList();
  }

  // 8. Laporan Retur Penjualan (Customer Returns)
  Future<List<Map<String, dynamic>>> getSalesReturnReport(DateTime start, DateTime end) async {
    final returns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    if (returns.isEmpty) return [];

    final customerIds = returns.where((r) => r.customerId != null).map((r) => r.customerId!).toSet().toList();
    final orderIds = returns.where((r) => r.orderId != null).map((r) => r.orderId!).toSet().toList();
    final returnIds = returns.map((r) => r.id).toList();

    final customers = customerIds.isEmpty ? [] : await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.isIn(customerIds)))
        .get();
    final orders = orderIds.isEmpty ? [] : await (_db.select(_db.orders)
          ..where((tbl) => tbl.id.isIn(orderIds)))
        .get();
    final customerMap = {for (var c in customers) c.id: c};
    final orderMap = {for (var o in orders) o.id: o};

    final allItems = await (_db.select(_db.salesReturnItems)
          ..where((tbl) => tbl.salesReturnId.isIn(returnIds)))
        .get();
    final itemsByReturn = <int, List<SalesReturnItem>>{};
    for (var item in allItems) {
      itemsByReturn.putIfAbsent(item.salesReturnId, () => []).add(item);
    }

    final productIds = allItems.map((i) => i.productId).toSet().toList();
    final unitIds = allItems.map((i) => i.unitId).toSet().toList();
    final products = productIds.isEmpty ? [] : await (_db.select(_db.products)
          ..where((tbl) => tbl.id.isIn(productIds)))
        .get();
    final units = unitIds.isEmpty ? [] : await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.id.isIn(unitIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};
    final unitMap = {for (var u in units) u.id: u};

    return returns.map((r) {
      final items = itemsByReturn[r.id] ?? [];
      final itemDetails = items.map((item) {
        return {
          'item': item,
          'product': productMap[item.productId],
          'unit': unitMap[item.unitId],
        };
      }).toList();

      return {
        'return': r,
        'customer': customerMap[r.customerId],
        'order': orderMap[r.orderId],
        'items': itemDetails,
      };
    }).toList();
  }

  // 9. Laporan Retur Pembelian (Supplier Returns)
  Future<List<Map<String, dynamic>>> getPurchaseReturnReport(DateTime start, DateTime end) async {
    final returns = await (_db.select(_db.purchaseReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    if (returns.isEmpty) return [];

    final supplierIds = returns.map((r) => r.supplierId).toSet().toList();
    final purchaseIds = returns.where((r) => r.purchaseId != null).map((r) => r.purchaseId!).toSet().toList();
    final returnIds = returns.map((r) => r.id).toList();

    final suppliers = await (_db.select(_db.suppliers)
          ..where((tbl) => tbl.id.isIn(supplierIds)))
        .get();
    final purchases = purchaseIds.isEmpty ? [] : await (_db.select(_db.purchases)
          ..where((tbl) => tbl.id.isIn(purchaseIds)))
        .get();
    final supplierMap = {for (var s in suppliers) s.id: s};
    final purchaseMap = {for (var o in purchases) o.id: o};

    final allItems = await (_db.select(_db.purchaseReturnItems)
          ..where((tbl) => tbl.purchaseReturnId.isIn(returnIds)))
        .get();
    final itemsByReturn = <int, List<PurchaseReturnItem>>{};
    for (var item in allItems) {
      itemsByReturn.putIfAbsent(item.purchaseReturnId, () => []).add(item);
    }

    final productIds = allItems.map((i) => i.productId).toSet().toList();
    final unitIds = allItems.map((i) => i.unitId).toSet().toList();
    final products = productIds.isEmpty ? [] : await (_db.select(_db.products)
          ..where((tbl) => tbl.id.isIn(productIds)))
        .get();
    final units = unitIds.isEmpty ? [] : await (_db.select(_db.productUnits)
          ..where((tbl) => tbl.id.isIn(unitIds)))
        .get();
    final productMap = {for (var p in products) p.id: p};
    final unitMap = {for (var u in units) u.id: u};

    return returns.map((r) {
      final items = itemsByReturn[r.id] ?? [];
      final itemDetails = items.map((item) {
        return {
          'item': item,
          'product': productMap[item.productId],
          'unit': unitMap[item.unitId],
        };
      }).toList();

      return {
        'return': r,
        'supplier': supplierMap[r.supplierId],
        'purchase': purchaseMap[r.purchaseId],
        'items': itemDetails,
      };
    }).toList();
  }

  // 10. Laporan Analisis Produk (Terlaris & Tidak Laku)
  Future<Map<String, List<Map<String, dynamic>>>> getProductAnalysisReport(DateTime start, DateTime end) async {
    final orders = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed')))
        .get();

    final Map<int, double> productBaseQuantities = {};
    final Map<int, double> productRevenues = {};

    final allUnits = await _db.select(_db.productUnits).get();
    final unitMap = {for (var u in allUnits) u.id: u};

    if (orders.isNotEmpty) {
      final orderIds = orders.map((o) => o.id).toList();
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.isIn(orderIds)))
          .get();

      for (var item in items) {
        final unit = unitMap[item.unitId];
        final factor = unit?.conversionFactor ?? 1.0;
        final baseQty = item.quantity * factor;
        productBaseQuantities[item.productId] = (productBaseQuantities[item.productId] ?? 0.0) + baseQty;
        productRevenues[item.productId] = (productRevenues[item.productId] ?? 0.0) + (item.subtotal - item.discountAmount);
      }
    }

    final activeProducts = await (_db.select(_db.products)..where((tbl) => tbl.isActive.equals(true))).get();
    if (activeProducts.isEmpty) return {'bestSellers': [], 'slowSellers': []};

    final activeProductIds = activeProducts.map((p) => p.id).toList();
    final productUnitsByProduct = <int, List<ProductUnit>>{};
    for (var u in allUnits.where((u) => activeProductIds.contains(u.productId))) {
      productUnitsByProduct.putIfAbsent(u.productId, () => []).add(u);
    }

    final allInventory = await (_db.select(_db.inventory)
          ..where((tbl) => tbl.productId.isIn(activeProductIds)))
        .get();
    final invMap = <String, double>{};
    for (var inv in allInventory) {
      invMap['${inv.productId}_${inv.unitId}'] = inv.quantity;
    }

    final List<Map<String, dynamic>> bestSellers = [];
    final List<Map<String, dynamic>> slowSellers = [];

    for (var prod in activeProducts) {
      final productUnits = productUnitsByProduct[prod.id] ?? [];
      final baseUnit = productUnits.firstWhere(
        (u) => u.isBase,
        orElse: () => productUnits.isNotEmpty ? productUnits.first : ProductUnit(id: 0, productId: prod.id, name: 'Pcs', conversionFactor: 1.0, isBase: true),
      );

      final qtySold = productBaseQuantities[prod.id] ?? 0.0;
      final revenue = productRevenues[prod.id] ?? 0.0;

      double totalBaseStock = 0.0;
      for (var unit in productUnits) {
        final stock = invMap['${prod.id}_${unit.id}'] ?? 0.0;
        totalBaseStock += stock * unit.conversionFactor;
      }

      final dataMap = {
        'product': prod,
        'unit': baseUnit,
        'quantity': qtySold,
        'revenue': revenue,
        'currentStock': totalBaseStock,
      };

      if (qtySold > 0) {
        bestSellers.add(dataMap);
      } else {
        slowSellers.add(dataMap);
      }
    }

    bestSellers.sort((a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double));

    return {
      'bestSellers': bestSellers,
      'slowSellers': slowSellers,
    };
  }

  // 11. Points Report (Laporan Poin Pelanggan)
  Future<Map<String, dynamic>> getPointsReport(DateTime start, DateTime end) async {
    final transactions = await (_db.select(_db.pointTransactions)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    if (transactions.isEmpty) {
      return {
        'totalEarned': 0,
        'totalRedeemed': 0,
        'netPoints': 0,
        'transactionCount': 0,
        'details': [],
      };
    }

    int totalEarned = 0;
    int totalRedeemed = 0;

    final customerIds = transactions.map((t) => t.customerId).toSet().toList();
    final customers = await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.isIn(customerIds)))
        .get();
    final customerMap = {for (var c in customers) c.id: c.name};

    final details = transactions.map((txn) {
      if (txn.type == 'earn') totalEarned += txn.points;
      if (txn.type == 'redeem') totalRedeemed += txn.points.abs();

      return {
        'transaction': txn,
        'customerName': customerMap[txn.customerId] ?? 'Pelanggan Tidak Dikenal',
      };
    }).toList();

    return {
      'totalEarned': totalEarned,
      'totalRedeemed': totalRedeemed,
      'netPoints': totalEarned - totalRedeemed,
      'transactionCount': transactions.length,
      'details': details,
    };
  }
}
