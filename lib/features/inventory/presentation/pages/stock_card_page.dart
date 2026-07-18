import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
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
        return AppConstants.errorColor;
      case 'purchase':
        return AppConstants.successColor;
      case 'opname':
        return AppConstants.primaryColor;
      case 'manual_in':
        return AppConstants.successColor;
      case 'manual_out':
        return AppConstants.errorColor;
      default:
        return AppConstants.textLightColor;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'sale':
        return 'Penjualan';
      case 'purchase':
        return 'Pembelian';
      case 'opname':
        return 'Opname (Penyesuaian)';
      case 'void':
        return 'Batal Transaksi';
      case 'manual_in':
        return 'Stok Masuk Manual';
      case 'manual_out':
        return 'Stok Keluar Manual';
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Periode Mutasi',
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

  Widget _buildUnitTabs(List<ProductUnit> units) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Satuan',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppConstants.textLightColor,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
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
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? AppConstants.primaryColor : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unit.name,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppConstants.primaryColor : AppConstants.textDarkColor,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kartu Stok Barang',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filter Periode
                _buildPeriodFilter(),
                const Divider(height: 1, color: AppConstants.borderLightColor),

                // Movements list
                Expanded(
                  child: BlocBuilder<InventoryCubit, InventoryState>(
                    builder: (context, state) {
                      if (state is InventoryLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state is InventoryError) {
                        return Center(child: Text(state.message));
                      }
                      if (state is StockCardLoaded) {
                        final List<ProductUnit> units = state.units;

                        if (units.isNotEmpty && _selectedUnitId == null) {
                          final baseUnit = units.firstWhere((u) => u.isBase, orElse: () => units.first);
                          _selectedUnitId = baseUnit.id;
                        }

                        final filteredList = state.movements.where((item) {
                          final ProductUnit unit = item['unit'];
                          return unit.id == _selectedUnitId;
                        }).toList();

                        return Column(
                          children: [
                            if (units.isNotEmpty) ...[
                              _buildUnitTabs(units),
                              const Divider(height: 1, color: AppConstants.borderLightColor),
                            ],
                            Expanded(
                              child: filteredList.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.history_rounded,
                                                size: 48, color: AppConstants.textLightColor),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Belum ada riwayat mutasi stok untuk produk ini pada satuan yang dipilih.',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                  color: AppConstants.textLightColor, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredList[index];
                                        final StockMovement move = item['movement'];
                                        final ProductUnit unit = item['unit'];
                                        final color = _getTypeColor(move.type);

                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                            side: const BorderSide(color: AppConstants.borderLightColor),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                // Colored icon circle indicator
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(_getTypeIcon(move.type), color: color, size: 18),
                                                ),
                                                const SizedBox(width: 14),
                                                // Details column
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: color.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          _getTypeLabel(move.type),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: color,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        move.createdAt.toString().substring(0, 16),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppConstants.textLightColor,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (move.notes != null)
                                                        Text(
                                                          move.notes!,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            color: AppConstants.textDarkColor,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      if (move.referenceNo != null)
                                                        Text(
                                                          'Reff: ${move.referenceNo!}',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppConstants.textLightColor),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Qty diff indicator
                                                Text(
                                                  '${move.quantity > 0 ? "+" : ""}${move.quantity} ${unit.name}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
          ),
        ],
      ),
    );
  }
}
