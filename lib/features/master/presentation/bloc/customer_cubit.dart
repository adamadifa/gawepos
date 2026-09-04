import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../data/master_repository.dart';

abstract class CustomerState {}
class CustomerInitial extends CustomerState {}
class CustomerLoading extends CustomerState {}
class CustomerLoaded extends CustomerState {
  final List<Customer> customers;
  CustomerLoaded(this.customers);
}
class CustomerSaved extends CustomerState {
  final String customerName;
  final bool isEdit;
  CustomerSaved({required this.customerName, this.isEdit = false});
}
class CustomerDeleted extends CustomerState {
  final String customerName;
  CustomerDeleted({required this.customerName});
}
class CustomerError extends CustomerState {
  final String message;
  CustomerError(this.message);
}

class CustomerCubit extends Cubit<CustomerState> {
  final MasterRepository _repository;

  CustomerCubit(this._repository) : super(CustomerInitial());

  Future<void> loadCustomers() async {
    emit(CustomerLoading());
    try {
      final customers = await _repository.getCustomers();
      emit(CustomerLoaded(customers));
    } catch (e) {
      emit(CustomerError('Gagal memuat pelanggan: $e'));
    }
  }

  Future<void> addCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      await _repository.insertCustomer(
        CustomersCompanion.insert(
          name: name,
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
        ),
      );
      emit(CustomerSaved(customerName: name, isEdit: false));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError('Gagal menambah pelanggan: $e'));
    }
  }

  Future<void> editCustomer(
    Customer customer, {
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      await _repository.updateCustomer(
        customer.copyWith(
          name: name,
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
        ),
      );
      emit(CustomerSaved(customerName: name, isEdit: true));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError('Gagal mengubah pelanggan: $e'));
    }
  }

  Future<void> deleteCustomer(int id, {String customerName = ''}) async {
    try {
      await _repository.deleteCustomer(id);
      emit(CustomerDeleted(customerName: customerName));
      await loadCustomers();
    } catch (e) {
      emit(CustomerError('Gagal menghapus pelanggan: $e'));
    }
  }
}
