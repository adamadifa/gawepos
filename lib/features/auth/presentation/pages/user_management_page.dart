import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/user_management_cubit.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  @override
  void initState() {
    super.initState();
    context.read<UserManagementCubit>().loadUsers();
  }

  void _showAddEditUserBottomSheet({User? user}) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final usernameController = TextEditingController(text: user?.username ?? '');
    final pinController = TextEditingController();
    String selectedRole = user?.role ?? 'cashier';
    bool isActive = user?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user == null ? 'Tambah Pengguna Baru' : 'Edit Data Pengguna',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                user == null
                                    ? 'Daftarkan akun kasir atau staf baru'
                                    : 'Perbarui nama, peran, atau ubah PIN akun',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      // Nama Lengkap
                      Text(
                        'Nama Lengkap',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Ahmad Kasir',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      // Username
                      Text(
                        'Username (ID Login)',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: usernameController,
                        enabled: user == null,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Contoh: ahmad01',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: user == null ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Username wajib diisi';
                          if (value.trim().length < 3) return 'Minimal 3 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // PIN
                      Text(
                        user == null ? 'PIN Akses (4-6 Digit Angka)' : 'PIN Baru (Kosongkan jika tidak diubah)',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        style: GoogleFonts.poppins(fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: user == null ? '1234' : '••••',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, letterSpacing: 0, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.pin_rounded, size: 18, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                        validator: (value) {
                          if (user == null) {
                            if (value == null || value.isEmpty) return 'PIN wajib diisi';
                            if (value.length < 4 || value.length > 6) return 'PIN harus 4-6 digit angka';
                          } else {
                            if (value != null && value.isNotEmpty && (value.length < 4 || value.length > 6)) {
                              return 'PIN baru harus 4-6 digit';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Role Akses
                      Text(
                        'Peran / Role Akses',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.security_rounded, size: 18, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'cashier',
                            child: Text('Kasir (Akses Terbatas)', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A))),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin (Pemilik / Akses Penuh)', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A))),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedRole = val);
                          }
                        },
                      ),

                      if (user != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status Akun Aktif',
                                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                              ),
                              Switch(
                                value: isActive,
                                activeThumbColor: const Color(0xFF0F172A),
                                onChanged: (val) {
                                  setModalState(() => isActive = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            if (user == null) {
                              context.read<UserManagementCubit>().addUser(
                                    name: nameController.text.trim(),
                                    username: usernameController.text.trim(),
                                    pin: pinController.text,
                                    role: selectedRole,
                                  );
                            } else {
                              final updatedUser = user.copyWith(
                                name: nameController.text.trim(),
                                role: selectedRole,
                                isActive: isActive,
                              );
                              context.read<UserManagementCubit>().editUser(
                                    updatedUser,
                                    newPin: pinController.text.isNotEmpty ? pinController.text : null,
                                  );
                            }
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(
                          user == null ? 'TAMBAH PENGGUNA' : 'SIMPAN PERUBAHAN',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manajemen User',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kelola akun kasir, admin, dan hak otorisasi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Tambah User Baru',
            onPressed: () => _showAddEditUserBottomSheet(),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<UserManagementCubit, UserManagementState>(
          listener: (context, state) {
            if (state is UserManagementError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message, style: GoogleFonts.poppins()),
                  backgroundColor: AppConstants.errorColor,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is UserManagementLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
            }

            if (state is UserManagementLoaded) {
              final users = state.users;
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada pengguna terdaftar.',
                        style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isAdmin = user.role == 'admin';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isAdmin
                                ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                                : const Color(0xFF0D9488).withValues(alpha: 0.1),
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF0D9488),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                                            : const Color(0xFF0D9488).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isAdmin ? 'ADMIN' : 'KASIR',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF0D9488),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      '@${user.username}',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: user.isActive
                                            ? const Color(0xFF059669).withValues(alpha: 0.1)
                                            : const Color(0xFFDC2626).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user.isActive ? 'Aktif' : 'Nonaktif',
                                        style: GoogleFonts.poppins(
                                          color: user.isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showAddEditUserBottomSheet(user: user);
                              } else if (action == 'status') {
                                context.read<UserManagementCubit>().toggleUserStatus(user);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF0F172A)),
                                    const SizedBox(width: 8),
                                    Text('Edit Profil / PIN', style: GoogleFonts.poppins(fontSize: 12)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'status',
                                child: Row(
                                  children: [
                                    Icon(
                                      user.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: user.isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      user.isActive ? 'Nonaktifkan Akun' : 'Aktifkan Akun',
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
