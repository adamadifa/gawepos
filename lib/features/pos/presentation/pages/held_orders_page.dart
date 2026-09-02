import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/sales_repository.dart';
import '../bloc/cart_cubit.dart';

class HeldOrdersPage extends StatefulWidget {
  final User user;
  final List<Map<String, dynamic>> allProducts;
  final List<Customer> allCustomers;

  const HeldOrdersPage({
    super.key,
    required this.user,
    required this.allProducts,
    required this.allCustomers,
  });

  @override
  State<HeldOrdersPage> createState() => _HeldOrdersPageState();
}

class _HeldOrdersPageState extends State<HeldOrdersPage> {
  final SalesRepository _salesRepository = getIt<SalesRepository>();
  List<_ParsedHeldOrder> _parsedHeldOrders = [];
  List<_ParsedHeldOrder> _filteredHeldOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHeldOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHeldOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _salesRepository.getHeldOrders(widget.user.id);
      final parsed = orders.map((o) => _parseHeldOrder(o)).toList();
      setState(() {
        _parsedHeldOrders = parsed;
        _isLoading = false;
      });
      _applyFilter();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      if (_searchQuery.trim().isEmpty) {
        _filteredHeldOrders = List.from(_parsedHeldOrders);
      } else {
        final query = _searchQuery.toLowerCase();
        _filteredHeldOrders = _parsedHeldOrders.where((parsed) {
          final refMatch = parsed.order.referenceNo.toLowerCase().contains(query);
          final custMatch = parsed.customer != null && parsed.customer!.name.toLowerCase().contains(query);
          final itemMatch = parsed.items.any((item) => item.productName.toLowerCase().contains(query));
          return refMatch || custMatch || itemMatch;
        }).toList();
      }
    });
  }

  _ParsedHeldOrder _parseHeldOrder(PosHeldOrder order) {
    try {
      final data = jsonDecode(order.cartData) as Map<String, dynamic>;
      final itemsData = (data['items'] as List<dynamic>?) ?? [];
      final globalDisc = (data['global_discount'] as num?)?.toDouble() ?? 0.0;
      final isPercentage = data['is_global_discount_percentage'] as bool? ?? false;

      Customer? customer;
      if (order.customerId != null) {
        final matches = widget.allCustomers.where((c) => c.id == order.customerId);
        if (matches.isNotEmpty) {
          customer = matches.first;
        }
      }

      final List<_ParsedHeldItem> parsedItems = [];
      double subtotal = 0.0;
      double totalQty = 0.0;

      for (var itemMap in itemsData) {
        final int productId = itemMap['product_id'] ?? 0;
        final int unitId = itemMap['unit_id'] ?? 0;
        final double qty = (itemMap['quantity'] as num?)?.toDouble() ?? 1.0;
        final double price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
        final double disc = (itemMap['discount_amount'] as num?)?.toDouble() ?? 0.0;

        String productName = 'Produk #$productId';
        String unitName = 'Pcs';

        final prodMap = widget.allProducts.firstWhere(
          (p) => (p['product'] as Product).id == productId,
          orElse: () => {},
        );

        if (prodMap.isNotEmpty) {
          final Product product = prodMap['product'];
          productName = product.name;
          final List<ProductUnit> units = List<ProductUnit>.from(prodMap['units'] ?? []);
          final matchingUnits = units.where((un) => un.id == unitId);
          if (matchingUnits.isNotEmpty) {
            unitName = matchingUnits.first.name;
          } else if (units.isNotEmpty) {
            unitName = units.first.name;
          }
        }

        final lineTotal = (price - disc) * qty;
        subtotal += lineTotal;
        totalQty += qty;

        parsedItems.add(_ParsedHeldItem(
          productId: productId,
          productName: productName,
          unitId: unitId,
          unitName: unitName,
          quantity: qty,
          price: price,
          discountAmount: disc,
          lineTotal: lineTotal,
        ));
      }

      double discountValue = 0.0;
      if (isPercentage) {
        discountValue = subtotal * (globalDisc / 100);
      } else {
        discountValue = globalDisc;
      }
      final grandTotal = (subtotal - discountValue).clamp(0.0, double.infinity);

      return _ParsedHeldOrder(
        order: order,
        customer: customer,
        totalItemCount: parsedItems.length,
        totalQuantity: totalQty,
        subtotal: subtotal,
        globalDiscount: globalDisc,
        isGlobalDiscountPercentage: isPercentage,
        grandTotal: grandTotal,
        items: parsedItems,
      );
    } catch (_) {
      return _ParsedHeldOrder(
        order: order,
        totalItemCount: 0,
        totalQuantity: 0.0,
        subtotal: 0.0,
        globalDiscount: 0.0,
        isGlobalDiscountPercentage: false,
        grandTotal: 0.0,
        items: [],
      );
    }
  }

  Future<void> _deleteHeld(int id, {bool showToast = true}) async {
    try {
      await _salesRepository.deleteHeldOrder(id);
      _loadHeldOrders();
      if (mounted && showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Transaksi ditahan berhasil dihapus.',
                  style: GoogleFonts.poppins(fontSize: 12.5),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  void _recallOrder(_ParsedHeldOrder parsed) {
    context.read<CartCubit>().recallCart(
          parsed.order,
          widget.allProducts,
          widget.allCustomers,
        );
    _deleteHeld(parsed.order.id, showToast: false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transaksi #${parsed.order.referenceNo} berhasil dimuat ke kasir!',
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmDeleteHeld(_ParsedHeldOrder parsed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Antrean Ditahan?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus antrean #${parsed.order.referenceNo}? Data keranjang belanja yang tersimpan ini akan dihapus secara permanen.',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteHeld(parsed.order.id, showToast: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Ya, Hapus',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailModal(_ParsedHeldOrder parsed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pause_circle_filled_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parsed.order.referenceNo,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(parsed.order.createdAt),
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Scrollable Items list
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer badge if any
                      if (parsed.customer != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pelanggan: ${parsed.customer!.name}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      Text(
                        'Rincian Produk (${parsed.totalItemCount} Item):',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),

                      ...parsed.items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${CurrencyFormatter.formatQty(item.quantity)} ${item.unitName} x ${CurrencyFormatter.format(item.price)}${item.discountAmount > 0 ? " (Diskon ${CurrencyFormatter.format(item.discountAmount)})" : ""}',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.lineTotal),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 14),

                      // Totals breakdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(parsed.subtotal), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ],
                      ),
                      if (parsed.globalDiscount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Diskon Global ${parsed.isGlobalDiscountPercentage ? "(${parsed.globalDiscount}%)" : ""}',
                              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFDC2626)),
                            ),
                            Text(
                              '- ${parsed.isGlobalDiscountPercentage ? CurrencyFormatter.format(parsed.subtotal * (parsed.globalDiscount / 100)) : CurrencyFormatter.format(parsed.globalDiscount)}',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Transaksi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          Text(CurrencyFormatter.format(parsed.grandTotal), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDeleteHeld(parsed);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFDC2626)),
                        label: Text(
                          'Hapus',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _recallOrder(parsed);
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          'Lanjutkan Kasir',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else if (diff.inDays == 1) {
      return 'Kemarin, ${DateFormat('HH:mm').format(dt)}';
    } else {
      return DateFormat('dd MMM, HH:mm').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalGrandTotal = _parsedHeldOrders.fold(0.0, (sum, o) => sum + o.grandTotal);
    final double totalQuantity = _parsedHeldOrders.fold(0.0, (sum, o) => sum + o.totalQuantity);
    final bool isTablet = MediaQuery.of(context).size.width > 720;

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
              'Transaksi Ditahan (Hold)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kelola antrean transaksi kasir yang disimpan sementara',
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Segarkan',
            onPressed: _loadHeldOrders,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : RefreshIndicator(
              color: const Color(0xFF0F172A),
              onRefresh: _loadHeldOrders,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // 1. Top Summary Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 24 : 16,
                        16,
                        isTablet ? 24 : 16,
                        12,
                      ),
                      child: _buildSummaryMetricsBar(
                        count: _parsedHeldOrders.length,
                        totalAmount: totalGrandTotal,
                        totalQty: totalQuantity,
                        isTablet: isTablet,
                      ),
                    ),
                  ),

                  // 2. Search & Info Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                        vertical: 4,
                      ),
                      child: _buildSearchBar(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // 3. Main Content (List or Grid)
                  if (_filteredHeldOrders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else if (isTablet)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final double availableWidth = constraints.crossAxisExtent;
                          final int crossAxisCount = availableWidth > 1100 ? 3 : 2;

                          return SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 220,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final parsed = _filteredHeldOrders[index];
                                return _buildHeldOrderCard(parsed, isTablet: true);
                              },
                              childCount: _filteredHeldOrders.length,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final parsed = _filteredHeldOrders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildHeldOrderCard(parsed, isTablet: false),
                            );
                          },
                          childCount: _filteredHeldOrders.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────
  //  TOP SUMMARY METRICS
  // ─────────────────────────────────────────
  Widget _buildSummaryMetricsBar({
    required int count,
    required double totalAmount,
    required double totalQty,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
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
      child: Row(
        children: [
          Expanded(
            child: _buildMetricItem(
              icon: Icons.pause_circle_filled_rounded,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFEF3C7),
              title: 'Antrean Ditahan',
              value: '$count Transaksi',
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildMetricItem(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              title: 'Estimasi Nilai',
              value: CurrencyFormatter.format(totalAmount),
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: _buildMetricItem(
              icon: Icons.inventory_2_rounded,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              title: 'Total Barang',
              value: '${CurrencyFormatter.formatQty(totalQty)} Item',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  SEARCH BAR
  // ─────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          _searchQuery = val;
          _applyFilter();
        },
        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Cari no. referensi, pelanggan, atau nama produk...',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    _searchController.clear();
                    _searchQuery = '';
                    _applyFilter();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  HELD ORDER CARD
  // ─────────────────────────────────────────
  Widget _buildHeldOrderCard(_ParsedHeldOrder parsed, {required bool isTablet}) {
    final order = parsed.order;
    final String timeAgo = _formatTimeAgo(order.createdAt);

    return InkWell(
      onTap: () => _showDetailModal(parsed),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row: Reference & Time badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pause_rounded, size: 16, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.referenceNo,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Customer info & Item snippet
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parsed.customer != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          parsed.customer!.name,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Item Preview Snippet
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Text(
                    parsed.items.isNotEmpty
                        ? parsed.items.take(2).map((i) => '${CurrencyFormatter.formatQty(i.quantity)}x ${i.productName}').join(', ') +
                            (parsed.items.length > 2 ? ' (+${parsed.items.length - 2} lainnya)' : '')
                        : 'Keranjang kosong',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Bottom Actions & Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${parsed.totalItemCount} Item (${CurrencyFormatter.formatQty(parsed.totalQuantity)} pcs)',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(parsed.grandTotal),
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _confirmDeleteHeld(parsed),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE4E6)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _recallOrder(parsed),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(
                        'Lanjutkan',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A), width: 2),
              ),
              child: const Center(
                child: Icon(Icons.pause_circle_outline_rounded, size: 40, color: Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? 'Tidak Ditemukan' : 'Tidak Ada Transaksi Ditahan',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Tidak ada antrean ditahan yang cocok dengan kata kunci "$_searchQuery".'
                    : 'Saat kasir menahan transaksi (Hold), data keranjang akan tersimpan di sini agar kasir dapat melayani pelanggan lain terlebih dahulu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HELPER PARSED DATA MODELS
// ─────────────────────────────────────────
class _ParsedHeldOrder {
  final PosHeldOrder order;
  final Customer? customer;
  final int totalItemCount;
  final double totalQuantity;
  final double subtotal;
  final double globalDiscount;
  final bool isGlobalDiscountPercentage;
  final double grandTotal;
  final List<_ParsedHeldItem> items;

  _ParsedHeldOrder({
    required this.order,
    this.customer,
    required this.totalItemCount,
    required this.totalQuantity,
    required this.subtotal,
    required this.globalDiscount,
    required this.isGlobalDiscountPercentage,
    required this.grandTotal,
    required this.items,
  });
}

class _ParsedHeldItem {
  final int productId;
  final String productName;
  final int unitId;
  final String unitName;
  final double quantity;
  final double price;
  final double discountAmount;
  final double lineTotal;

  _ParsedHeldItem({
    required this.productId,
    required this.productName,
    required this.unitId,
    required this.unitName,
    required this.quantity,
    required this.price,
    required this.discountAmount,
    required this.lineTotal,
  });
}
