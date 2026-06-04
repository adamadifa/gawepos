import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/user_repository.dart';

abstract class UserManagementState {}
class UserManagementInitial extends UserManagementState {}
class UserManagementLoading extends UserManagementState {}
class UserManagementLoaded extends UserManagementState {
  final List<User> users;
  UserManagementLoaded(this.users);
}
class UserManagementError extends UserManagementState {
  final String message;
  UserManagementError(this.message);
}

class UserManagementCubit extends Cubit<UserManagementState> {
  final UserRepository _repository;

  UserManagementCubit(this._repository) : super(UserManagementInitial());

  Future<void> loadUsers() async {
    emit(UserManagementLoading());
    try {
      final users = await _repository.getUsers();
      emit(UserManagementLoaded(users));
    } catch (e) {
      emit(UserManagementError('Gagal memuat daftar user: $e'));
    }
  }

  Future<void> addUser({
    required String name,
    required String username,
    required String pin,
    required String role,
  }) async {
    emit(UserManagementLoading());
    try {
      await _repository.insertUser(
        name: name,
        username: username,
        pin: pin,
        role: role,
      );
      await loadUsers();
    } catch (e) {
      emit(UserManagementError('Gagal menambah user: $e'));
    }
  }

  Future<void> editUser(User user, {String? newPin}) async {
    emit(UserManagementLoading());
    try {
      await _repository.updateUser(user, newPin: newPin);
      await loadUsers();
    } catch (e) {
      emit(UserManagementError('Gagal memperbarui user: $e'));
    }
  }

  Future<void> toggleUserStatus(User user) async {
    emit(UserManagementLoading());
    try {
      await _repository.updateUser(
        user.copyWith(isActive: !user.isActive),
      );
      await loadUsers();
    } catch (e) {
      emit(UserManagementError('Gagal mengubah status user: $e'));
    }
  }

  Future<void> deleteUser(int id) async {
    emit(UserManagementLoading());
    try {
      await _repository.deleteUser(id);
      await loadUsers();
    } catch (e) {
      emit(UserManagementError('Gagal menghapus user: $e'));
    }
  }
}
