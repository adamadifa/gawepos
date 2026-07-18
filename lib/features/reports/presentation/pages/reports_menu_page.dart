import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import 'pnl_report_page.dart';
import 'shift_report_page.dart';
import 'sales_report_page.dart';
import 'expenses_report_page.dart';
import 'stock_report_page.dart';
import 'purchase_report_page.dart';
import 'debts_receivables_report_page.dart';
import 'return_report_page.dart';
import 'points_report_page.dart';
import 'product_analysis_report_page.dart';

class ReportsMenuPage extends StatelessWidget {
  const ReportsMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    // List menu laporan
    final List<Map<String, dynamic>> reportMenus = [
      {
        'title': 'Laba Rugi',
        'desc': 'Rincian omzet penjualan bersih, HPP, biaya operasional, dan laba/rugi bersih usaha.',
        'icon': Icons.analytics_outlined,
        'color': AppConstants.primaryColor,
        'page': const PnlReportPage(),
      },
      {
        'title': 'Hutang & Piutang',
        'desc': 'Rincian saldo piutang pelanggan dan tagihan hutang supplier berjalan beserta statusnya.',
        'icon': Icons.payment_outlined,
        'color': Colors.purple,
        'page': const DebtsReceivablesReportPage(),
      },
      {
        'title': 'Penjualan',
        'desc': 'Rekap data transaksi kasir, detail penjualan per produk, serta ringkasan pelanggan.',
        'icon': Icons.trending_up_rounded,
        'color': Colors.teal,
        'page': const SalesReportPage(),
      },
      {
        'title': 'Pembelian',
        'desc': 'Laporan restok barang dari supplier, data tagihan transaksi, dan rekap pembelian barang.',
        'icon': Icons.shopping_bag_outlined,
        'color': Colors.blueAccent,
        'page': const PurchaseReportPage(),
      },
      {
        'title': 'Analisis Produk',
        'desc': 'Peringkat produk terlaris berdasarkan penjualan serta produk yang kurang laku terjual.',
        'icon': Icons.star_outline_rounded,
        'color': Colors.amber.shade800,
        'page': const ProductAnalysisReportPage(),
      },
      {
        'title': 'Retur Barang',
        'desc': 'Laporan pengembalian barang dari pelanggan (penjualan) dan pengembalian barang ke supplier (pembelian).',
        'icon': Icons.swap_horizontal_circle_outlined,
        'color': Colors.deepOrange,
        'page': const ReturnReportPage(),
      },
      {
        'title': 'Laporan & Kartu Stok',
        'desc': 'Status kuantitas stok berjalan semua produk, limit minimum stok, dan histori mutasi barang.',
        'icon': Icons.inventory_2_outlined,
        'color': Colors.indigo,
        'page': const StockReportPage(),
      },
      {
        'title': 'Shift Kasir',
        'desc': 'Riwayat pembukaan & penutupan kas laci, estimasi nominal kas, dan pencatatan selisih kas.',
        'icon': Icons.history_toggle_off_rounded,
        'color': Colors.orange.shade700,
        'page': const ShiftReportPage(),
      },
      {
        'title': 'Biaya / Pengeluaran',
        'desc': 'Catatan pengeluaran operasional outlet dan biaya lain-lain di luar transaksi.',
        'icon': Icons.outbox_rounded,
        'color': AppConstants.errorColor,
        'page': const ExpensesReportPage(),
      },
      {
        'title': 'Poin Pelanggan',
        'desc': 'Riwayat perolehan & penukaran poin pelanggan.',
        'icon': Icons.card_giftcard_rounded,
        'color': Colors.orange,
        'page': const PointsReportPage(),
      },
    ];

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Laporan Keuangan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Pilih Laporan Usaha',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppConstants.textDarkColor,
              ),
            ),
          ),
          ...reportMenus.map((menu) {
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppConstants.borderLightColor),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => menu['page']),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (menu['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          menu['icon'] as IconData,
                          color: menu['color'] as Color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              menu['title'] as String,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppConstants.textDarkColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              menu['desc'] as String,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppConstants.textLightColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
