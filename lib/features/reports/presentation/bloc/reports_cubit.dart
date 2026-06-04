import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/reports_repository.dart';

class ReportsState {
  final Map<String, dynamic>? dashboardData;
  final Map<String, dynamic>? pnlData;
  final List<Map<String, dynamic>>? shiftsData;

  final bool isDashboardLoading;
  final bool isPnLLoading;
  final bool isShiftsLoading;

  final String? dashboardError;
  final String? pnlError;
  final String? shiftsError;

  ReportsState({
    this.dashboardData,
    this.pnlData,
    this.shiftsData,
    this.isDashboardLoading = false,
    this.isPnLLoading = false,
    this.isShiftsLoading = false,
    this.dashboardError,
    this.pnlError,
    this.shiftsError,
  });

  ReportsState copyWith({
    Map<String, dynamic>? dashboardData,
    Map<String, dynamic>? pnlData,
    List<Map<String, dynamic>>? shiftsData,
    bool? isDashboardLoading,
    bool? isPnLLoading,
    bool? isShiftsLoading,
    String? dashboardError,
    String? pnlError,
    String? shiftsError,
    bool clearDashboardError = false,
    bool clearPnLError = false,
    bool clearShiftsError = false,
  }) {
    return ReportsState(
      dashboardData: dashboardData ?? this.dashboardData,
      pnlData: pnlData ?? this.pnlData,
      shiftsData: shiftsData ?? this.shiftsData,
      isDashboardLoading: isDashboardLoading ?? this.isDashboardLoading,
      isPnLLoading: isPnLLoading ?? this.isPnLLoading,
      isShiftsLoading: isShiftsLoading ?? this.isShiftsLoading,
      dashboardError: clearDashboardError ? null : (dashboardError ?? this.dashboardError),
      pnlError: clearPnLError ? null : (pnlError ?? this.pnlError),
      shiftsError: clearShiftsError ? null : (shiftsError ?? this.shiftsError),
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
}
