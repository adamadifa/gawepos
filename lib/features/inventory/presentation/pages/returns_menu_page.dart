import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../data/return_repository.dart';
import '../bloc/return_cubit.dart';
import 'return_form_page.dart';

class ReturnsMenuPage extends StatefulWidget {
  const ReturnsMenuPage({super.key});

  @override
  State<ReturnsMenuPage> createState() => _ReturnsMenuPageState();
}

class _ReturnsMenuPageState extends State<ReturnsMenuPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
    context.read<ReturnCubit>().loadReturnHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retur Barang',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kelola retur penjualan pembeli & retur ke supplier',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: BlocListener<ReturnCubit, ReturnState>(
        listener: (context, state) {
          if (state is ReturnSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontSize: 12.5))),
                  ],
                ),
                backgroundColor: AppConstants.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else if (state is ReturnError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message, style: GoogleFonts.poppins(fontSize: 12.5))),
                  ],
                ),
                backgroundColor: AppConstants.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        child: BlocBuilder<ReturnCubit, ReturnState>(
          builder: (context, state) {
            if (state is ReturnLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
            }

            if (state is ReturnError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      Text(state.message, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: const Color(0xFFDC2626))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<ReturnCubit>().loadReturnHistory(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                        child: Text('Coba Lagi', style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is ReturnHistoryLoaded) {
              final salesList = state.salesReturns;
              final purchaseList = state.purchaseReturns;

              // Calculate metrics
              double totalSalesRefund = 0;
              for (var row in salesList) {
                final SalesReturn r = row['return'];
                totalSalesRefund += r.refundAmount;
              }

              double totalPurchaseRefund = 0;
              for (var row in purchaseList) {
                final PurchaseReturn r = row['return'];
                totalPurchaseRefund += r.refundAmount;
              }

              return Column(
                children: [
                  // ─── 1. METRIC SUMMARY CARDS ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        // Retur Penjualan Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
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
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFDC2626), size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Retur Penjualan',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  CurrencyFormatter.format(totalSalesRefund),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFDC2626),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${salesList.length} transaksi retur',
                                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Retur Pembelian Card
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
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
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0D9488), size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Retur Pembelian',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  CurrencyFormatter.format(totalPurchaseRefund),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0D9488),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${purchaseList.length} transaksi retur',
                                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── 2. SEARCH BAR & SEGMENTED TABS ──────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // Search Field
                        TextField(
                          controller: _searchController,
                          style: GoogleFonts.poppins(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'Cari no. retur, nama, atau no. invoice...',
                            hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            filled: true,
                            fillColor: Colors.white,
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
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Segmented Tab Bar
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _tabController.animateTo(0)),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 0 ? const Color(0xFF0F172A) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _tabController.index == 0
                                          ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.assignment_return_rounded,
                                          size: 15,
                                          color: _tabController.index == 0 ? Colors.white : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Retur Penjualan (${salesList.length})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: _tabController.index == 0 ? FontWeight.w700 : FontWeight.w500,
                                            color: _tabController.index == 0 ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _tabController.animateTo(1)),
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 1 ? const Color(0xFF0F172A) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _tabController.index == 1
                                          ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.local_shipping_rounded,
                                          size: 15,
                                          color: _tabController.index == 1 ? Colors.white : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Retur Pembelian (${purchaseList.length})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: _tabController.index == 1 ? FontWeight.w700 : FontWeight.w500,
                                            color: _tabController.index == 1 ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
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

                  // ─── 3. TAB VIEW LISTS ───────────────────────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSalesReturnsList(salesList),
                        _buildPurchaseReturnsList(purchaseList),
                      ],
                    ),
                  ),
                ],
              );
            }

            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final returnCubit = context.read<ReturnCubit>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReturnFormPage(
                initialIsSales: _tabController.index == 0,
              ),
            ),
          ).then((value) {
            returnCubit.loadReturnHistory();
          });
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'BUAT RETUR BARU',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _buildSalesReturnsList(List<Map<String, dynamic>> list) {
    final filtered = list.where((row) {
      if (_searchQuery.isEmpty) return true;
      final SalesReturn ret = row['return'];
      final Customer? customer = row['customer'];
      final Order? order = row['order'];

      final ref = ret.referenceNo.toLowerCase();
      final custName = (customer?.name ?? 'pelanggan umum').toLowerCase();
      final orderRef = (order?.referenceNo ?? '').toLowerCase();

      return ref.contains(_searchQuery) || custName.contains(_searchQuery) || orderRef.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'Tidak ada retur penjualan yang cocok.' : 'Belum ada riwayat transaksi retur penjualan.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final row = filtered[index];
        final SalesReturn ret = row['return'];
        final Customer? customer = row['customer'];
        final Order? order = row['order'];

        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt);
        final isCash = ret.refundMethod == 'cash';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showSalesReturnDetailsSheet(ret.id),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Ref & Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ret.referenceNo,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: const Color(0xFF1A56DB),
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Middle Row: Contact & Nominal
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                          child: Text(
                            (customer?.name.isNotEmpty == true) ? customer!.name[0].toUpperCase() : 'P',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF1A56DB), fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer?.name ?? 'Pelanggan Umum',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                order != null ? 'Ref: ${order.referenceNo}' : 'Retur Umum (Bebas)',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(ret.refundAmount),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isCash
                                    ? const Color(0xFF059669).withValues(alpha: 0.1)
                                    : const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCash ? 'Tunai' : 'Potong Piutang',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isCash ? const Color(0xFF059669) : const Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseReturnsList(List<Map<String, dynamic>> list) {
    final filtered = list.where((row) {
      if (_searchQuery.isEmpty) return true;
      final PurchaseReturn ret = row['return'];
      final Supplier? supplier = row['supplier'];
      final Purchase? purchase = row['purchase'];

      final ref = ret.referenceNo.toLowerCase();
      final supName = (supplier?.name ?? 'supplier').toLowerCase();
      final purRef = (purchase?.referenceNo ?? '').toLowerCase();

      return ref.contains(_searchQuery) || supName.contains(_searchQuery) || purRef.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'Tidak ada retur pembelian yang cocok.' : 'Belum ada riwayat transaksi retur pembelian.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final row = filtered[index];
        final PurchaseReturn ret = row['return'];
        final Supplier? supplier = row['supplier'];
        final Purchase? purchase = row['purchase'];

        final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ret.createdAt);
        final isCash = ret.refundMethod == 'cash';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showPurchaseReturnDetailsSheet(ret.id),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Ref & Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ret.referenceNo,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Middle Row: Supplier & Nominal
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          child: Text(
                            (supplier?.name.isNotEmpty == true) ? supplier!.name[0].toUpperCase() : 'S',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF0D9488), fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier?.name ?? 'Supplier / Pemasok',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                purchase != null ? 'Ref: ${purchase.referenceNo}' : 'Retur Umum (Bebas)',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(ret.refundAmount),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isCash
                                    ? const Color(0xFF059669).withValues(alpha: 0.1)
                                    : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCash ? 'Tunai' : 'Potong Hutang',
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isCash ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_return_outlined, size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSalesReturnDetailsSheet(int id) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: getIt<ReturnRepository>().getSalesReturnDetails(id),
          builder: (fbCtx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(40),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Data tidak ditemukan.', style: GoogleFonts.poppins())),
              );
            }

            final SalesReturn ret = data['return'];
            final Customer? customer = data['customer'];
            final Order? order = data['order'];
            final List<Map<String, dynamic>> items = data['items'];

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.92,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rincian Retur Penjualan',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                ret.referenceNo,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1A56DB)),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      // Meta Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildMetaRow('Tanggal Retur', DateFormat('dd MMMM yyyy, HH:mm').format(ret.createdAt)),
                            _buildMetaRow('Pelanggan', customer?.name ?? 'Pelanggan Umum'),
                            _buildMetaRow('Invoice Asal', order?.referenceNo ?? 'Retur Umum (Bebas)'),
                            _buildMetaRow('Metode Refund', ret.refundMethod == 'cash' ? 'Uang Tunai (Cash)' : 'Potong Piutang (Bon)'),
                            if (ret.notes != null && ret.notes!.isNotEmpty)
                              _buildMetaRow('Alasan / Catatan', ret.notes!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Barang yang Diretur (${items.length}):',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      ...items.map((itemRow) {
                        final SalesReturnItem item = itemRow['item'];
                        final Product? product = itemRow['product'];
                        final ProductUnit? unit = itemRow['unit'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
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
                                      product?.name ?? 'Produk',
                                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.price)}',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      // Total Refund
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Refund Pengembalian', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          Text(
                            CurrencyFormatter.format(ret.refundAmount),
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmVoidSalesReturn(context, ret);
                        },
                        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                        label: Text(
                          'BATALKAN TRANSAKSI RETUR',
                          style: GoogleFonts.poppins(color: const Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPurchaseReturnDetailsSheet(int id) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: getIt<ReturnRepository>().getPurchaseReturnDetails(id),
          builder: (fbCtx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(40),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Data tidak ditemukan.', style: GoogleFonts.poppins())),
              );
            }

            final PurchaseReturn ret = data['return'];
            final Supplier? supplier = data['supplier'];
            final Purchase? purchase = data['purchase'];
            final List<Map<String, dynamic>> items = data['items'];

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.92,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rincian Retur Pembelian',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                ret.referenceNo,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),

                      // Meta Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildMetaRow('Tanggal Retur', DateFormat('dd MMMM yyyy, HH:mm').format(ret.createdAt)),
                            _buildMetaRow('Supplier / Pemasok', supplier?.name ?? 'Pemasok'),
                            _buildMetaRow('PO Pembelian Asal', purchase?.referenceNo ?? 'Retur Umum (Bebas)'),
                            _buildMetaRow('Metode Refund', ret.refundMethod == 'cash' ? 'Uang Tunai (Cash)' : 'Potong Hutang Dagang'),
                            if (ret.notes != null && ret.notes!.isNotEmpty)
                              _buildMetaRow('Alasan / Catatan', ret.notes!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Barang yang Diretur (${items.length}):',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      ...items.map((itemRow) {
                        final PurchaseReturnItem item = itemRow['item'];
                        final Product? product = itemRow['product'];
                        final ProductUnit? unit = itemRow['unit'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
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
                                      product?.name ?? 'Produk',
                                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      '${item.quantity.toString().replaceAll(RegExp(r'\.0$'), '')} ${unit?.name ?? ""} x ${CurrencyFormatter.format(item.costPrice)}',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      // Total Refund
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Refund / Potongan', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          Text(
                            CurrencyFormatter.format(ret.refundAmount),
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmVoidPurchaseReturn(context, ret);
                        },
                        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                        label: Text(
                          'BATALKAN TRANSAKSI RETUR',
                          style: GoogleFonts.poppins(color: const Color(0xFFDC2626), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
          ),
          const Text(': ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmVoidSalesReturn(BuildContext context, SalesReturn ret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Batalkan Retur Penjualan?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFFDC2626)),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi retur ${ret.referenceNo}? Stok produk akan dikurangi kembali dan piutang pelanggan akan dipulihkan jika sebelumnya dipotong.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('TIDAK', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ReturnCubit>().voidSalesReturn(ret.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('YA, BATALKAN', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _confirmVoidPurchaseReturn(BuildContext context, PurchaseReturn ret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Batalkan Retur Pembelian?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFFDC2626)),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan transaksi retur ${ret.referenceNo}? Stok produk akan ditambahkan kembali ke inventori dan hutang ke supplier akan dipulihkan.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('TIDAK', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ReturnCubit>().voidPurchaseReturn(ret.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('YA, BATALKAN', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
