import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/curved_header.dart';
import '../../data/master_repository.dart';
import 'categories_brands_page.dart';
import 'contacts_page.dart';
import 'products_list_page.dart';
import '../../../inventory/presentation/pages/stock_opname_page.dart';
import '../../../inventory/presentation/pages/stock_adjustment_page.dart';

class MasterMenuPage extends StatelessWidget {
  const MasterMenuPage({super.key});

  void _showSeedConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        title: Text(
          'Isi Data Dummy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengisi data dummy untuk produk, kategori, merek, pelanggan, dan pemasok?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await getIt<MasterRepository>().seedDummyData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Berhasil mengisi data dummy master.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal mengisi data dummy: $e'),
                      backgroundColor: AppConstants.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('YA, ISI DATA'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppConstants.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppConstants.textLightColor, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          const CurvedHeader(height: 155),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Master Data Toko',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                        tooltip: 'Isi Data Dummy',
                        onPressed: () => _showSeedConfirmDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sub-menu List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildMenuCard(
                        icon: Icons.shopping_bag_rounded,
                        title: 'Daftar Produk',
                        subtitle: 'Kelola detail produk, multi-satuan & matriks harga',
                        color: AppConstants.primaryColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductsListPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMenuCard(
                        icon: Icons.category_rounded,
                        title: 'Kategori & Merek',
                        subtitle: 'Atur kategori pengelompokan produk & brand pabrikan',
                        color: AppConstants.successColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CategoriesBrandsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMenuCard(
                        icon: Icons.people_alt_rounded,
                        title: 'Pelanggan & Pemasok',
                        subtitle: 'Kelola profil pelanggan & supplier/pemasok barang',
                        color: AppConstants.warningColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ContactsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMenuCard(
                        icon: Icons.warehouse_rounded,
                        title: 'Stok & Opname',
                        subtitle: 'Penyesuaian stok produk & riwayat mutasi barang',
                        color: const Color(0xFF7C3AED),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StockOpnamePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildMenuCard(
                        icon: Icons.compare_arrows_rounded,
                        title: 'Stok Masuk / Keluar',
                        subtitle: 'Tambah atau kurangi stok secara manual',
                        color: const Color(0xFF0891B2),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StockAdjustmentPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
