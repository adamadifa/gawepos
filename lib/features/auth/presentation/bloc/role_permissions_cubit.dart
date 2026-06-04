import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/app_database.dart';
import '../../data/user_repository.dart';

abstract class RolePermissionsState {}
class RolePermissionsInitial extends RolePermissionsState {}
class RolePermissionsLoading extends RolePermissionsState {}
class RolePermissionsLoaded extends RolePermissionsState {
  final List<RolePermission> permissions;
  RolePermissionsLoaded(this.permissions);
}
class RolePermissionsError extends RolePermissionsState {
  final String message;
  RolePermissionsError(this.message);
}

class RolePermissionsCubit extends Cubit<RolePermissionsState> {
  final UserRepository _repository;

  RolePermissionsCubit(this._repository) : super(RolePermissionsInitial());

  Future<void> loadPermissions() async {
    emit(RolePermissionsLoading());
    try {
      final permissions = await _repository.getRolePermissions();
      emit(RolePermissionsLoaded(permissions));
    } catch (e) {
      emit(RolePermissionsError('Gagal memuat hak akses role: $e'));
    }
  }

  Future<void> updatePermissions(String role, List<String> allowedMenus) async {
    emit(RolePermissionsLoading());
    try {
      await _repository.updateRolePermissions(role, allowedMenus);
      await loadPermissions();
    } catch (e) {
      emit(RolePermissionsError('Gagal memperbarui hak akses role: $e'));
    }
  }
}
