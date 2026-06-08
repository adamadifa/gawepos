import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import '../../../../core/database/app_database.dart';

// States
abstract class AuthState {}

class AuthSplash extends AuthState {}

class AuthLoading extends AuthState {}

class AuthIntroRequired extends AuthState {}

class AuthOnboardingRequired extends AuthState {}

class AuthLoginRequired extends AuthState {
  final List<User> users;
  AuthLoginRequired(this.users);
}

class AuthSessionRequired extends AuthState {
  final User user;
  AuthSessionRequired(this.user);
}

class AuthAuthenticated extends AuthState {
  final User user;
  final CashierSession? session;
  AuthAuthenticated(this.user, this.session);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Cubit
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  
  User? _currentUser;
  CashierSession? _currentSession;
  List<String> _allowedMenus = [];

  AuthCubit(this._authRepository) : super(AuthSplash());

  User? get currentUser => _currentUser;
  CashierSession? get currentSession => _currentSession;
  List<String> get allowedMenus => _allowedMenus;

  bool isMenuAllowed(String menuKey) {
    if (_currentUser == null) return false;
    // Admin always has access to users, settings, and owner_dashboard to prevent lockout
    if (_currentUser!.role == 'admin' && 
        (menuKey == 'users' || menuKey == 'settings' || menuKey == 'owner_dashboard' || menuKey == 'debts_receivables' || menuKey == 'returns')) {
      return true;
    }
    return _allowedMenus.contains(menuKey);
  }

  // Cek status awal aplikasi saat dibuka
  Future<void> checkStatus() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    emit(AuthLoading());
    try {
      final hasOutlet = await _authRepository.hasOutlet();
      if (!hasOutlet) {
        final introShown = await _authRepository.isIntroShown();
        if (!introShown) {
          emit(AuthIntroRequired());
        } else {
          emit(AuthOnboardingRequired());
        }
        return;
      }

      final activeSession = await _authRepository.getActiveSession();
      if (activeSession != null) {
        // Cari user untuk sesi ini
        final users = await _authRepository.getActiveUsers();
        final sessionUser = users.firstWhere((u) => u.id == activeSession.userId);
        _currentUser = sessionUser;
        _currentSession = activeSession;
        _allowedMenus = await _authRepository.getAllowedMenus(sessionUser.role);
        emit(AuthAuthenticated(sessionUser, activeSession));
      } else {
        final users = await _authRepository.getActiveUsers();
        emit(AuthLoginRequired(users));
      }
    } catch (e) {
      emit(AuthError('Gagal memuat status aplikasi: $e'));
    }
  }

  // Selesaikan intro carousel dan lanjut ke onboarding
  Future<void> completeIntro() async {
    await _authRepository.markIntroShown();
    emit(AuthOnboardingRequired());
  }

  // Proses onboarding pertama kali
  Future<void> performOnboarding({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String adminName,
    required String adminUsername,
    required String adminPin,
  }) async {
    emit(AuthLoading());
    try {
      final success = await _authRepository.setupOnboarding(
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        adminName: adminName,
        adminUsername: adminUsername,
        adminPin: adminPin,
      );

      if (success) {
        // Onboarding sukses, langsung diarahkan ke layar login dengan daftar user baru
        final users = await _authRepository.getActiveUsers();
        emit(AuthLoginRequired(users));
      } else {
        emit(AuthError('Gagal menyimpan konfigurasi onboarding.'));
      }
    } catch (e) {
      emit(AuthError('Terjadi kesalahan onboarding: $e'));
    }
  }

  // Login dengan PIN
  Future<void> login(String username, String pin) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.authenticate(username, pin);
      if (user != null) {
        _currentUser = user;
        _allowedMenus = await _authRepository.getAllowedMenus(user.role);
        
        // Cek apakah ada sesi aktif untuk user ini (atau sesi kasir umum)
        final activeSession = await _authRepository.getActiveSession();
        if (activeSession != null) {
          _currentSession = activeSession;
          emit(AuthAuthenticated(user, activeSession));
        } else {
          if (user.role == 'admin') {
            emit(AuthAuthenticated(user, null));
          } else {
            emit(AuthSessionRequired(user));
          }
        }
      } else {
        final users = await _authRepository.getActiveUsers();
        emit(AuthError('PIN yang Anda masukkan salah.'));
        emit(AuthLoginRequired(users));
      }
    } catch (e) {
      emit(AuthError('Gagal melakukan autentikasi: $e'));
    }
  }

  // Membuka Shift Kasir
  Future<void> openShift(double openingCash) async {
    if (_currentUser == null) return;
    emit(AuthLoading());
    try {
      final session = await _authRepository.openSession(_currentUser!.id, openingCash);
      _currentSession = session;
      emit(AuthAuthenticated(_currentUser!, session));
    } catch (e) {
      emit(AuthError('Gagal membuka shift kasir: $e'));
    }
  }

  // Mendapatkan nilai teoretis laci kasir sebelum ditutup
  Future<double> getExpectedCashAmount() async {
    if (_currentSession == null) return 0.0;
    return await _authRepository.getExpectedCash(_currentSession!.id);
  }

  // Mendapatkan rincian transaksi sesi aktif
  Future<Map<String, dynamic>?> getActiveSessionDetails() async {
    if (_currentSession == null) return null;
    return await _authRepository.getActiveSessionDetails(_currentSession!.id);
  }

  // Menutup Shift Kasir
  Future<void> closeShift(double closingCash) async {
    if (_currentSession == null) return;
    emit(AuthLoading());
    try {
      final expected = await _authRepository.getExpectedCash(_currentSession!.id);
      final difference = closingCash - expected;

      await _authRepository.closeSession(
        sessionId: _currentSession!.id,
        closingCash: closingCash,
        expectedCash: expected,
        differenceAmount: difference,
      );

      _currentSession = null;
      _currentUser = null;

      // Kembali ke halaman login
      final users = await _authRepository.getActiveUsers();
      emit(AuthLoginRequired(users));
    } catch (e) {
      emit(AuthError('Gagal menutup shift kasir: $e'));
    }
  }

  // Log Out (Keluar ke layar PIN tanpa menutup shift kasir aktif)
  void logout() async {
    _currentUser = null;
    _currentSession = null;
    try {
      final users = await _authRepository.getActiveUsers();
      emit(AuthLoginRequired(users));
    } catch (e) {
      emit(AuthError('Gagal memuat daftar user untuk logout: $e'));
    }
  }
}
