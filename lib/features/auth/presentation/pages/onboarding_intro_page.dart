import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../bloc/auth_cubit.dart';

class OnboardingIntroPage extends StatefulWidget {
  const OnboardingIntroPage({super.key});

  @override
  State<OnboardingIntroPage> createState() => _OnboardingIntroPageState();
}

class _OnboardingIntroPageState extends State<OnboardingIntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _IntroSlide(
      icon: Icons.point_of_sale_rounded,
      badge: 'Kasir Mandiri',
      title: 'Transaksi Kasir Cepat & Praktis',
      description:
          'Catat transaksi penjualan kasir dalam hitungan detik. Mendukung multi-pembayaran: Tunai, QRIS, Kartu, dan Hutang.',
      color: Color(0xFF0F172A),
    ),
    _IntroSlide(
      icon: Icons.inventory_2_outlined,
      badge: 'Manajemen Stok',
      title: 'Pantau Stok Real-Time & Mutasi',
      description:
          'Lacak histori kartu stok produk, peringatan batas minimum stok, opname berkala, dan retur barang secara akurat.',
      color: Color(0xFF0D9488), // Teal
    ),
    _IntroSlide(
      icon: Icons.auto_graph_rounded,
      badge: 'Laporan Keuangan',
      title: 'Analitik Laba Rugi & Performa Bisnis',
      description:
          'Pantau omzet bersih, margin laba kotor hingga laba bersih usaha, rekap shift kasir, dan ekspor laporan PDF instan.',
      color: Color(0xFF7C3AED), // Violet
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _complete() {
    context.read<AuthCubit>().completeIntro();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF0F172A),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'GawePOS',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _complete,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'Lewati',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, index) {
                  final s = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Clean Rounded Icon Box
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: s.color.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              s.icon,
                              color: s.color,
                              size: 52,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: s.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            s.badge,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: s.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          s.title,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          s.description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _currentPage == _slides.length - 1
                          ? _complete
                          : _nextPage,
                      child: Text(
                        _currentPage == _slides.length - 1
                            ? 'MULAI SEKARANG'
                            : 'LANJUT',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
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

class _IntroSlide {
  final IconData icon;
  final String badge;
  final String title;
  final String description;
  final Color color;

  const _IntroSlide({
    required this.icon,
    required this.badge,
    required this.title,
    required this.description,
    required this.color,
  });
}
