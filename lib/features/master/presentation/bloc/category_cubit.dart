import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../data/master_repository.dart';

abstract class CategoryState {}
class CategoryInitial extends CategoryState {}
class CategoryLoading extends CategoryState {}
class CategoryLoaded extends CategoryState {
  final List<Category> categories;
  CategoryLoaded(this.categories);
}
class CategoryError extends CategoryState {
  final String message;
  CategoryError(this.message);
}

class CategoryCubit extends Cubit<CategoryState> {
  final MasterRepository _repository;

  CategoryCubit(this._repository) : super(CategoryInitial());

  Future<void> loadCategories() async {
    emit(CategoryLoading());
    try {
      final categories = await _repository.getCategories();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError('Gagal memuat kategori: $e'));
    }
  }

  Future<void> addCategory(String name, String? description) async {
    try {
      await _repository.insertCategory(
        CategoriesCompanion.insert(
          name: name,
          description: Value(description),
        ),
      );
      await loadCategories();
    } catch (e) {
      emit(CategoryError('Gagal menambah kategori: $e'));
    }
  }

  Future<void> editCategory(Category category, String name, String? description) async {
    try {
      await _repository.updateCategory(
        category.copyWith(
          name: name,
          description: Value(description),
        ),
      );
      await loadCategories();
    } catch (e) {
      emit(CategoryError('Gagal mengubah kategori: $e'));
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _repository.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      emit(CategoryError('Gagal menghapus kategori: $e'));
    }
  }
}
