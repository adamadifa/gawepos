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

  void _showAddEditUserDialog({User? user}) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final usernameController = TextEditingController(text: user?.username ?? '');
    final pinController = TextEditingController();
    String selectedRole = user?.role ?? 'cashier';
    bool isActive = user?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                user == null ? 'Tambah User Baru' : 'Edit User',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Nama harus diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        enabled: user == null, // Username tidak boleh diedit karena unique key
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Username harus diisi';
                          if (value.length < 3) return 'Minimal 3 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pinController,
                        decoration: InputDecoration(
                          labelText: user == null ? 'PIN (4-6 Digit)' : 'PIN Baru (Kosongkan jika tidak diubah)',
                          prefixIcon: const Icon(Icons.pin_rounded),
                          hintText: user == null ? '1234' : '••••',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        validator: (value) {
                          if (user == null) {
                            if (value == null || value.isEmpty) return 'PIN harus diisi';
                            if (value.length < 4 || value.length > 6) return 'PIN harus 4-6 digit';
                          } else {
                            if (value != null && value.isNotEmpty && (value.length < 4 || value.length > 6)) {
                              return 'PIN baru harus 4-6 digit';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role Akses',
                          prefixIcon: Icon(Icons.security_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin (Pemilik)')),
                          DropdownMenuItem(value: 'cashier', child: Text('Kasir')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status Akun Aktif',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            Switch.adaptive(
                              value: isActive,
                              activeColor: AppConstants.primaryColor,
                              onChanged: (val) {
                                setDialogState(() {
                                  isActive = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('BATAL'),
                ),
                ElevatedButton(
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
                  child: const Text('SIMPAN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Manajemen User',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah User',
            onPressed: () => _showAddEditUserDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<UserManagementCubit, UserManagementState>(
          listener: (context, state) {
            if (state is UserManagementError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppConstants.errorColor,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is UserManagementLoading) {
              return const Center(child: CircularProgressIndicator());
            }
  
            if (state is UserManagementLoaded) {
              final users = state.users;
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada user terdaftar',
                        style: GoogleFonts.poppins(color: AppConstants.textLightColor, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
  
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isAdmin = user.role == 'admin';
  
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isAdmin
                                ? AppConstants.primaryColor.withValues(alpha: 0.1)
                                : AppConstants.successColor.withValues(alpha: 0.1),
                            child: Text(
                              user.name[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: isAdmin ? AppConstants.primaryColor : AppConstants.successColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppConstants.textDarkColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '@${user.username}',
                                      style: TextStyle(
                                        color: AppConstants.textLightColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: user.isActive
                                            ? AppConstants.successColor.withValues(alpha: 0.1)
                                            : AppConstants.errorColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user.isActive ? 'Aktif' : 'Nonaktif',
                                        style: TextStyle(
                                          color: user.isActive ? AppConstants.successColor : AppConstants.errorColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showAddEditUserDialog(user: user);
                              } else if (action == 'status') {
                                context.read<UserManagementCubit>().toggleUserStatus(user);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Profile / PIN'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'status',
                                child: Row(
                                  children: [
                                    Icon(
                                      user.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: user.isActive ? AppConstants.errorColor : AppConstants.successColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(user.isActive ? 'Nonaktifkan User' : 'Aktifkan User'),
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
