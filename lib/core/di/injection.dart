import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/user_management_cubit.dart';
import '../../features/auth/presentation/bloc/role_permissions_cubit.dart';
import '../../features/master/data/master_repository.dart';
import '../../features/master/presentation/bloc/category_cubit.dart';
import '../../features/master/presentation/bloc/brand_cubit.dart';
import '../../features/master/presentation/bloc/customer_cubit.dart';
import '../../features/master/presentation/bloc/supplier_cubit.dart';
import '../../features/master/presentation/bloc/product_cubit.dart';
import '../../features/inventory/data/inventory_repository.dart';
import '../../features/inventory/presentation/bloc/inventory_cubit.dart';
import '../../features/pos/data/sales_repository.dart';
import '../../features/pos/presentation/bloc/cart_cubit.dart';
import '../../features/pos/presentation/bloc/sales_cubit.dart';
import '../services/print_service.dart';
import '../../features/expenses/data/expenses_repository.dart';
import '../../features/expenses/presentation/bloc/expenses_cubit.dart';
import '../../features/purchases/data/purchase_repository.dart';
import '../../features/purchases/presentation/bloc/purchase_cubit.dart';
import '../../features/reports/data/reports_repository.dart';
import '../../features/reports/presentation/bloc/reports_cubit.dart';
import '../../features/inventory/data/return_repository.dart';
import '../../features/inventory/presentation/bloc/return_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  // Register AppDatabase
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
  
  // Register PrintService
  getIt.registerLazySingleton<PrintService>(() => PrintService());
  
  // Register AuthRepository
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(getIt<AppDatabase>()));

  // Register UserRepository
  getIt.registerLazySingleton<UserRepository>(() => UserRepository(getIt<AppDatabase>()));

  // Register MasterRepository
  getIt.registerLazySingleton<MasterRepository>(() => MasterRepository(getIt<AppDatabase>()));

  // Register InventoryRepository
  getIt.registerLazySingleton<InventoryRepository>(() => InventoryRepository(getIt<AppDatabase>()));

  // Register SalesRepository
  getIt.registerLazySingleton<SalesRepository>(() => SalesRepository(getIt<AppDatabase>()));
 
  // Register ExpensesRepository & PurchaseRepository
  getIt.registerLazySingleton<ExpensesRepository>(() => ExpensesRepository(getIt<AppDatabase>()));
  getIt.registerLazySingleton<PurchaseRepository>(() => PurchaseRepository(getIt<AppDatabase>()));
  getIt.registerLazySingleton<ReportsRepository>(() => ReportsRepository(getIt<AppDatabase>()));
  getIt.registerLazySingleton<ReturnRepository>(() => ReturnRepository(getIt<AppDatabase>()));

  // Register AuthCubit
  getIt.registerFactory<AuthCubit>(() => AuthCubit(getIt<AuthRepository>()));

  // Register UserManagementCubit & RolePermissionsCubit
  getIt.registerFactory<UserManagementCubit>(() => UserManagementCubit(getIt<UserRepository>()));
  getIt.registerFactory<RolePermissionsCubit>(() => RolePermissionsCubit(getIt<UserRepository>()));

  // Register Master Cubits
  getIt.registerFactory<CategoryCubit>(() => CategoryCubit(getIt<MasterRepository>()));
  getIt.registerFactory<BrandCubit>(() => BrandCubit(getIt<MasterRepository>()));
  getIt.registerFactory<CustomerCubit>(() => CustomerCubit(getIt<MasterRepository>()));
  getIt.registerFactory<SupplierCubit>(() => SupplierCubit(getIt<MasterRepository>()));
  getIt.registerFactory<ProductCubit>(() => ProductCubit(getIt<MasterRepository>()));

  // Register Inventory Cubit
  getIt.registerFactory<InventoryCubit>(() => InventoryCubit(getIt<InventoryRepository>()));
  getIt.registerFactory<ReturnCubit>(() => ReturnCubit(getIt<ReturnRepository>()));

  // Register Expenses & Purchase Cubits
  getIt.registerFactory<ExpensesCubit>(() => ExpensesCubit(getIt<ExpensesRepository>()));
  getIt.registerFactory<PurchaseCubit>(() => PurchaseCubit(getIt<PurchaseRepository>()));
  getIt.registerFactory<ReportsCubit>(() => ReportsCubit(getIt<ReportsRepository>()));

  // Register POS Cubits (Singleton karena digunakan secara global via MultiBlocProvider)
  getIt.registerLazySingleton<CartCubit>(() => CartCubit());
  getIt.registerLazySingleton<SalesCubit>(() => SalesCubit(getIt<SalesRepository>()));
}
