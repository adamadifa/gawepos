import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/user_management_cubit.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    context.read<UserManagementCubit>().loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditUserDialog({User? user}) {
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
                top: 16,
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
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Modal Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0D9488), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user == null ? 'Tambah Pengguna Baru' : 'Edit Pengguna',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  user == null ? 'Buat akun kasir atau pengelola baru' : 'Perbarui profil, peran, atau PIN kasir',
                                  style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Input Nama
                      Text(
                        'Nama Lengkap',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration(
                          hintText: 'Contoh: Budi Santoso',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Nama harus diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      // Input Username
                      Text(
                        'Username (ID Login)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: usernameController,
                        enabled: user == null,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: user == null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                        decoration: _buildInputDecoration(
                          hintText: 'Contoh: kasir1',
                          prefixIcon: Icons.alternate_email_rounded,
                          helperText: user == null ? 'Digunakan saat login (tanpa spasi)' : 'Username tidak dapat diubah',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Username harus diisi';
                          if (value.trim().length < 3) return 'Minimal 3 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Input PIN
                      Text(
                        user == null ? 'PIN Akses (4-6 Angka)' : 'PIN Baru (Opsional)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                        decoration: _buildInputDecoration(
                          hintText: user == null ? 'Contoh: 1234' : 'Biarkan kosong jika tidak diubah',
                          prefixIcon: Icons.pin_outlined,
                        ),
                        validator: (value) {
                          if (user == null) {
                            if (value == null || value.isEmpty) return 'PIN harus diisi';
                            if (value.length < 4 || value.length > 6) return 'PIN harus 4-6 digit angka';
                          } else {
                            if (value != null && value.isNotEmpty && (value.length < 4 || value.length > 6)) {
                              return 'PIN baru harus 4-6 digit angka';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Role Switcher Cards
                      Text(
                        'Peran Pengguna (Role)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRoleChoiceCard(
                            roleId: 'cashier',
                            title: 'Kasir',
                            desc: 'Hanya akses menu kasir',
                            icon: Icons.point_of_sale_rounded,
                            selectedRole: selectedRole,
                            onSelect: (r) => setModalState(() => selectedRole = r),
                          ),
                          const SizedBox(width: 10),
                          _buildRoleChoiceCard(
                            roleId: 'admin',
                            title: 'Admin Toko',
                            desc: 'Akses penuh ke semua menu',
                            icon: Icons.admin_panel_settings_rounded,
                            selectedRole: selectedRole,
                            onSelect: (r) => setModalState(() => selectedRole = r),
                          ),
                        ],
                      ),

                      if (user != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status Akun',
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    isActive ? 'Akun dapat digunakan login' : 'Akun dinonaktifkan sementara',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: isActive,
                                activeTrackColor: const Color(0xFF0D9488).withValues(alpha: 0.5),
                                activeThumbColor: const Color(0xFF0D9488),
                                onChanged: (val) => setModalState(() => isActive = val),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
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
                          label: Text(
                            user == null ? 'TAMBAH PENGGUNA' : 'SIMPAN PERUBAHAN',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
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
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manajemen Pengguna',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17, color: const Color(0xFF0F172A)),
            ),
            Text(
              'Daftar akun kasir & hak akses login',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditUserDialog(),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: Text('Tambah Kasir', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      body: SafeArea(
        child: BlocConsumer<UserManagementCubit, UserManagementState>(
          listener: (context, state) {
            if (state is UserManagementError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
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
              final totalUsers = users.length;
              final totalAdmin = users.where((u) => u.role == 'admin').length;
              final totalCashier = users.where((u) => u.role == 'cashier').length;
              final totalActive = users.where((u) => u.isActive).length;

              final filteredUsers = users.where((u) {
                final matchQuery = _searchQuery.isEmpty ||
                    u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    u.username.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchRole = _selectedRoleFilter == 'Semua' ||
                    (_selectedRoleFilter == 'Admin' && u.role == 'admin') ||
                    (_selectedRoleFilter == 'Kasir' && u.role == 'cashier');
                return matchQuery && matchRole;
              }).toList();

              return Column(
                children: [
                  // ── TOP SUMMARY BANNER ────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      children: [
                        // Stat overview chips
                        Row(
                          children: [
                            _buildStatBadge('Total Akun', '$totalUsers', const Color(0xFF0F172A), const Color(0xFFF1F5F9)),
                            const SizedBox(width: 8),
                            _buildStatBadge('Admin', '$totalAdmin', const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
                            const SizedBox(width: 8),
                            _buildStatBadge('Kasir', '$totalCashier', const Color(0xFF0F766E), const Color(0xFFF0FDFA)),
                            const SizedBox(width: 8),
                            _buildStatBadge('Aktif', '$totalActive', const Color(0xFF15803D), const Color(0xFFF0FDF4)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Search Input & Role Filter Tabs
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Cari nama atau @username...',
                              hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Role Filter Tabs
                        Row(
                          children: ['Semua', 'Kasir', 'Admin'].map((role) {
                            final isSel = _selectedRoleFilter == role;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: InkWell(
                                onTap: () => setState(() => _selectedRoleFilter = role),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    role,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // ── USER LIST ────────────────────────────────
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Pengguna tidak ditemukan',
                                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Coba cari dengan nama atau username lain',
                                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final isAdmin = user.role == 'admin';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
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
                                      // Avatar Initial with role color
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDFA),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isAdmin ? const Color(0xFFBFDBFE) : const Color(0xFF99F6E4),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF0D9488),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // User Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    user.name,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13.5,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Role badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isAdmin ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isAdmin ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isAdmin ? 'ADMIN' : 'KASIR',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
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
                                                    fontSize: 11.5,
                                                    color: const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Color(0xFFCBD5E1),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Status badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: user.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: user.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        user.isActive ? 'Aktif' : 'Nonaktif',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: user.isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Actions Popup
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            _showAddEditUserDialog(user: user);
                                          } else if (action == 'status') {
                                            context.read<UserManagementCubit>().toggleUserStatus(user);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Edit Data / PIN',
                                                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
                                                ),
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
                                                  color: user.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  user.isActive ? 'Nonaktifkan Akun' : 'Aktifkan Akun',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: user.isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                                  ),
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
                          ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String count, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 9.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)),
      helperText: helperText,
      helperStyle: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildRoleChoiceCard({
    required String roleId,
    required String title,
    required String desc,
    required IconData icon,
    required String selectedRole,
    required Function(String) onSelect,
  }) {
    final isSelected = roleId == selectedRole;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(roleId),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF475569)),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF38BDF8)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
