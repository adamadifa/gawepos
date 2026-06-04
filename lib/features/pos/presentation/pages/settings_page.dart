import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/pages/user_management_page.dart';
import '../../../auth/presentation/pages/role_permissions_page.dart';
import 'database_management_page.dart';
import 'printer_settings_page.dart';
import 'shop_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final canManageUsers = authCubit.isMenuAllowed('users');

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Pengaturan Aplikasi',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canManageUsers) ...[
            _buildMenuCard(
              context: context,
              icon: Icons.people_outline_rounded,
              iconColor: Colors.teal.shade600,
              bgColor: Colors.teal.shade50,
              title: 'Manajemen User',
              subtitle: 'Tambah kasir baru, ubah nama, ganti PIN, atau ubah status aktif.',
              destination: const UserManagementPage(),
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context: context,
              icon: Icons.security_rounded,
              iconColor: Colors.red.shade600,
              bgColor: Colors.red.shade50,
              title: 'Hak Akses Menu',
              subtitle: 'Batasi menu apa saja yang boleh dibuka oleh Kasir atau Admin.',
              destination: const RolePermissionsPage(),
            ),
            const SizedBox(height: 12),
          ],
          _buildMenuCard(
            context: context,
            icon: Icons.store_rounded,
            iconColor: Colors.blue.shade600,
            bgColor: Colors.blue.shade50,
            title: 'Profil & Struk Toko',
            subtitle: 'Nama, telepon, alamat toko, header & footer cetakan struk.',
            destination: const ShopSettingsPage(),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context: context,
            icon: Icons.print_rounded,
            iconColor: Colors.purple.shade600,
            bgColor: Colors.purple.shade50,
            title: 'Printer Bluetooth',
            subtitle: 'Hubungkan printer thermal kasir dan lakukan uji test print.',
            destination: const PrinterSettingsPage(),
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context: context,
            icon: Icons.storage_rounded,
            iconColor: Colors.indigo.shade600,
            bgColor: Colors.indigo.shade50,
            title: 'Backup & Restore Data',
            subtitle: 'Cadangkan data database lokal atau pulihkan dari file luar.',
            destination: const DatabaseManagementPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
