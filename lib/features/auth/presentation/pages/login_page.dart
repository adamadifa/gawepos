import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  final List<User> users;
  const LoginPage({super.key, required this.users});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  User? _selectedUser;
  String _pinCode = '';

  @override
  void initState() {
    super.initState();
    if (widget.users.isNotEmpty) {
      _selectedUser = widget.users.first;
    }
  }

  void _onKeyPress(String val) {
    if (_pinCode.length >= 6) return;
    setState(() => _pinCode += val);
  }

  void _onBackspace() {
    if (_pinCode.isEmpty) return;
    setState(() => _pinCode = _pinCode.substring(0, _pinCode.length - 1));
  }

  void _onClear() => setState(() => _pinCode = '');

  void _submit() {
    if (_selectedUser == null || _pinCode.isEmpty) return;
    context.read<AuthCubit>().login(_selectedUser!.username, _pinCode);
  }

  Widget _buildPinDot(int index) {
    final isFilled = index < _pinCode.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: isFilled ? 18 : 14,
      height: isFilled ? 18 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? AppConstants.primaryColor : Colors.transparent,
        border: Border.all(
          color: isFilled
              ? AppConstants.primaryColor
              : AppConstants.textLightColor.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: AppConstants.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildKeypadButton(String text,
      {VoidCallback? onPressed, IconData? icon}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed ?? () => _onKeyPress(text),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Container(
          width: 76,
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            color: Colors.white,
            border: Border.all(color: AppConstants.borderLightColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: icon != null
              ? Icon(icon, size: 21, color: AppConstants.textLightColor)
              : Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textDarkColor,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Indigo Gradient Header ─────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primaryColor,
                  AppConstants.primaryDarkColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 44),
                child: Column(
                  children: [
                    // App icon box
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'GawePOS',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mode Standalone — Kasir Mandiri',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── White Content Area dengan Rounded Top ─────────
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                color: AppConstants.backgroundColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── User Selector ──────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd),
                              border: Border.all(
                                  color: AppConstants.borderLightColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<User>(
                                value: _selectedUser,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.unfold_more_rounded,
                                  color: AppConstants.primaryColor,
                                ),
                                onChanged: (User? newUser) {
                                  setState(() {
                                    _selectedUser = newUser;
                                    _pinCode = '';
                                  });
                                },
                                items: widget.users.map((User user) {
                                  return DropdownMenuItem<User>(
                                    value: user,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppConstants
                                              .primaryColor
                                              .withValues(alpha: 0.1),
                                          radius: 16,
                                          child: Text(
                                            user.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppConstants.primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            user.name,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppConstants.textDarkColor,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppConstants.primaryColor
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            user.role,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppConstants.primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── PIN Label ──────────────────────
                          Text(
                            'Masukkan PIN',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppConstants.textLightColor,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── PIN Dots ───────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children:
                                List.generate(6, (i) => _buildPinDot(i)),
                          ),
                          const SizedBox(height: 28),

                          // ── Keypad ─────────────────────────
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('1'),
                                  _buildKeypadButton('2'),
                                  _buildKeypadButton('3'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('4'),
                                  _buildKeypadButton('5'),
                                  _buildKeypadButton('6'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('7'),
                                  _buildKeypadButton('8'),
                                  _buildKeypadButton('9'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('C',
                                      onPressed: _onClear,
                                      icon: Icons.clear_rounded),
                                  _buildKeypadButton('0'),
                                  _buildKeypadButton('⌫',
                                      onPressed: _onBackspace,
                                      icon: Icons.backspace_outlined),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ── Login Button ───────────────────
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _pinCode.length >= 4 ? _submit : null,
                              child: Text(
                                'MASUK KASIR',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
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
          ),
        ],
      ),
    );
  }
}
