import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/master_repository.dart';
import '../../../pos/data/sales_repository.dart';
import 'categories_brands_page.dart';
import 'contacts_page.dart';
import 'products_list_page.dart';
import 'raw_materials_page.dart';
import '../../../inventory/presentation/pages/stock_opname_page.dart';
import '../../../inventory/presentation/pages/stock_adjustment_page.dart';
import '../../../consignment/presentation/pages/consignment_page.dart';

class MasterMenuPage extends StatefulWidget {
  const MasterMenuPage({super.key});

  @override
  State<MasterMenuPage> createState() => _MasterMenuPageState();
}

class _MasterMenuPageState extends State<MasterMenuPage> {
  String _businessMode = 'all';

  @override
  void initState() {
    super.initState();
    _loadBusinessMode();
  }

  Future<void> _loadBusinessMode() async {
    final mode = await getIt<SalesRepository>().getSetting('business_mode');
    if (mounted) {
      setState(() {
        _businessMode = mode ?? 'all';
      });
    }
  }

  void _showSeedChoiceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0F172A), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Data Contoh & Reset Katalog',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Option 1: F&B Coffee Shop Menu with Recipes
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _startSeedingCoffeeProducts(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF78350F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.coffee_rounded, color: Color(0xFF78350F), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Menu Kedai Kopi (F&B)',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Resep BOM',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '15 Menu Minuman F&B siap kasir terhubung otomatis ke 23 Bahan Baku racikan',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Seblak Prasmanan & 19 Topping F&B
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _startSeedingSeblakProducts(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFDC2626), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Seblak Prasmanan (F&B)',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '19 Topping',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '19 Topping isian seblak (kerupuk, dumpling, ceker, mie, makaroni) & 6 bahan dapur',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Retail / Minimarket 100 Products
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _showRetailSeedConfirmDialog(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppConstants.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '100 Produk Retail / Minimarket',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sembako, snack, minuman botol, rokok, sabun, multi-satuan & harga grosir',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 3: Reset Total Master Data
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pop(ctx);
                _showResetCatalogConfirmDialog(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Bersihkan Katalog Produk',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Kosongkan semua produk & bahan baku agar data kasir kembali bersih 0',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFDC2626), size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetCatalogConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Reset Katalog Produk?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Semua daftar produk, bahan baku, resep racikan, dan saldo stok inventori akan dihapus bersih. Riwayat transaksi penjualan lama dan pengaturan toko tetap aman tersimpan.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await getIt<MasterRepository>().resetMasterCatalogData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Katalog produk dan bahan baku berhasil dibersihkan!',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: const Color(0xFF0F172A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: Text(
              'YA, BERSIHKAN SEKARANG',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRetailSeedConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppConstants.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Generate 100 Produk',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistem akan membuat 100 data produk dummy UMKM lengkap dengan:',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            _buildFeatureBullet('8 Kategori & Brand Populer (Makanan, Minuman, Sembako, dll)'),
            _buildFeatureBullet('Foto thumbnail produk otomatis'),
            _buildFeatureBullet('Multi-satuan (Pcs, Dus, Slop, Karton, dsb)'),
            _buildFeatureBullet('Harga bertingkat eceran & grosir serta stok awal'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _startSeedingWithProgress(context);
            },
            child: Text(
              'GENERATE SEKARANG',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  void _startSeedingWithProgress(BuildContext context) {
    int currentProgress = 0;
    int totalProgress = 100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat Data & Foto Produk...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentProgress dari $totalProgress produk diproses',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalProgress > 0 ? (currentProgress / totalProgress) : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Jalankan seeding
    getIt<MasterRepository>().seedDummyData(
      onProgress: (cur, tot) {
        currentProgress = cur;
        totalProgress = tot;
      },
    ).then((count) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Berhasil membuat $count produk dummy beserta foto!',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengisi data dummy: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    });
  }

  void _startSeedingCoffeeProducts(BuildContext context) {
    int currentProgress = 0;
    int totalProgress = 15;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat Menu & Resep F&B...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentProgress dari $totalProgress menu kedai kopi diproses',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalProgress > 0 ? (currentProgress / totalProgress) : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Jalankan seeding F&B
    getIt<MasterRepository>().seedCoffeeMenuProducts(
      onProgress: (cur, tot) {
        currentProgress = cur;
        totalProgress = tot;
      },
    ).then((count) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Berhasil membuat $count menu F&B lengkap dengan komposisi resep bahan baku!',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat menu F&B: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    });
  }

  void _startSeedingSeblakProducts(BuildContext context) {
    int currentProgress = 0;
    int totalProgress = 19;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat Menu & Topping Seblak...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentProgress dari $totalProgress item seblak & bahan baku diproses',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalProgress > 0 ? (currentProgress / totalProgress) : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Jalankan seeding Seblak
    getIt<MasterRepository>().seedSeblakMenuProducts(
      onProgress: (cur, tot) {
        currentProgress = cur;
        totalProgress = tot;
      },
    ).then((count) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Berhasil membuat $count topping & isian seblak prasmanan siap kasir!',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }).catchError((e) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup dialog progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat data seblak: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    });
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF94A3B8), size: 14),
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Clean Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A), size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Master Data & Produk',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showSeedChoiceDialog(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.playlist_add_rounded,
                            color: Color(0xFF334155), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE2E8F0)),

            // Sub-menu List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _buildMenuCard(
                    icon: Icons.inventory_2_rounded,
                    title: _businessMode == 'fnb' ? 'Katalog Menu F&B' : 'Daftar Produk',
                    subtitle: _businessMode == 'fnb'
                        ? 'Kelola varian rasa, ukuran minuman & harga kasir'
                        : 'Kelola katalog barang jadi & variasi harga kasir',
                    color: const Color(0xFF0F172A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProductsListPage(),
                        ),
                      );
                    },
                  ),
                  if (_businessMode != 'retail') ...[
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: Icons.eco_rounded,
                      title: 'Bahan Baku (Raw Materials)',
                      subtitle: 'Kelola bahan mentah, takaran racikan & harga modal',
                      color: const Color(0xFF059669),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RawMaterialsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.category_rounded,
                    title: 'Kategori & Merek',
                    subtitle: 'Pengelompokan jenis produk & brand pabrikan',
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoriesBrandsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Pelanggan & Pemasok',
                    subtitle: 'Data kontak pelanggan dan supplier pemasok',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.warehouse_rounded,
                    title: 'Stok & Opname',
                    subtitle: 'Penyesuaian stok produk & verifikasi fisik',
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
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.compare_arrows_rounded,
                    title: 'Stok Masuk / Keluar',
                    subtitle: 'Tambah atau kurangi stok secara manual',
                    color: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockAdjustmentPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.handshake_rounded,
                    title: 'Konsinyasi (Titip Jual)',
                    subtitle: 'Kelola mitra titip jual, settlement & komisi toko',
                    color: const Color(0xFF16A34A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConsignmentPage(),
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
    );
  }
}
