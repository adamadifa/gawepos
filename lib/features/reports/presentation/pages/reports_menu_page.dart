import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'owner_dashboard_page.dart';
import '../../../consignment/presentation/pages/consignment_page.dart';

class ReportsMenuPage extends StatefulWidget {
  const ReportsMenuPage({super.key});

  @override
  State<ReportsMenuPage> createState() => _ReportsMenuPageState();
}

class _ReportsMenuPageState extends State<ReportsMenuPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';

  final List<String> _categories = [
    'Semua',
    'Finansial',
    'Operasional',
    'Inventori & Produk',
  ];

  final List<Map<String, dynamic>> _reportMenus = [
    {
      'title': 'Dashboard Eksekutif',
      'desc': 'Visualisasi komprehensif metrik penjualan, tren grafik, margin, dan ringkasan kas.',
      'icon': Icons.dashboard_outlined,
      'category': 'Finansial',
      'tag': 'Populer',
      'color': const Color(0xFF2563EB), // Royal Blue
      'page': const OwnerDashboardPage(),
    },
    {
      'title': 'Laba Rugi (P&L)',
      'desc': 'Rincian omzet penjualan bersih, HPP, beban operasional, dan net profit usaha.',
      'icon': Icons.analytics_outlined,
      'category': 'Finansial',
      'tag': 'Utama',
      'color': const Color(0xFF0D9488), // Teal 600
      'page': const PnlReportPage(),
    },
    {
      'title': 'Hutang & Piutang',
      'desc': 'Monitoring saldo piutang customer dan tagihan hutang ke supplier berjalan.',
      'icon': Icons.account_balance_wallet_outlined,
      'category': 'Finansial',
      'tag': 'Finansial',
      'color': const Color(0xFF9333EA), // Purple 600
      'page': const DebtsReceivablesReportPage(),
    },
    {
      'title': 'Laporan Penjualan',
      'desc': 'Rekap data riwayat transaksi kasir, detail per produk, dan ringkasan metode bayar.',
      'icon': Icons.receipt_long_outlined,
      'category': 'Operasional',
      'tag': 'Harian',
      'color': const Color(0xFF0284C7), // Sky 600
      'page': const SalesReportPage(),
    },
    {
      'title': 'Laporan Pembelian',
      'desc': 'Histori restok barang supplier, data tagihan PO, dan akumulasi nilai belanja.',
      'icon': Icons.shopping_bag_outlined,
      'category': 'Operasional',
      'tag': 'Supplier',
      'color': const Color(0xFF4F46E5), // Indigo 600
      'page': const PurchaseReportPage(),
    },
    {
      'title': 'Analisis Produk',
      'desc': 'Peringkat produk terlaris (Top Selling) serta produk minim pergerakan (Slow Moving).',
      'icon': Icons.insights_outlined,
      'category': 'Inventori & Produk',
      'tag': 'Analitik',
      'color': const Color(0xFFD97706), // Amber 600
      'page': const ProductAnalysisReportPage(),
    },
    {
      'title': 'Laporan & Kartu Stok',
      'desc': 'Kuantitas stok real-time, alert minimum limit stok, dan riwayat mutasi kartu stok.',
      'icon': Icons.inventory_2_outlined,
      'category': 'Inventori & Produk',
      'tag': 'Stok',
      'color': const Color(0xFF059669), // Emerald 600
      'page': const StockReportPage(),
    },
    {
      'title': 'Retur Barang',
      'desc': 'Laporan pengembalian barang penjualan pelanggan dan retur pembelian supplier.',
      'icon': Icons.swap_horizontal_circle_outlined,
      'category': 'Inventori & Produk',
      'tag': 'Retur',
      'color': const Color(0xFFEA580C), // Orange 600
      'page': const ReturnReportPage(),
    },
    {
      'title': 'Shift & Kas Kasir',
      'desc': 'Rekap buka/tutup kasir per shift, estimasi kas laci, dan pencatatan selisih kas.',
      'icon': Icons.history_toggle_off_rounded,
      'category': 'Operasional',
      'tag': 'Kasir',
      'color': const Color(0xFF6366F1), // Indigo Accent
      'page': const ShiftReportPage(),
    },
    {
      'title': 'Biaya & Pengeluaran',
      'desc': 'Catatan beban operasional outlet, maintenance, dan pengeluaran kas non-transaksi.',
      'icon': Icons.outbox_rounded,
      'category': 'Finansial',
      'tag': 'Beban',
      'color': const Color(0xFFDC2626), // Rose Red
      'page': const ExpensesReportPage(),
    },
    {
      'title': 'Poin & Loyalitas',
      'desc': 'Histori perolehan dan penukaran saldo poin reward loyalitas pelanggan.',
      'icon': Icons.card_giftcard_rounded,
      'category': 'Operasional',
      'tag': 'Reward',
      'color': const Color(0xFFCA8A04), // Yellow Ochre
      'page': const PointsReportPage(),
    },
    {
      'title': 'Konsinyasi (Titip Jual)',
      'desc': 'Rekonsiliasi barang titipan mitra/supplier, komisi toko, dan pelunasan bagi hasil.',
      'icon': Icons.handshake_outlined,
      'category': 'Finansial',
      'tag': 'Mitra',
      'color': const Color(0xFF16A34A), // Emerald 600
      'page': const ConsignmentPage(),
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredMenus {
    return _reportMenus.where((m) {
      final matchesCat = _selectedCategory == 'Semua' || m['category'] == _selectedCategory;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          (m['title'] as String).toLowerCase().contains(q) ||
          (m['desc'] as String).toLowerCase().contains(q) ||
          (m['tag'] as String).toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();
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
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pusat Laporan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Analitik, Keuangan & Inventori Usaha',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 44,
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
                      hintText: 'Cari modul laporan...',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
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
                const SizedBox(height: 12),
                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Report List
          Expanded(
            child: _filteredMenus.isEmpty
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
                          child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Laporan tidak ditemukan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coba kata kunci pencarian atau kategori lain',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMenus.length,
                    itemBuilder: (context, index) {
                      final menu = _filteredMenus[index];
                      final Color menuColor = menu['color'] as Color;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => menu['page']),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: menuColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      menu['icon'] as IconData,
                                      color: menuColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Texts & Tag
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                menu['title'] as String,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: menuColor.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                menu['tag'] as String,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: menuColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          menu['desc'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            height: 1.35,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Chevron
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

