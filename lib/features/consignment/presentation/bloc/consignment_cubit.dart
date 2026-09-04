import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/consignment_repository.dart';

// States
abstract class ConsignmentState {}

class ConsignmentInitial extends ConsignmentState {}

class ConsignmentLoading extends ConsignmentState {}

class ConsignmentOverviewLoaded extends ConsignmentState {
  final List<ConsignmentSupplierSummary> summaries;
  final List<Map<String, dynamic>> settlements;
  final List<Map<String, dynamic>> stockReport;

  ConsignmentOverviewLoaded({
    required this.summaries,
    required this.settlements,
    required this.stockReport,
  });

  double get totalUnsettledPayable =>
      summaries.fold<double>(0.0, (sum, s) => sum + s.unsettledSupplierPayable);

  double get totalStoreCommission =>
      summaries.fold<double>(0.0, (sum, s) => sum + s.unsettledStoreCommission);

  int get totalActiveSuppliers => summaries.length;
}

class ConsignmentUnsettledCalculated extends ConsignmentState {
  final int supplierId;
  final List<ConsignmentUnsettledItem> items;
  final DateTime startDate;
  final DateTime endDate;

  ConsignmentUnsettledCalculated({
    required this.supplierId,
    required this.items,
    required this.startDate,
    required this.endDate,
  });

  double get totalSales => items.fold<double>(0.0, (sum, i) => sum + i.totalSalesAmount);
  double get totalPayable => items.fold<double>(0.0, (sum, i) => sum + i.supplierPayable);
  double get totalCommission => items.fold<double>(0.0, (sum, i) => sum + i.storeCommission);
  double get totalSoldQty => items.fold<double>(0.0, (sum, i) => sum + i.soldQty);
}

class ConsignmentError extends ConsignmentState {
  final String message;
  ConsignmentError(this.message);
}

// Cubit
class ConsignmentCubit extends Cubit<ConsignmentState> {
  final ConsignmentRepository _repository;

  ConsignmentCubit(this._repository) : super(ConsignmentInitial());

  Future<void> loadOverview() async {
    emit(ConsignmentLoading());
    try {
      final summaries = await _repository.getConsignmentSuppliersSummary();
      final settlements = await _repository.getSettlements();
      final stockReport = await _repository.getConsignmentStockReport();

      emit(ConsignmentOverviewLoaded(
        summaries: summaries,
        settlements: settlements,
        stockReport: stockReport,
      ));
    } catch (e) {
      emit(ConsignmentError('Gagal memuat data konsinyasi: $e'));
    }
  }

  Future<void> calculateUnsettled({
    required int supplierId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    emit(ConsignmentLoading());
    try {
      final sDate = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final eDate = endDate ?? DateTime.now();

      final items = await _repository.getUnsettledItemsForSupplier(
        supplierId,
        startDate: sDate,
        endDate: eDate,
      );

      emit(ConsignmentUnsettledCalculated(
        supplierId: supplierId,
        items: items,
        startDate: sDate,
        endDate: eDate,
      ));
    } catch (e) {
      emit(ConsignmentError('Gagal mengkalkulasi barang konsinyasi: $e'));
    }
  }

  Future<bool> createSettlement({
    required int supplierId,
    required DateTime startDate,
    required DateTime endDate,
    required List<ConsignmentUnsettledItem> items,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      await _repository.createSettlement(
        supplierId: supplierId,
        startDate: startDate,
        endDate: endDate,
        items: items,
        paidAmount: paidAmount,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      await loadOverview();
      return true;
    } catch (e) {
      emit(ConsignmentError('Gagal membuat nota settlement: $e'));
      return false;
    }
  }

  Future<bool> paySettlement({
    required int settlementId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      final success = await _repository.paySettlement(settlementId, amount, paymentMethod);
      if (success) {
        await loadOverview();
      }
      return success;
    } catch (e) {
      emit(ConsignmentError('Gagal mencatat pembayaran: $e'));
      return false;
    }
  }
}
