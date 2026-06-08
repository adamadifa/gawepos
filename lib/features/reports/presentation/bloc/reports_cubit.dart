import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/reports_repository.dart';

class ReportsState {
  final Map<String, dynamic>? dashboardData;
  final Map<String, dynamic>? pnlData;
  final List<Map<String, dynamic>>? shiftsData;
  
  // New sales report fields
  final List<Map<String, dynamic>>? transactionsData;
  final List<Map<String, dynamic>>? productSalesData;
  final List<Map<String, dynamic>>? customerSalesData;

  // New purchase report fields
  final List<Map<String, dynamic>>? purchaseTransactionsData;
  final List<Map<String, dynamic>>? productPurchasesData;

  // New expense report fields
  final List<Expense>? expensesData;

  // New return report fields
  final List<Map<String, dynamic>>? salesReturnsReportData;
  final List<Map<String, dynamic>>? purchaseReturnsReportData;

  // New product analysis fields
  final Map<String, List<Map<String, dynamic>>>? productAnalysisData;

  final bool isDashboardLoading;
  final bool isPnLLoading;
  final bool isShiftsLoading;
  final bool isSalesLoading;
  final bool isExpensesLoading;
  final bool isPurchasesLoading;
  final bool isReturnsLoading;
  final bool isProductAnalysisLoading;

  final String? dashboardError;
  final String? pnlError;
  final String? shiftsError;
  final String? salesError;
  final String? expensesError;
  final String? purchasesError;
  final String? returnsError;
  final String? productAnalysisError;

  ReportsState({
    this.dashboardData,
    this.pnlData,
    this.shiftsData,
    this.transactionsData,
    this.productSalesData,
    this.customerSalesData,
    this.purchaseTransactionsData,
    this.productPurchasesData,
    this.expensesData,
    this.salesReturnsReportData,
    this.purchaseReturnsReportData,
    this.productAnalysisData,
    this.isDashboardLoading = false,
    this.isPnLLoading = false,
    this.isShiftsLoading = false,
    this.isSalesLoading = false,
    this.isExpensesLoading = false,
    this.isPurchasesLoading = false,
    this.isReturnsLoading = false,
    this.isProductAnalysisLoading = false,
    this.dashboardError,
    this.pnlError,
    this.shiftsError,
    this.salesError,
    this.expensesError,
    this.purchasesError,
    this.returnsError,
    this.productAnalysisError,
  });

  ReportsState copyWith({
    Map<String, dynamic>? dashboardData,
    Map<String, dynamic>? pnlData,
    List<Map<String, dynamic>>? shiftsData,
    List<Map<String, dynamic>>? transactionsData,
    List<Map<String, dynamic>>? productSalesData,
    List<Map<String, dynamic>>? customerSalesData,
    List<Map<String, dynamic>>? purchaseTransactionsData,
    List<Map<String, dynamic>>? productPurchasesData,
    List<Expense>? expensesData,
    List<Map<String, dynamic>>? salesReturnsReportData,
    List<Map<String, dynamic>>? purchaseReturnsReportData,
    Map<String, List<Map<String, dynamic>>>? productAnalysisData,
    bool? isDashboardLoading,
    bool? isPnLLoading,
    bool? isShiftsLoading,
    bool? isSalesLoading,
    bool? isExpensesLoading,
    bool? isPurchasesLoading,
    bool? isReturnsLoading,
    bool? isProductAnalysisLoading,
    String? dashboardError,
    String? pnlError,
    String? shiftsError,
    String? salesError,
    String? expensesError,
    String? purchasesError,
    String? returnsError,
    String? productAnalysisError,
    bool clearDashboardError = false,
    bool clearPnLError = false,
    bool clearShiftsError = false,
    bool clearSalesError = false,
    bool clearExpensesError = false,
    bool clearPurchasesError = false,
    bool clearReturnsError = false,
    bool clearProductAnalysisError = false,
  }) {
    return ReportsState(
      dashboardData: dashboardData ?? this.dashboardData,
      pnlData: pnlData ?? this.pnlData,
      shiftsData: shiftsData ?? this.shiftsData,
      transactionsData: transactionsData ?? this.transactionsData,
      productSalesData: productSalesData ?? this.productSalesData,
      customerSalesData: customerSalesData ?? this.customerSalesData,
      purchaseTransactionsData: purchaseTransactionsData ?? this.purchaseTransactionsData,
      productPurchasesData: productPurchasesData ?? this.productPurchasesData,
      expensesData: expensesData ?? this.expensesData,
      salesReturnsReportData: salesReturnsReportData ?? this.salesReturnsReportData,
      purchaseReturnsReportData: purchaseReturnsReportData ?? this.purchaseReturnsReportData,
      productAnalysisData: productAnalysisData ?? this.productAnalysisData,
      isDashboardLoading: isDashboardLoading ?? this.isDashboardLoading ?? false,
      isPnLLoading: isPnLLoading ?? this.isPnLLoading ?? false,
      isShiftsLoading: isShiftsLoading ?? this.isShiftsLoading ?? false,
      isSalesLoading: isSalesLoading ?? this.isSalesLoading ?? false,
      isExpensesLoading: isExpensesLoading ?? this.isExpensesLoading ?? false,
      isPurchasesLoading: isPurchasesLoading ?? this.isPurchasesLoading ?? false,
      isReturnsLoading: isReturnsLoading ?? this.isReturnsLoading ?? false,
      isProductAnalysisLoading: isProductAnalysisLoading ?? this.isProductAnalysisLoading ?? false,
      dashboardError: clearDashboardError ? null : (dashboardError ?? this.dashboardError),
      pnlError: clearPnLError ? null : (pnlError ?? this.pnlError),
      shiftsError: clearShiftsError ? null : (shiftsError ?? this.shiftsError),
      salesError: clearSalesError ? null : (salesError ?? this.salesError),
      expensesError: clearExpensesError ? null : (expensesError ?? this.expensesError),
      purchasesError: clearPurchasesError ? null : (purchasesError ?? this.purchasesError),
      returnsError: clearReturnsError ? null : (returnsError ?? this.returnsError),
      productAnalysisError: clearProductAnalysisError ? null : (productAnalysisError ?? this.productAnalysisError),
    );
  }
}

