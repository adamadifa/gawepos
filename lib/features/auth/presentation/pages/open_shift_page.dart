import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/auth_cubit.dart';

class OpenShiftPage extends StatefulWidget {
  final User user;
  const OpenShiftPage({super.key, required this.user});

  @override
  State<OpenShiftPage> createState() => _OpenShiftPageState();
}

class _OpenShiftPageState extends State<OpenShiftPage> {
  final _cashController = TextEditingController(text: '0');

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _submit() {
    final cash = double.tryParse(_cashController.text.trim()) ?? 0.0;
    context.read<AuthCubit>().openShift(cash);
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
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 30,
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
                      'Buka Sesi Shift Kasir',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content Area dengan Rounded Top ───────────────
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                color: AppConstants.backgroundColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Icon ──────────────────────────
                          Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: AppConstants.warningColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd),
                                border: Border.all(
                                  color: AppConstants.warningColor
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.vpn_key_rounded,
                                size: 32,
                                color: AppConstants.warningColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Buka Shift Kasir Baru',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textDarkColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Halo, ${widget.user.name}. Masukkan jumlah uang kas awal (modal) yang ada di dalam laci kasir saat ini.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppConstants.textLightColor,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Modal Input Card ───────────────
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
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Card header strip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryColor
                                        .withValues(alpha: 0.04),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(
                                          AppConstants.radiusMd),
                                    ),
                                    border: const Border(
                                      bottom: BorderSide(
                                          color: AppConstants.borderLightColor),
                                    ),
                                  ),
                                  child: Text(
                                    'UANG MODAL AWAL',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppConstants.textLightColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                // Amount field
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 16, 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Rp ',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.textLightColor,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _cashController,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            filled: false,
                                            contentPadding: EdgeInsets.zero,
                                            hintText: '0',
                                            hintStyle: GoogleFonts.poppins(
                                              color: AppConstants.textLightColor
                                                  .withValues(alpha: 0.4),
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.poppins(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: AppConstants.textDarkColor,
                                          ),
                                          onTap: () {
                                            if (_cashController.text == '0') {
                                              _cashController.clear();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Action Buttons ─────────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      context.read<AuthCubit>().logout(),
                                  child: const Text('LOG OUT'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  child: const Text('BUKA SHIFT'),
                                ),
                              ),
                            ],
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
