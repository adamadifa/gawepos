import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/reports_cubit.dart';

class ProductAnalysisReportPage extends StatefulWidget {
  const ProductAnalysisReportPage({super.key});

  @override
  State<ProductAnalysisReportPage> createState() => _ProductAnalysisReportPageState();
}

class _ProductAnalysisReportPageState extends State<ProductAnalysisReportPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateDateRange();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    context.read<ReportsCubit>().loadProductAnalysisReport(_startDate, _endDate);
  }

  void _updateDateRange() {
    final now = DateTime.now();
    if (_selectedRange == 'Hari Ini') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedRange == '7 Hari Terakhir') {
      _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedRange == 'Bulan Ini') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  Widget _buildPeriodFilter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periode Laporan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppConstants.textLightColor,
                ),
              ),
              Text(
                '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Kustom'].map((range) {
              final isSelected = _selectedRange == range;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () async {
                      if (range == 'Kustom') {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(
                            start: _startDate,
                            end: _endDate,
                          ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppConstants.primaryColor,
                                  onPrimary: Colors.white,
                                  onSurface: AppConstants.textDarkColor,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppConstants.primaryColor,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedRange = 'Kustom';
                            _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
                            _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
                          });
                          _loadData();
                        }
                      } else {
                        setState(() {
                          _selectedRange = range;
                        });
                        _updateDateRange();
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.primaryColor : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppConstants.primaryColor.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          range,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppConstants.textDarkColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(int bestCount, int slowCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.star_rounded, color: Colors.amber.shade800, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Produk Terlaris',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$bestCount Produk',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade600, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tidak Laku',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$slowCount Produk',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellersTab(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _buildEmptyState('Tidak ada data produk terlaris di periode ini.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final row = list[index];
        final Product product = row['product'];
        final ProductUnit unit = row['unit'];
        final double quantity = row['quantity'];
        final double revenue = row['revenue'];

        final rank = index + 1;
        final isTop3 = rank <= 3;
        Color rankColor = Colors.grey.shade400;

        if (rank == 1) {
          rankColor = const Color(0xFFD4AF37); // Gold
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Silver
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Bronze
        }

        final qtyStr = quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConstants.borderLightColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isTop3 ? rankColor : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isTop3 ? rankColor.withValues(alpha: 0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTop3 ? rankColor.withValues(alpha: 0.3) : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isTop3 ? rankColor : AppConstants.textLightColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Product Image
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.borderLightColor),
                    ),
                    child: product.imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(product.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.shopping_bag_outlined,
                                      color: AppConstants.textLightColor, size: 18),
                            ),
                          )
                        : const Icon(Icons.shopping_bag_outlined,
                            color: AppConstants.textLightColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$qtyStr ${unit.name} Terjual',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(revenue),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Omzet Bersih',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: AppConstants.textLightColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlowSellersTab(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _buildEmptyState('Luar biasa! Semua produk Anda laku terjual di periode ini.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final row = list[index];
        final Product product = row['product'];
        final ProductUnit unit = row['unit'];
        final double currentStock = row['currentStock'];

        final stockStr = currentStock.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
        final hasStockValue = currentStock > 0;
        final accentColor = hasStockValue ? Colors.orange.shade600 : Colors.grey.shade400;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConstants.borderLightColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Product Image instead of warning icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppConstants.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConstants.borderLightColor),
                    ),
                    child: product.imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(product.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.shopping_bag_outlined,
                                      color: AppConstants.textLightColor, size: 18),
                            ),
                          )
                        : const Icon(Icons.shopping_bag_outlined,
                            color: AppConstants.textLightColor, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Text(
                                '0 Terjual',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasStockValue ? Colors.orange.shade50 : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hasStockValue ? Colors.orange.shade200 : Colors.grey.shade200,
                                ),
                              ),
                              child: Text(
                                hasStockValue ? 'Stok Mengendap: $stockStr ${unit.name}' : 'Stok Kosong',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: hasStockValue ? Colors.orange.shade900 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Analisis Produk',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          final data = state.productAnalysisData ?? {};
          final bestSellers = data['bestSellers'] ?? [];
          final slowSellers = data['slowSellers'] ?? [];

          return Column(
            children: [
              _buildPeriodFilter(),
              _buildSummaryCards(bestSellers.length, slowSellers.length),
              const SizedBox(height: 6),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppConstants.primaryColor,
                  unselectedLabelColor: AppConstants.textLightColor,
                  indicatorColor: AppConstants.primaryColor,
                  labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                  tabs: const [
                    Tab(text: 'Produk Terlaris'),
                    Tab(text: 'Produk Tidak Laku'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppConstants.borderLightColor),
              Expanded(
                child: state.isProductAnalysisLoading && state.productAnalysisData == null
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBestSellersTab(bestSellers),
                          _buildSlowSellersTab(slowSellers),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
