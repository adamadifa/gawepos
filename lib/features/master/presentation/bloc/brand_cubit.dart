import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/master_repository.dart';

abstract class BrandState {}
class BrandInitial extends BrandState {}
class BrandLoading extends BrandState {}
class BrandLoaded extends BrandState {
  final List<Brand> brands;
  BrandLoaded(this.brands);
}
class BrandSaved extends BrandState {
  final String brandName;
  final bool isEdit;
  BrandSaved({required this.brandName, this.isEdit = false});
}
class BrandDeleted extends BrandState {
  final String brandName;
  BrandDeleted({required this.brandName});
}
class BrandError extends BrandState {
  final String message;
  BrandError(this.message);
}

class BrandCubit extends Cubit<BrandState> {
  final MasterRepository _repository;

  BrandCubit(this._repository) : super(BrandInitial());

  Future<void> loadBrands() async {
    emit(BrandLoading());
    try {
      final brands = await _repository.getBrands();
      emit(BrandLoaded(brands));
    } catch (e) {
      emit(BrandError('Gagal memuat merek: $e'));
    }
  }

  Future<void> addBrand(String name) async {
    try {
      await _repository.insertBrand(
        BrandsCompanion.insert(name: name),
      );
      emit(BrandSaved(brandName: name, isEdit: false));
      await loadBrands();
    } catch (e) {
      emit(BrandError('Gagal menambah merek: $e'));
    }
  }

  Future<void> editBrand(Brand brand, String name) async {
    try {
      await _repository.updateBrand(
        brand.copyWith(name: name),
      );
      emit(BrandSaved(brandName: name, isEdit: true));
      await loadBrands();
    } catch (e) {
      emit(BrandError('Gagal mengubah merek: $e'));
    }
  }

  Future<void> deleteBrand(int id, {String brandName = ''}) async {
    try {
      await _repository.deleteBrand(id);
      emit(BrandDeleted(brandName: brandName));
      await loadBrands();
    } catch (e) {
      emit(BrandError('Gagal menghapus merek: $e'));
    }
  }
}
