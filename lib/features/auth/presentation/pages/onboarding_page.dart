import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/curved_header.dart';
import '../bloc/auth_cubit.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();

  final _adminNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPinController = TextEditingController();

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _adminNameController.dispose();
    _adminUsernameController.dispose();
    _adminPinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().performOnboarding(
        shopName: _shopNameController.text.trim(),
        shopAddress: _shopAddressController.text.trim(),
        shopPhone: _shopPhoneController.text.trim(),
        adminName: _adminNameController.text.trim(),
        adminUsername: _adminUsernameController.text.trim(),
        adminPin: _adminPinController.text.trim(),
      );
    }
  }

  /// Section header dengan left border accent berwarna.
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppConstants.textDarkColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          // Background header dengan diagonal clipper
          const CurvedHeader(height: 280),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMd,
                vertical: AppConstants.paddingLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),

                  // App icon
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(
                        Icons.point_of_sale_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'GawePOS',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Setup toko & kasir dalam hitungan menit',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Form Card ──────────────────────────────
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 550),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLg),
                        border: Border.all(color: AppConstants.borderLightColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(AppConstants.paddingLg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── SECTION 1: Profil Toko ────────
                            _buildSectionHeader(
                              'Profil Toko / Outlet',
                              Icons.business_rounded,
                              AppConstants.primaryColor,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _shopNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Toko',
                                prefixIcon: Icon(Icons.store_rounded),
                                hintText: 'Contoh: Cafe Kenangan',
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Nama toko wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _shopAddressController,
                              decoration: const InputDecoration(
                                labelText: 'Alamat Toko',
                                prefixIcon: Icon(Icons.location_on_rounded),
                                hintText: 'Alamat lengkap toko Anda',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _shopPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Nomor Telepon',
                                prefixIcon: Icon(Icons.phone_rounded),
                                hintText: 'Contoh: 08123456789',
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 24),

                            // ── SECTION 2: Administrator ───────
                            _buildSectionHeader(
                              'Akun Administrator Utama',
                              Icons.admin_panel_settings_rounded,
                              AppConstants.successColor,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _adminNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Lengkap Admin',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Nama admin wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _adminUsernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username Login',
                                prefixIcon:
                                    Icon(Icons.alternate_email_rounded),
                                hintText: 'Contoh: admin',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Username wajib diisi';
                                }
                                if (v.length < 3) {
                                  return 'Minimal 3 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _adminPinController,
                              decoration: const InputDecoration(
                                labelText: 'PIN Login (4-6 Digit Angka)',
                                prefixIcon: Icon(Icons.lock_rounded),
                                hintText: 'Contoh: 123456',
                              ),
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'PIN wajib diisi';
                                }
                                if (int.tryParse(v) == null) {
                                  return 'PIN harus berupa angka';
                                }
                                if (v.length < 4 || v.length > 6) {
                                  return 'PIN harus 4 sampai 6 digit';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _submit,
                                child: const Text('Simpan & Mulai Aplikasi'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
