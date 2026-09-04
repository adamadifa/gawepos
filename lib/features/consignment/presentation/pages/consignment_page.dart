import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/consignment_repository.dart';
import '../bloc/consignment_cubit.dart';
import 'create_settlement_page.dart';
import 'settlement_detail_page.dart';

class ConsignmentPage extends StatefulWidget {
  const ConsignmentPage({super.key});

  @override
  State<ConsignmentPage> createState() => _ConsignmentPageState();
}

class _ConsignmentPageState extends State<ConsignmentPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ConsignmentCubit>().loadOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAppSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppConstants.errorColor : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Konsinyasi & Titip Jual',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: BlocConsumer<ConsignmentCubit, ConsignmentState>(
        listener: (context, state) {
          if (state is ConsignmentError) {
            _showAppSnackbar(state.message, isError: true);
          }
        },
        builder: (context, state) {
          if (state is ConsignmentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ConsignmentOverviewLoaded) {
            return RefreshIndicator(
              onRefresh: () => context.read<ConsignmentCubit>().loadOverview(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // 1. Executive Metric Summary Cards
                  _buildMetricCards(state),
                  const SizedBox(height: 16),

                  // 2. Search Bar
                  _buildSearchBar(),
                  const SizedBox(height: 16),

                  // 3. Segmented Tab Selector
                  _buildSegmentedTab(),
                  const SizedBox(height: 16),

                  // 4. Tab Content View
                  if (_tabController.index == 0)
                    _buildSuppliersTab(state.summaries)
                  else if (_tabController.index == 1)
                    _buildSettlementsTab(state.settlements)
                  else
                    _buildStockTab(state.stockReport),
                ],
              ),
            );
          }

          return Center(
            child: Text(
              'Belum ada data konsinyasi',
              style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
            ),
          );
        },
      ),
    );
  }

  // 1. Metric Header
  Widget _buildMetricCards(ConsignmentOverviewLoaded state) {
    return Row(
      children: [
        // Card Hak Bayar Penitip
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFDC2626), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Belum Disetor',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(state.totalUnsettledPayable),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                Text(
                  '${state.totalActiveSuppliers} Mitra Aktif',
                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Card Potensi Komisi Toko
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.savings_outlined, color: Color(0xFF16A34A), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Komisi Toko',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(state.totalStoreCommission),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                Text(
                  'Estimasi Margin',
                  style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Search Field
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Cari mitra, produk, atau no faktur...',
          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // 3. Segmented Tab Selector
  Widget _buildSegmentedTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(index: 0, label: 'Mitra Penitip', icon: Icons.storefront_outlined),
          _buildTabButton(index: 1, label: 'Settlement', icon: Icons.receipt_long_outlined),
          _buildTabButton(index: 2, label: 'Stok Titipan', icon: Icons.inventory_2_outlined),
        ],
      ),
    );
  }

  Widget _buildTabButton({required int index, required String label, required IconData icon}) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tabController.index = index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Tab 1: Mitra Penitip
  Widget _buildSuppliersTab(List<ConsignmentSupplierSummary> summaries) {
    final filtered = summaries.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.supplier.name.toLowerCase().contains(_searchQuery) ||
          (s.supplier.phone ?? '').contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.storefront_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Belum ada mitra konsinyasi terdaftar',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tandai produk sebagai Konsinyasi pada menu Master Produk',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: filtered.map((summary) {
        final supplier = summary.supplier;
        final hasUnsettled = summary.unsettledSupplierPayable > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'M',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (supplier.phone != null && supplier.phone!.isNotEmpty)
                          Text(
                            supplier.phone!,
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${summary.totalProducts} SKU Produk',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sisa Stok Fisik',
                            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
                          ),
                          Text(
                            '${summary.totalPhysicalStock.toInt()} Unit',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terjual Belum Disetor',
                            style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
                          ),
                          Text(
                            CurrencyFormatter.format(summary.unsettledSupplierPayable),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: hasUnsettled ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: hasUnsettled
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateSettlementPage(supplier: supplier),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: Text(
                    hasUnsettled ? 'Buat Lembar Settlement' : 'Semua Tagihan Sudah Selesai',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 5. Tab 2: Riwayat Settlement
  Widget _buildSettlementsTab(List<Map<String, dynamic>> settlements) {
    final filtered = settlements.where((s) {
      if (_searchQuery.isEmpty) return true;
      final settlement = s['settlement'] as ConsignmentSettlement;
      final supplier = s['supplier'] as Supplier;
      return settlement.settlementNo.toLowerCase().contains(_searchQuery) ||
          supplier.name.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Belum ada riwayat settlement',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Column(
      children: filtered.map((row) {
        final settlement = row['settlement'] as ConsignmentSettlement;
        final supplier = row['supplier'] as Supplier;

        final isPaid = settlement.paymentStatus == 'paid';
        final isPartial = settlement.paymentStatus == 'partial';

        final statusColor = isPaid
            ? const Color(0xFF16A34A)
            : (isPartial ? const Color(0xFFD97706) : const Color(0xFFDC2626));
        final statusBg = isPaid
            ? const Color(0xFFDCFCE7)
            : (isPartial ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));
        final statusText = isPaid ? 'Lunas' : (isPartial ? 'Sebagian' : 'Belum Dibayar');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettlementDetailPage(settlementId: settlement.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        settlement.settlementNo,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mitra: ${supplier.name}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  ),
                  Text(
                    dateFormat.format(settlement.createdAt),
                    style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                  ),
                  const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Barang Terjual', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                          Text('${settlement.totalSoldQty.toInt()} Item', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Hak Bayar Penitip', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B))),
                          Text(
                            CurrencyFormatter.format(settlement.supplierPayableAmount),
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 6. Tab 3: Monitoring Stok Titipan
  Widget _buildStockTab(List<Map<String, dynamic>> stockReport) {
    final filtered = stockReport.where((s) {
      if (_searchQuery.isEmpty) return true;
      final product = s['product'] as Product;
      final supplier = s['supplier'] as Supplier;
      return product.name.toLowerCase().contains(_searchQuery) ||
          supplier.name.toLowerCase().contains(_searchQuery) ||
          (product.sku ?? '').toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'Belum ada produk konsinyasi',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filtered.map((row) {
        final Product product = row['product'] as Product;
        final Supplier supplier = row['supplier'] as Supplier;
        final InventoryData? inventory = row['inventory'] as InventoryData?;
        final double stockQty = inventory != null ? inventory.quantity : 0.0;

        final isFixed = product.consignmentType == 'fixed_cost';
        final schemeText = isFixed
            ? 'Setor: ${CurrencyFormatter.format(product.commissionRate)}/pcs'
            : 'Komisi Toko: ${product.commissionRate.toStringAsFixed(0)}%';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded, color: Color(0xFF475569), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Mitra: ${supplier.name}',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        schemeText,
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sisa Fisik', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
                  Text(
                    '${stockQty.toInt()} Pcs',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: stockQty <= (product.minStockAlert) ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
