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

      final total = daysOrders.fold<double>(0.0, (sum, o) => sum + o.grandTotal);
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

      result.add({
        'session': s,
        'cashierName': user?.name ?? 'Kasir Tidak Dikenal',
      });
    }

    return result;
  }
}
