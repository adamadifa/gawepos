import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../pos/presentation/bloc/cart_cubit.dart';
import '../bloc/table_cubit.dart';

class TableLayoutModal extends StatefulWidget {
  final Function(RestaurantTable table, bool isAddonOrder)? onTableSelected;

  const TableLayoutModal({
    super.key,
    this.onTableSelected,
  });

  @override
  State<TableLayoutModal> createState() => _TableLayoutModalState();
}

class _TableLayoutModalState extends State<TableLayoutModal> {
  String _selectedSection = 'Semua';

  void _handleTableTap(BuildContext context, RestaurantTable table) {
    final isOccupied = table.status == 'occupied';

    if (isOccupied) {
      // Meja sedang terisi -> Tampilkan opsi pemilihan (Lanjut / Pesanan Tambahan / Bebaskan)
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${table.name} (Sedang Terisi)',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Area: ${table.section} • Kapasitas: ${table.capacity} Orang',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Option 1: Tambah Pesanan Baru (Add-on Order)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                title: Text('Buat Pesanan Tambahan (Order Baru)', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text('Membuat pesanan/struk dapur baru untuk meja ini', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx); // Tutup bottomsheet opsi
                  Navigator.pop(context); // Tutup modal meja
                  context.read<CartCubit>().setSelectedTable(table);
                  widget.onTableSelected?.call(table, true);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              // Option 2: Jadikan Meja Terpilih di Keranjang
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0F172A), size: 22),
                ),
                title: Text('Pilih Meja Ini untuk Keranjang Aktif', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text('Menyematkan ${table.name} ke keranjang kasir saat ini', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  context.read<CartCubit>().setSelectedTable(table);
                  widget.onTableSelected?.call(table, false);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              // Option 3: Kosongkan Meja
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF059669), size: 22),
                ),
                title: Text('Selesaikan & Kosongkan Meja', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text('Ubah status meja menjadi Kosong (Tersedia)', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<TableCubit>().updateStatus(table.id, 'available');
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // Meja Kosong / Reserved -> Langsung set ke keranjang
      Navigator.pop(context);
      context.read<CartCubit>().setSelectedTable(table);
      widget.onTableSelected?.call(table, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxModalHeight = screenHeight * 0.85;

    return BlocBuilder<TableCubit, TableState>(
      builder: (context, state) {
        final currentTable = context.watch<CartCubit>().state.selectedTable;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600, maxHeight: maxModalHeight),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Handle Bar & Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Column(
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
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0F172A), size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Denah & Pemilihan Meja',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Pilih meja untuk pesanan makan di tempat (Dine-in)',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Legend (Bioskop Style)
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem('Tersedia', const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                            const SizedBox(width: 16),
                            _buildLegendItem('Terisi / Aktif', const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
                            const SizedBox(width: 16),
                            _buildLegendItem('Terpilih', const Color(0xFF0F172A), const Color(0xFFE2E8F0)),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // Section Tabs Filter
                    if (state is TableLoaded && state.sections.length > 1)
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.sections.length,
                          separatorBuilder: (c, i) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final sec = state.sections[index];
                            final isSelected = sec == _selectedSection;
                            return ChoiceChip(
                              label: Text(sec),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedSection = sec;
                                  });
                                }
                              },
                              labelStyle: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                              selectedColor: const Color(0xFF0F172A),
                              backgroundColor: const Color(0xFFF1F5F9),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            );
                          },
                        ),
                      ),

                    // Grid Layout Meja (Cinema / Table Visual Grid)
                    Expanded(
                      child: state is TableLoading
                          ? const Center(child: CircularProgressIndicator())
                          : state is TableLoaded
                              ? _buildTableGrid(context, state, currentTable)
                              : const SizedBox(),
                    ),

                    // Bottom Action Bar (Clear Table Selection or Takeaway)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              icon: const Icon(Icons.takeout_dining_rounded, size: 18, color: Color(0xFF334155)),
                              label: Text(
                                'Bawa Pulang / Tanpa Meja',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF334155)),
                              ),
                              onPressed: () {
                                context.read<CartCubit>().setSelectedTable(null);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                          if (currentTable != null) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Lepas Meja',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE2E2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.link_off_rounded, color: Color(0xFFDC2626), size: 20),
                              onPressed: () {
                                context.read<CartCubit>().setSelectedTable(null);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildTableGrid(BuildContext context, TableLoaded state, RestaurantTable? currentTable) {
    final tables = _selectedSection == 'Semua'
        ? state.tables
        : state.tables.where((t) => t.section == _selectedSection).toList();

    if (tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('Tidak ada meja di area $_selectedSection', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final isSelected = currentTable?.id == table.id;
        final isAvailable = table.status == 'available';
        final isOccupied = table.status == 'occupied';

        return GestureDetector(
          onTap: () => _handleTableTap(context, table),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : isOccupied
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE2E8F0),
                width: isOccupied || isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris Atas: Nomor Meja & Indikator Status Dot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          table.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),

                  // Bagian Tengah: Ikon Meja
                  Center(
                    child: Icon(
                      Icons.table_restaurant_rounded,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : isOccupied
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF94A3B8),
                    ),
                  ),

                  // Baris Bawah: Area & Kapasitas Kursi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          table.section,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${table.capacity} org',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : const Color(0xFF64748B),
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

  Widget _buildLegendItem(String label, Color dotColor, Color bgColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
