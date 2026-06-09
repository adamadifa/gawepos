import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/constants.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/auth/presentation/pages/onboarding_intro_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/open_shift_page.dart';
import 'features/pos/presentation/pages/home_page.dart';
import 'features/master/presentation/bloc/category_cubit.dart';
import 'features/master/presentation/bloc/brand_cubit.dart';
import 'features/master/presentation/bloc/customer_cubit.dart';
import 'features/master/presentation/bloc/supplier_cubit.dart';
import 'features/master/presentation/bloc/product_cubit.dart';
import 'features/inventory/presentation/bloc/inventory_cubit.dart';
import 'features/pos/presentation/bloc/cart_cubit.dart';
import 'features/pos/presentation/bloc/sales_cubit.dart';
import 'features/expenses/presentation/bloc/expenses_cubit.dart';
import 'features/purchases/presentation/bloc/purchase_cubit.dart';
import 'features/reports/presentation/bloc/reports_cubit.dart';
import 'features/auth/presentation/bloc/user_management_cubit.dart';
import 'features/auth/presentation/bloc/role_permissions_cubit.dart';
import 'features/inventory/presentation/bloc/return_cubit.dart';

import 'package:intl/date_symbol_data_local.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  // Pastikan binding Flutter diinisialisasi
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi format tanggal lokal (Indonesia)
  await initializeDateFormatting('id', null);
  
  // Setup Dependency Injection (GetIt)
  await setupLocator();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (context) => getIt<AuthCubit>()..checkStatus(),
        ),
        BlocProvider<UserManagementCubit>(
          create: (context) => getIt<UserManagementCubit>()..loadUsers(),
        ),
        BlocProvider<RolePermissionsCubit>(
          create: (context) => getIt<RolePermissionsCubit>()..loadPermissions(),
        ),
        BlocProvider<CategoryCubit>(
          create: (context) => getIt<CategoryCubit>(),
        ),
        BlocProvider<BrandCubit>(
          create: (context) => getIt<BrandCubit>(),
        ),
        BlocProvider<CustomerCubit>(
          create: (context) => getIt<CustomerCubit>(),
        ),
        BlocProvider<SupplierCubit>(
          create: (context) => getIt<SupplierCubit>(),
        ),
        BlocProvider<ProductCubit>(
          create: (context) => getIt<ProductCubit>(),
        ),
        BlocProvider<InventoryCubit>(
          create: (context) => getIt<InventoryCubit>(),
        ),
        BlocProvider<CartCubit>(
          create: (context) => getIt<CartCubit>(),
        ),
        BlocProvider<SalesCubit>(
          create: (context) => getIt<SalesCubit>(),
        ),
        BlocProvider<ExpensesCubit>(
          create: (context) => getIt<ExpensesCubit>()..loadExpenses(),
        ),
        BlocProvider<PurchaseCubit>(
          create: (context) => getIt<PurchaseCubit>()..loadPurchases(),
        ),
        BlocProvider<ReportsCubit>(
          create: (context) => getIt<ReportsCubit>()..loadDashboard(),
        ),
        BlocProvider<ReturnCubit>(
          create: (context) => getIt<ReturnCubit>(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        navigatorObservers: [routeObserver],
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is AuthSplash || state is AuthLoading) {
          return const SplashPage();
        }
        
        if (state is AuthIntroRequired) {
          return const OnboardingIntroPage();
        }
        
        if (state is AuthOnboardingRequired) {
          return const OnboardingPage();
        }
        
        if (state is AuthLoginRequired) {
          return LoginPage(users: state.users);
        }
        
        if (state is AuthSessionRequired) {
          return OpenShiftPage(user: state.user);
        }
        
        if (state is AuthAuthenticated) {
          return HomePage(user: state.user, session: state.session);
        }

        // Default fallback (misal jika terjadi error berat)
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppConstants.errorColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Terjadi kesalahan aplikasi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthCubit>().checkStatus();
                    },
                    child: const Text('COBA LAGI'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