class ReportsCubit extends Cubit<ReportsState> {
  final ReportsRepository _repository;

  ReportsCubit(this._repository) : super(ReportsState());

  Future<void> loadDashboard({DateTime? start, DateTime? end}) async {
    emit(state.copyWith(
      isDashboardLoading: true,
      clearDashboardError: true,
    ));
    try {
      final data = await _repository.getDashboardData(start: start, end: end);
      emit(state.copyWith(
        isDashboardLoading: false,
        dashboardData: data,
      ));
    } catch (e) {
      emit(state.copyWith(
        isDashboardLoading: false,
        dashboardError: 'Gagal memuat dashboard: $e',
      ));
    }
  }

  Future<void> loadPnL(DateTime start, DateTime end) async {
    emit(state.copyWith(
      isPnLLoading: true,
      clearPnLError: true,
    ));
    try {
      final pnl = await _repository.getPnLReport(start, end);
      emit(state.copyWith(
        isPnLLoading: false,
        pnlData: pnl,
      ));
    } catch (e) {
      emit(state.copyWith(
        isPnLLoading: false,
        pnlError: 'Gagal memuat laporan laba rugi: $e',
      ));
    }
  }

  Future<void> loadShifts() async {
    emit(state.copyWith(
      isShiftsLoading: true,
      clearShiftsError: true,
    ));
    try {
      final shifts = await _repository.getShiftReports();
      emit(state.copyWith(
        isShiftsLoading: false,
        shiftsData: shifts,
      ));
    } catch (e) {
      emit(state.copyWith(
        isShiftsLoading: false,
        shiftsError: 'Gagal memuat laporan shift kasir: $e',
      ));
    }
  }

  Future<void> loadSalesReports(DateTime start, DateTime end) async {
    emit(state.copyWith(
      isSalesLoading: true,
      clearSalesError: true,
    ));
    try {
      final tx = await _repository.getTransactionReport(start, end);
      final prod = await _repository.getProductSalesReport(start, end);
      final cust = await _repository.getCustomerSalesReport(start, end);
      emit(state.copyWith(
        isSalesLoading: false,
        transactionsData: tx,
        productSalesData: prod,
        customerSalesData: cust,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSalesLoading: false,
        salesError: 'Gagal memuat laporan penjualan: $e',
      ));
    }
  }

  Future<void> loadExpensesReport(DateTime start, DateTime end) async {
    emit(state.copyWith(
      isExpensesLoading: true,
      clearExpensesError: true,
    ));
    try {
      final expenses = await _repository.getExpensesReport(start, end);
      emit(state.copyWith(
        isExpensesLoading: false,
        expensesData: expenses,
      ));
    } catch (e) {
      emit(state.copyWith(
        isExpensesLoading: false,
        expensesError: 'Gagal memuat laporan biaya: $e',
      ));
    }
  }

  Future<void> loadPurchasesReports(DateTime start, DateTime end) async {
    emit(state.copyWith(
      isPurchasesLoading: true,
      clearPurchasesError: true,
    ));
    try {
      final tx = await _repository.getPurchaseReport(start, end);
      final prod = await _repository.getProductPurchaseReport(start, end);
      emit(state.copyWith(
        isPurchasesLoading: false,
        purchaseTransactionsData: tx,
        productPurchasesData: prod,
      ));
    } catch (e) {
      emit(state.copyWith(
        isPurchasesLoading: false,
        purchasesError: 'Gagal memuat laporan pembelian: $e',
      ));
    }
  }

  Future<void> loadReturnsReport(DateTime start, DateTime end) async {
    emit(state.copyWith(
      isReturnsLoading: true,
      clearReturnsError: true,
    ));
    try {
      final sales = await _repository.getSalesReturnReport(start, end);
      final purchases = await _repository.getPurchaseReturnReport(start, end);
      emit(state.copyWith(
        isReturnsLoading: false,
        salesReturnsReportData: sales,
        purchaseReturnsReportData: purchases,
      ));
    } catch (e) {
      emit(state.copyWith(
        isReturnsLoading: false,
        returnsError: 'Gagal memuat laporan retur: $e',
      ));
    }
  }

  Future<void> loadProductAnalysisReport(DateTime start, DateTime end) async {
    emit(state.copyWith(
      isProductAnalysisLoading: true,
      clearProductAnalysisError: true,
    ));
    try {
      final data = await _repository.getProductAnalysisReport(start, end);
      emit(state.copyWith(
        isProductAnalysisLoading: false,
        productAnalysisData: data,
      ));
    } catch (e) {
      emit(state.copyWith(
        isProductAnalysisLoading: false,
        productAnalysisError: 'Gagal memuat analisis produk: $e',
      ));
    }
  }
}
