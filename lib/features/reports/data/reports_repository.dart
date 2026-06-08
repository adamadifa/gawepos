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

    // Fetch Today's Orders
    final todayOrders = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startOfDay) & tbl.createdAt.isSmallerOrEqualValue(endOfDay) & tbl.status.equals('completed')))
        .get();

    double totalGrossSales = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double totalNetSales = 0.0;
    double totalHpp = 0.0;

    for (var order in todayOrders) {
      totalGrossSales += order.subtotal;
      totalDiscount += order.discountAmount;
      totalTax += order.taxAmount;
      totalNetSales += order.grandTotal;

      // Calculate HPP for this order
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.equals(order.id)))
          .get();

      for (var item in items) {
        final cost = await getProductCostPrice(item.productId, item.unitId, item.price);
        totalHpp += (item.quantity * cost);
      }
    }

    // Fetch Today's Sales Returns
    final todaySalesReturns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(startOfDay) & tbl.createdAt.isSmallerOrEqualValue(endOfDay)))
        .get();
    double totalSalesReturns = 0.0;
    double totalReturnedHpp = 0.0;
    for (var ret in todaySalesReturns) {
      totalSalesReturns += ret.refundAmount;
      final retItems = await (_db.select(_db.salesReturnItems)
            ..where((tbl) => tbl.salesReturnId.equals(ret.id)))
          .get();
      for (var item in retItems) {
        final cost = await getProductCostPrice(item.productId, item.unitId, item.price);
        totalReturnedHpp += (item.quantity * cost);
      }
    }

    totalNetSales = totalNetSales - totalSalesReturns;
    totalHpp = totalHpp - totalReturnedHpp;

    final grossProfit = totalNetSales - totalHpp;

    // Fetch Today's Expenses
    final todayExpenses = await (_db.select(_db.expenses)
          ..where((tbl) => tbl.date.isBiggerOrEqualValue(startOfDay) & tbl.date.isSmallerOrEqualValue(endOfDay)))
        .get();

    double totalExpenses = todayExpenses.fold(0.0, (sum, exp) => sum + exp.amount);
    final netProfit = grossProfit - totalExpenses;

    // Last 7 days trend
    final List<Map<String, dynamic>> trendData = [];
    for (int i = 6; i >= 0; i--) {
      final targetDate = now.subtract(Duration(days: i));
      final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      final daysOrders = await (_db.select(_db.orders)
            ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed')))
          .get();

      final daysReturns = await (_db.select(_db.salesReturns)
            ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end)))
          .get();

      final totalSales = daysOrders.fold<double>(0.0, (sum, o) => sum + o.grandTotal);
      final totalReturns = daysReturns.fold<double>(0.0, (sum, r) => sum + r.refundAmount);
      final total = (totalSales - totalReturns).clamp(0.0, double.infinity);

      trendData.add({
        'day': '${targetDate.day}/${targetDate.month}',
        'amount': total,
      });
    }

    // Best Sellers Today (Top 5)
    // Gather all today's items
    final Map<int, double> productQtyMap = {};
    for (var order in todayOrders) {
      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.equals(order.id)))
          .get();
      for (var item in items) {
        productQtyMap[item.productId] = (productQtyMap[item.productId] ?? 0) + item.quantity;
      }
    }

    final List<Map<String, dynamic>> bestSellers = [];
    final sortedProductIds = productQtyMap.keys.toList()
      ..sort((a, b) => productQtyMap[b]!.compareTo(productQtyMap[a]!));

    final top5 = sortedProductIds.take(5);
    for (var prodId in top5) {
      final prod = await (_db.select(_db.products)
            ..where((tbl) => tbl.id.equals(prodId)))
          .getSingleOrNull();
      if (prod != null) {
        bestSellers.add({
          'name': prod.name,
          'qty': productQtyMap[prodId],
        });
      }
    }

    // Low Stock Alert
    final List<Map<String, dynamic>> lowStockAlerts = [];
    final activeProducts = await (_db.select(_db.products)
          ..where((tbl) => tbl.isStockManaged.equals(true) & tbl.isActive.equals(true)))
        .get();

    for (var p in activeProducts) {
      // Get stock units
      final units = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.productId.equals(p.id)))
          .get();

      for (var u in units) {
        final inv = await (_db.select(_db.inventory)
              ..where((tbl) => tbl.productId.equals(p.id) & tbl.unitId.equals(u.id)))
            .getSingleOrNull();

        final currentQty = inv?.quantity ?? 0.0;
        // Check alert using base unit or general check (conversion factor conversion could be done,
        // but checking unit stock relative to minStockAlert is standard)
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

    return {
      'grossSales': totalGrossSales,
      'discount': totalDiscount,
      'tax': totalTax,
      'netSales': totalNetSales,
      'hpp': totalHpp,
      'grossProfit': grossProfit,
      'expenses': totalExpenses,
      'netProfit': netProfit,
      'transactionCount': todayOrders.length,
      'trend': trendData,
      'bestSellers': bestSellers,
      'lowStock': lowStockAlerts,
    };
  }

  // Get Custom range Laba Rugi Report
  Future<Map<String, dynamic>> getPnLReport(DateTime start, DateTime end) async {
    final orders = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed')))
        .get();

    double totalGrossSales = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double totalNetSales = 0.0;
    double totalHpp = 0.0;

    for (var order in orders) {
      totalGrossSales += order.subtotal;
      totalDiscount += order.discountAmount;
      totalTax += order.taxAmount;
      totalNetSales += order.grandTotal;

      final items = await (_db.select(_db.orderItems)
            ..where((tbl) => tbl.orderId.equals(order.id)))
          .get();

      for (var item in items) {
        final cost = await getProductCostPrice(item.productId, item.unitId, item.price);
        totalHpp += (item.quantity * cost);
      }
    }

    // Fetch Sales Returns
    final periodSalesReturns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end)))
        .get();
    double totalSalesReturns = 0.0;
    double totalReturnedHpp = 0.0;
    for (var ret in periodSalesReturns) {
      totalSalesReturns += ret.refundAmount;
      final retItems = await (_db.select(_db.salesReturnItems)
            ..where((tbl) => tbl.salesReturnId.equals(ret.id)))
          .get();
      for (var item in retItems) {
        final cost = await getProductCostPrice(item.productId, item.unitId, item.price);
        totalReturnedHpp += (item.quantity * cost);
      }
    }

    totalNetSales = totalNetSales - totalSalesReturns;
    totalHpp = totalHpp - totalReturnedHpp;

    final grossProfit = totalNetSales - totalHpp;

    final expenses = await (_db.select(_db.expenses)
          ..where((tbl) => tbl.date.isBiggerOrEqualValue(start) & tbl.date.isSmallerOrEqualValue(end)))
        .get();

    double totalExpenses = expenses.fold(0.0, (sum, exp) => sum + exp.amount);
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
    final query = _db.select(_db.orders)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed'))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);

    final ordersList = await query.get();
    final List<Map<String, dynamic>> report = [];

    for (var order in ordersList) {
      final customer = order.customerId != null
          ? await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(order.customerId!))).getSingleOrNull()
          : null;

      final payments = await (_db.select(_db.orderPayments)..where((tbl) => tbl.orderId.equals(order.id))).get();
      final paymentMethods = payments.map((p) => p.paymentMethod).join(', ');

      report.add({
        'order': order,
        'customerName': customer?.name ?? 'Umum',
        'paymentMethods': paymentMethods.isEmpty ? 'Tunai' : paymentMethods,
      });
    }
    return report;
  }

  // 2. Product Sales Report (Laporan Penjualan per Produk)
  Future<List<Map<String, dynamic>>> getProductSalesReport(DateTime start, DateTime end) async {
    final ordersList = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed')))
        .get();

    if (ordersList.isEmpty) return [];

    final orderIds = ordersList.map((o) => o.id).toList();

    final items = await (_db.select(_db.orderItems)
          ..where((tbl) => tbl.orderId.isIn(orderIds)))
        .get();

    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in items) {
      final key = '${item.productId}_${item.unitId}';
      if (!productStats.containsKey(key)) {
        final prod = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
        final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();
        final cost = await getProductCostPrice(item.productId, item.unitId, item.price);

        productStats[key] = {
          'productName': prod?.name ?? 'Produk Tidak Dikenal',
          'unitName': unit?.name ?? '',
          'quantity': 0.0,
          'revenue': 0.0,
          'cost': cost,
          'profit': 0.0,
        };
      }

      final stats = productStats[key]!;
      final qty = item.quantity;
      final revenue = item.subtotal - item.discountAmount; // net item revenue
      final totalCost = qty * stats['cost'];
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

    final Map<int?, Map<String, dynamic>> customerStats = {};

    for (var order in ordersList) {
      final custId = order.customerId;
      if (!customerStats.containsKey(custId)) {
        String name = 'Pelanggan Umum';
        if (custId != null) {
          final cust = await (_db.select(_db.customers)..where((tbl) => tbl.id.equals(custId))).getSingleOrNull();
          if (cust != null) name = cust.name;
        }

        customerStats[custId] = {
          'customerId': custId,
          'customerName': name,
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
    final query = _db.select(_db.purchases)
      ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);

    final purchasesList = await query.get();
    final List<Map<String, dynamic>> report = [];

    for (var p in purchasesList) {
      final supplier = p.supplierId != null
          ? await (_db.select(_db.suppliers)..where((tbl) => tbl.id.equals(p.supplierId!))).getSingleOrNull()
          : null;

      report.add({
        'purchase': p,
        'supplierName': supplier?.name ?? 'Tanpa Supplier',
      });
    }
    return report;
  }

  // 6. Product Purchase Report (Laporan Pembelian per Produk)
  Future<List<Map<String, dynamic>>> getProductPurchaseReport(DateTime start, DateTime end) async {
    final purchasesList = await (_db.select(_db.purchases)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end)))
        .get();

    if (purchasesList.isEmpty) return [];
    final purchaseIds = purchasesList.map((p) => p.id).toList();

    final items = await (_db.select(_db.purchaseItems)
          ..where((tbl) => tbl.purchaseId.isIn(purchaseIds)))
        .get();

    final Map<String, Map<String, dynamic>> productStats = {};

    for (var item in items) {
      final key = '${item.productId}_${item.unitId}';
      if (!productStats.containsKey(key)) {
        final prod = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(item.productId))).getSingleOrNull();
        final unit = await (_db.select(_db.productUnits)..where((tbl) => tbl.id.equals(item.unitId))).getSingleOrNull();

        productStats[key] = {
          'productName': prod?.name ?? 'Produk Tidak Dikenal',
          'unitName': unit?.name ?? '',
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

    if (start != null) {
      query.where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where((tbl) => tbl.createdAt.isSmallerOrEqualValue(end));
    }

    final list = await query.get();
    final List<Map<String, dynamic>> results = [];

    for (var debt in list) {
      final customer = await (_db.select(_db.customers)
            ..where((tbl) => tbl.id.equals(debt.customerId)))
          .getSingleOrNull();

      Order? order;
      if (debt.orderId != null) {
        order = await (_db.select(_db.orders)
              ..where((tbl) => tbl.id.equals(debt.orderId!)))
            .getSingleOrNull();
      }

      results.add({
        'debt': debt,
        'customerName': customer?.name ?? 'Pelanggan Umum',
        'referenceNo': order?.referenceNo ?? '-',
      });
    }

    return results;
  }

  // Get Supplier Debts (Hutang) Report with optional date range
  Future<List<Map<String, dynamic>>> getSupplierDebtsReport({DateTime? start, DateTime? end}) async {
    final query = _db.select(_db.supplierDebts)
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]);

    if (start != null) {
      query.where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start));
    }
    if (end != null) {
      query.where((tbl) => tbl.createdAt.isSmallerOrEqualValue(end));
    }

    final list = await query.get();
    final List<Map<String, dynamic>> results = [];

    for (var debt in list) {
      final supplier = await (_db.select(_db.suppliers)
            ..where((tbl) => tbl.id.equals(debt.supplierId)))
          .getSingleOrNull();

      Purchase? purchase;
      if (debt.purchaseId != null) {
        purchase = await (_db.select(_db.purchases)
              ..where((tbl) => tbl.id.equals(debt.purchaseId!)))
            .getSingleOrNull();
      }

      results.add({
        'debt': debt,
        'supplierName': supplier?.name ?? 'Supplier Umum',
        'referenceNo': purchase?.referenceNo ?? '-',
      });
    }

    return results;
  }

  // 8. Laporan Retur Penjualan (Customer Returns)
  Future<List<Map<String, dynamic>>> getSalesReturnReport(DateTime start, DateTime end) async {
    final returns = await (_db.select(_db.salesReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
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

      final items = await (_db.select(_db.salesReturnItems)..where((tbl) => tbl.salesReturnId.equals(r.id))).get();
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

      results.add({
        'return': r,
        'customer': customer,
        'order': order,
        'items': itemDetails,
      });
    }
    return results;
  }

  // 9. Laporan Retur Pembelian (Supplier Returns)
  Future<List<Map<String, dynamic>>> getPurchaseReturnReport(DateTime start, DateTime end) async {
    final returns = await (_db.select(_db.purchaseReturns)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .get();

    final List<Map<String, dynamic>> results = [];
    for (var r in returns) {
      final supplier = await (_db.select(_db.suppliers)..where((tbl) => tbl.id.equals(r.supplierId))).getSingleOrNull();

      final purchase = r.purchaseId != null
          ? await (_db.select(_db.purchases)..where((tbl) => tbl.id.equals(r.purchaseId!))).getSingleOrNull()
          : null;

      final items = await (_db.select(_db.purchaseReturnItems)..where((tbl) => tbl.purchaseReturnId.equals(r.id))).get();
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

      results.add({
        'return': r,
        'supplier': supplier,
        'purchase': purchase,
        'items': itemDetails,
      });
    }
    return results;
  }

  // 10. Laporan Analisis Produk (Terlaris & Tidak Laku)
  Future<Map<String, List<Map<String, dynamic>>>> getProductAnalysisReport(DateTime start, DateTime end) async {
    final orders = await (_db.select(_db.orders)
          ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(start) & tbl.createdAt.isSmallerOrEqualValue(end) & tbl.status.equals('completed')))
        .get();

    final List<Map<String, dynamic>> bestSellers = [];
    final List<Map<String, dynamic>> slowSellers = [];

    final Map<int, double> productBaseQuantities = {};
    final Map<int, double> productRevenues = {};

    final allUnits = await _db.select(_db.productUnits).get();
    final Map<int, ProductUnit> unitMap = {for (var u in allUnits) u.id: u};

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
    
    for (var prod in activeProducts) {
      final productUnits = await (_db.select(_db.productUnits)..where((tbl) => tbl.productId.equals(prod.id))).get();
      final baseUnit = productUnits.firstWhere(
        (u) => u.isBase,
        orElse: () => productUnits.isNotEmpty ? productUnits.first : ProductUnit(id: 0, productId: prod.id, name: 'Pcs', conversionFactor: 1.0, isBase: true),
      );

      final qtySold = productBaseQuantities[prod.id] ?? 0.0;
      final revenue = productRevenues[prod.id] ?? 0.0;

      double totalBaseStock = 0.0;
      for (var unit in productUnits) {
        final inv = await (_db.select(_db.inventory)
              ..where((tbl) => tbl.productId.equals(prod.id) & tbl.unitId.equals(unit.id)))
            .getSingleOrNull();
        final stock = inv?.quantity ?? 0.0;
        totalBaseStock += stock * unit.conversionFactor;
      }

      final Map<String, dynamic> dataMap = {
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
}
