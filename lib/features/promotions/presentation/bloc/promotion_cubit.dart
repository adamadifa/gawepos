import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../pos/presentation/bloc/cart_cubit.dart';
import '../../data/promotion_repository.dart';

enum PromotionStatus { initial, loading, loaded, error }

class PromotionState {
  final PromotionStatus status;
  final List<Promotion> promotions;
  final List<Promotion> activePromotions;
  final String? errorMessage;

  const PromotionState({
    this.status = PromotionStatus.initial,
    this.promotions = const [],
    this.activePromotions = const [],
    this.errorMessage,
  });

  PromotionState copyWith({
    PromotionStatus? status,
    List<Promotion>? promotions,
    List<Promotion>? activePromotions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PromotionState(
      status: status ?? this.status,
      promotions: promotions ?? this.promotions,
      activePromotions: activePromotions ?? this.activePromotions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PromotionCubit extends Cubit<PromotionState> {
  final PromotionRepository _repository;

  PromotionCubit(this._repository) : super(const PromotionState());

  // Memuat semua promosi
  Future<void> loadPromotions() async {
    emit(state.copyWith(status: PromotionStatus.loading, clearError: true));
    try {
      final all = await _repository.getAllPromotions();
      final active = await _repository.getActivePromotions();
      try {
        if (getIt.isRegistered<CartCubit>()) {
          getIt<CartCubit>().setActivePromotions(active);
        }
      } catch (_) {}
      emit(state.copyWith(
        status: PromotionStatus.loaded,
        promotions: all,
        activePromotions: active,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PromotionStatus.error,
        errorMessage: 'Gagal memuat daftar promosi: $e',
      ));
    }
  }

  // Tambah promosi baru
  Future<bool> createPromotion(PromotionsCompanion companion) async {
    try {
      await _repository.insertPromotion(companion);
      await loadPromotions();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: PromotionStatus.error,
        errorMessage: 'Gagal membuat promosi: $e',
      ));
      return false;
    }
  }

  // Update promosi
  Future<bool> updatePromotion(PromotionsCompanion companion) async {
    try {
      await _repository.updatePromotion(companion);
      await loadPromotions();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: PromotionStatus.error,
        errorMessage: 'Gagal mengupdate promosi: $e',
      ));
      return false;
    }
  }

  // Toggle status aktif
  Future<void> toggleActive(int id, bool isActive) async {
    try {
      await _repository.togglePromotionActive(id, isActive);
      await loadPromotions();
    } catch (e) {
      emit(state.copyWith(
        status: PromotionStatus.error,
        errorMessage: 'Gagal mengubah status promosi: $e',
      ));
    }
  }

  // Hapus promosi
  Future<bool> deletePromotion(int id) async {
    try {
      await _repository.deletePromotion(id);
      await loadPromotions();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: PromotionStatus.error,
        errorMessage: 'Gagal menghapus promosi: $e',
      ));
      return false;
    }
  }
}
