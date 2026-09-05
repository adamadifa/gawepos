import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/inventory_cubit.dart';

class StockCardPage extends StatefulWidget {
  final Product product;
  const StockCardPage({super.key, required this.product});

  @override
  State<StockCardPage> createState() => _StockCardPageState();
}

class _StockCardPageState extends State<StockCardPage> {
  String _selectedRange = 'Hari Ini';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    _loadData();
  }

  void _loadData() {
    context.read<InventoryCubit>().loadStockCard(
          widget.product.id,
          start: _startDate,
          end: _endDate,
        );
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'sale':
        return const Color(0xFFDC2626);
      case 'purchase':
        return const Color(0xFF059669);
      case 'opname':
        return const Color(0xFF0F172A);
      case 'manual_in':
        return const Color(0xFF059669);
      case 'manual_out':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'sale':
        return 'Penjualan';
      case 'purchase':
        return 'Pembelian';
      case 'opname':
        return 'Opname';
      case 'void':
        return 'Batal Transaksi';
      case 'manual_in':
        return 'Stok Masuk';
      case 'manual_out':
        return 'Stok Keluar';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'sale':
        return Icons.call_made_rounded;
      case 'purchase':
        return Icons.call_received_rounded;
      case 'opname':
        return Icons.tune_rounded;
      case 'manual_in':
        return Icons.add_circle_outline_rounded;
      case 'manual_out':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Widget _buildPeriodFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periode Mutasi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Hari Ini', '7 Hari Terakhir', 'Bulan Ini', 'Kustom'].map((range) {
              final isSelected = _selectedRange == range;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
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
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF0F172A),
                                  onPrimary: Colors.white,
                                  onSurface: Color(0xFF0F172A),
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F172A),
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
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          range,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
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

  Widget _buildUnitTabs(List<ProductUnit> units) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PILIH SATUAN',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                final isSelected = _selectedUnitId == unit.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedUnitId = unit.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unit.name,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
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
            Row(
              children: [
                Text(
                  widget.product.productType == 'raw_material' ? 'Kartu Stok Bahan Baku' : 'Kartu Stok Barang',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.product.productType == 'raw_material'
                        ? const Color(0xFF059669).withValues(alpha: 0.1)
                        : const Color(0xFF0F172A).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.product.productType == 'raw_material' ? 'Bahan Baku' : 'Barang Jadi',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: widget.product.productType == 'raw_material'
                          ? const Color(0xFF059669)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              widget.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Periode
          _buildPeriodFilter(),

          // Movements list
          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state is InventoryLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
                }
                if (state is InventoryError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        state.message,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFDC2626)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (state is StockCardLoaded) {
                  final List<ProductUnit> units = List<ProductUnit>.from(state.units)
                    ..sort((a, b) => b.conversionFactor.compareTo(a.conversionFactor));

                  if (units.isNotEmpty && _selectedUnitId == null) {
                    _selectedUnitId = units.first.id;
                  }

                  final filteredList = state.movements.where((item) {
                    final ProductUnit unit = item['unit'];
                    return unit.id == _selectedUnitId;
                  }).toList();

                  return Column(
                    children: [
                      if (units.isNotEmpty) ...[
                        _buildUnitTabs(units),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ],
                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFF0F172A),
                          onRefresh: () async {
                            _loadData();
                          },
                          child: filteredList.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.5,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.history_rounded,
                                                size: 36, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Belum ada riwayat mutasi stok untuk satuan ini.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                                color: const Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredList.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredList[index];
                                    final StockMovement move = item['movement'];
                                    final ProductUnit unit = item['unit'];
                                    final color = _getTypeColor(move.type);

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
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            // Colored icon circle indicator
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(_getTypeIcon(move.type), color: color, size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            // Details column
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: color.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      _getTypeLabel(move.type),
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    DateFormat('dd MMM yyyy, HH:mm').format(move.createdAt),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 10.5,
                                                      color: const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                  if (move.referenceNo != null && move.referenceNo!.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Ref: ${move.referenceNo}',
                                                      style: GoogleFonts.poppins(
                                                          fontSize: 11, color: const Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Numbers & notes column
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context).size.width * 0.42,
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${move.quantity > 0 ? "+" : ""}${move.quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '')} ${unit.name}',
                                                    textAlign: TextAlign.end,
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: move.quantity >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                  if (move.notes != null && move.notes!.isNotEmpty) ...[
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      move.notes!,
                                                      textAlign: TextAlign.end,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10.5,
                                                        color: const Color(0xFF64748B),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

