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
  bool _isSubmitting = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    await context.read<AuthCubit>().performOnboarding(
      shopName: _shopNameController.text.trim(),
      shopAddress: _shopAddressController.text.trim(),
      shopPhone: _shopPhoneController.text.trim(),
      adminName: _adminNameController.text.trim(),
      adminUsername: _adminUsernameController.text.trim(),
      adminPin: _adminPinController.text.trim(),
    );

    if (mounted) setState(() => _isSubmitting = false);
  }


  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppConstants.textDarkColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: AppConstants.backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppConstants.textLightColor,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppConstants.textLightColor.withValues(alpha: 0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppConstants.borderLightColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppConstants.borderLightColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppConstants.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppConstants.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppConstants.errorColor, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Column(
        children: [
          CurvedHeader(
            height: 220,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GawePOS',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lengkapi data toko & akun admin',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingMd,
                0,
                AppConstants.paddingMd,
                AppConstants.paddingLg,
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 540),
                  margin: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                          border: Border.all(color: AppConstants.borderLightColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSection(
                                icon: Icons.store_rounded,
                                title: 'Profil Toko / Outlet',
                                subtitle: 'Informasi dasar toko Anda',
                                color: AppConstants.primaryColor,
                                children: [
                                  _buildFormField(
                                    controller: _shopNameController,
                                    label: 'Nama Toko',
                                    icon: Icons.store_rounded,
                                    hint: 'Contoh: Cafe Kenangan',
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Nama toko wajib diisi' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildFormField(
                                    controller: _shopAddressController,
                                    label: 'Alamat Toko',
                                    icon: Icons.location_on_rounded,
                                    hint: 'Alamat lengkap toko Anda',
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildFormField(
                                    controller: _shopPhoneController,
                                    label: 'Nomor Telepon',
                                    icon: Icons.phone_rounded,
                                    hint: 'Contoh: 08123456789',
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Divider(
                                  color: AppConstants.borderLightColor,
                                  height: 1,
                                ),
                              ),

                              _buildSection(
                                icon: Icons.admin_panel_settings_rounded,
                                title: 'Akun Administrator Utama',
                                subtitle: 'Login pertama untuk kelola toko',
                                color: AppConstants.successColor,
                                children: [
                                  _buildFormField(
                                    controller: _adminNameController,
                                    label: 'Nama Lengkap Admin',
                                    icon: Icons.person_rounded,
                                    hint: 'Contoh: Bambang',
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Nama admin wajib diisi' : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildFormField(
                                    controller: _adminUsernameController,
                                    label: 'Username Login',
                                    icon: Icons.alternate_email_rounded,
                                    hint: 'Contoh: admin',
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Username wajib diisi';
                                      if (v.length < 3) return 'Minimal 3 karakter';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  _buildFormField(
                                    controller: _adminPinController,
                                    label: 'PIN Login (4-6 Digit Angka)',
                                    icon: Icons.lock_rounded,
                                    hint: 'Contoh: 123456',
                                    keyboardType: TextInputType.number,
                                    obscure: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'PIN wajib diisi';
                                      if (int.tryParse(v) == null) return 'PIN harus berupa angka';
                                      if (v.length < 4 || v.length > 6) return 'PIN harus 4 sampai 6 digit';
                                      return null;
                                    },
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppConstants.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                                      ),
                                      shadowColor: AppConstants.primaryColor.withValues(alpha: 0.3),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.check_circle_outline_rounded, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Simpan & Mulai Aplikasi',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textDarkColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppConstants.textLightColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
