import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
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
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      width: isFilled ? 18 : 14,
      height: isFilled ? 18 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        border: Border.all(
          color: isFilled
              ? const Color(0xFF2563EB)
              : const Color(0xFFCBD5E1),
          width: 2,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildKeypadButton(String text,
      {VoidCallback? onPressed, IconData? icon, Color? iconColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed ?? () => _onKeyPress(text),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 78,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: icon != null
              ? Icon(icon, size: 22, color: iconColor ?? const Color(0xFF64748B))
              : Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              'GawePOS',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting & Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.lock_person_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Akses Kasir',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Pilih profil kasir & ketik PIN keamanan',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                          // User Selector
                          Text(
                            'PILIH PENGGUNA',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<User>(
                                value: _selectedUser,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF2563EB),
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
                                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                          radius: 16,
                                          child: Text(
                                            user.name[0].toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            user.name,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            user.role.toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: const Color(0xFF2563EB),
                                              fontWeight: FontWeight.w700,
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
                          const SizedBox(height: 24),

                          // PIN Dots Area
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Ketik PIN',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (i) => _buildPinDot(i)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Keypad
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('1'),
                                  _buildKeypadButton('2'),
                                  _buildKeypadButton('3'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('4'),
                                  _buildKeypadButton('5'),
                                  _buildKeypadButton('6'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('7'),
                                  _buildKeypadButton('8'),
                                  _buildKeypadButton('9'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildKeypadButton('C',
                                      onPressed: _onClear,
                                      icon: Icons.clear_rounded,
                                      iconColor: const Color(0xFFEF4444)),
                                  _buildKeypadButton('0'),
                                  _buildKeypadButton('⌫',
                                      onPressed: _onBackspace,
                                      icon: Icons.backspace_outlined,
                                      iconColor: const Color(0xFF64748B)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Submit Button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFCBD5E1),
                                disabledForegroundColor: Colors.white70,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _pinCode.length >= 4 ? _submit : null,
                              child: Text(
                                'MASUK KASIR',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
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
    );
  }
}


