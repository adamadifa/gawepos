import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/table_cubit.dart';

class TablesManagementPage extends StatefulWidget {
  const TablesManagementPage({super.key});

  @override
  State<TablesManagementPage> createState() => _TablesManagementPageState();
}

class _TablesManagementPageState extends State<TablesManagementPage> {
  String _selectedSectionFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    context.read<TableCubit>().loadTables();
  }

  void _showAddEditTableDialog(BuildContext context, {RestaurantTable? table}) {
    final nameController = TextEditingController(text: table?.name ?? '');
    final sectionController = TextEditingController(text: table?.section ?? 'Indoor AC');
    int capacity = table?.capacity ?? 4;
    final isEditing = table != null;

    final presetSections = [
      {'name': 'Indoor AC', 'icon': Icons.ac_unit_rounded},
      {'name': 'Outdoor', 'icon': Icons.deck_rounded},
      {'name': 'Lantai 2', 'icon': Icons.stairs_rounded},
      {'name': 'VIP', 'icon': Icons.stars_rounded},
      {'name': 'Bar', 'icon': Icons.local_bar_rounded},
      {'name': 'Lesehan', 'icon': Icons.chair_alt_rounded},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag indicator handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Modal
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.table_restaurant_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Perbarui Data Meja' : 'Tambah Meja Baru',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isEditing ? 'Ubah nomor, area, atau kapasitas meja' : 'Daftarkan nomor meja baru untuk operasional F&B',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Input Nama Meja
                  Text(
                    'Nomor / Nama Meja',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: !isEditing,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Meja 01, VIP 2, Bar A',
                      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.numbers_rounded, color: Color(0xFF64748B), size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Area / Lantai
                  Text(
                    'Pilih Area / Lantai',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presetSections.map((sec) {
                      final isSelected = sectionController.text == sec['name'];
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            sectionController.text = sec['name'] as String;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                sec['icon'] as IconData,
                                size: 15,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                sec['name'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sectionController,
                    decoration: InputDecoration(
                      hintText: 'Atau tulis area kustom lainnya...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.room_rounded, color: Color(0xFF64748B), size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Kapasitas Kursi Interaktif
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kapasitas Meja',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: const Color(0xFF334155),
                            ),
                          ),
                          Text(
                            'Jumlah kursi / orang',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF0F172A)),
                              onPressed: capacity > 1
                                  ? () {
                                      setDialogState(() => capacity--);
                                    }
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$capacity Kursi',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF0F172A)),
                              onPressed: () {
                                setDialogState(() => capacity++);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tombol Aksi
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;
                            final sec = sectionController.text.trim().isEmpty ? 'Utama' : sectionController.text.trim();

                            if (isEditing) {
                              context.read<TableCubit>().updateTable(
                                    table.copyWith(
                                      name: name,
                                      section: sec,
                                      capacity: capacity,
                                    ),
                                  );
                            } else {
                              context.read<TableCubit>().addTable(
                                    RestaurantTablesCompanion.insert(
                                      name: name,
                                      section: drift.Value(sec),
                                      capacity: drift.Value(capacity),
                                    ),
                                  );
                            }
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            isEditing ? 'Simpan Perubahan' : 'Tambah Meja',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, RestaurantTable table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Text('Hapus ${table.name}?', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'Meja ini akan dihapus dari sistem denah meja outlet Anda.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TableCubit>().deleteTable(table.id);
            },
            child: Text('Ya, Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manajemen Meja F&B',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Tata letak meja, kapasitas & status outlet',
              style: GoogleFonts.poppins(
                color: const Color(0xFF94A3B8),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat Ulang',
            onPressed: () => context.read<TableCubit>().loadTables(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text('Tambah Meja', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
        onPressed: () => _showAddEditTableDialog(context),
      ),
      body: BlocBuilder<TableCubit, TableState>(
        builder: (context, state) {
          if (state is TableLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TableError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppConstants.errorColor, size: 48),
                    const SizedBox(height: 12),
                    Text(state.message, textAlign: TextAlign.center, style: GoogleFonts.poppins()),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.read<TableCubit>().loadTables(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is TableLoaded) {
            final tables = state.filteredTables;
            final sections = state.sections;

            return Column(
              children: [
                // Top Header Hero Dashboard Card
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStatusCard(
                            label: 'Tersedia',
                            count: state.availableCount,
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF10B981),
                            gradientColors: [const Color(0xFF065F46).withValues(alpha: 0.6), const Color(0xFF047857).withValues(alpha: 0.2)],
                          ),
                          const SizedBox(width: 10),
                          _buildStatusCard(
                            label: 'Terisi',
                            count: state.occupiedCount,
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFFF59E0B),
                            gradientColors: [const Color(0xFF78350F).withValues(alpha: 0.6), const Color(0xFFB45309).withValues(alpha: 0.2)],
                          ),
                          const SizedBox(width: 10),
                          _buildStatusCard(
                            label: 'Reserved',
                            count: state.reservedCount,
                            icon: Icons.bookmark_rounded,
                            color: const Color(0xFF38BDF8),
                            gradientColors: [const Color(0xFF0369A1).withValues(alpha: 0.6), const Color(0xFF0284C7).withValues(alpha: 0.2)],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Section Filter Tabs with Modern Badge
                if (sections.length > 1)
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: sections.length,
                      separatorBuilder: (c, i) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final sec = sections[index];
                        final isSelected = sec == _selectedSectionFilter;
                        return ChoiceChip(
                          label: Text(sec),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedSectionFilter = sec;
                              });
                              context.read<TableCubit>().setSection(sec);
                            }
                          },
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          showCheckmark: false,
                          elevation: isSelected ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Table List Grid
                Expanded(
                  child: tables.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.table_restaurant_outlined, size: 48, color: Color(0xFF6366F1)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Belum ada meja di area ini',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tekan tombol + Tambah Meja untuk mendaftarkan meja.',
                                style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.32,
                          ),
                          itemCount: tables.length,
                          itemBuilder: (context, index) {
                            final table = tables[index];
                            final isAvailable = table.status == 'available';
                            final isOccupied = table.status == 'occupied';

                            final Color statusColor = isAvailable
                                ? const Color(0xFF16A34A)
                                : isOccupied
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF2563EB);

                            final Color statusBg = isAvailable
                                ? const Color(0xFFDCFCE7)
                                : isOccupied
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFDBEAFE);

                            final String statusText = isAvailable
                                ? 'Tersedia'
                                : isOccupied
                                    ? 'Terisi'
                                    : 'Reserved';

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isOccupied
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFE2E8F0),
                                  width: isOccupied ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _showAddEditTableDialog(context, table: table),
                                    child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Baris Atas: Nomor Meja & Status Badge
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                table.name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Bagian Tengah: Ikon Meja Simpel & Rapi
                                        Center(
                                          child: Icon(
                                            Icons.table_restaurant_rounded,
                                            size: 26,
                                            color: isOccupied ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                                          ),
                                        ),

                                        // Baris Bawah: Area, Kapasitas & Menu Aksi
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  table.section,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '${table.capacity} org',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF94A3B8)),
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _showAddEditTableDialog(context, table: table);
                                                } else if (val == 'status_avail') {
                                                  context.read<TableCubit>().updateStatus(table.id, 'available');
                                                } else if (val == 'status_occ') {
                                                  context.read<TableCubit>().updateStatus(table.id, 'occupied');
                                                } else if (val == 'delete') {
                                                  _showDeleteConfirmDialog(context, table);
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.edit_rounded, size: 16, color: Color(0xFF0F172A)),
                                                      SizedBox(width: 8),
                                                      Text('Edit Meja'),
                                                    ],
                                                  ),
                                                ),
                                                if (!isAvailable)
                                                  const PopupMenuItem(
                                                    value: 'status_avail',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                                                        SizedBox(width: 8),
                                                        Text('Set Tersedia'),
                                                      ],
                                                    ),
                                                  ),
                                                if (!isOccupied)
                                                  const PopupMenuItem(
                                                    value: 'status_occ',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFFD97706)),
                                                        SizedBox(width: 8),
                                                        Text('Set Terisi'),
                                                      ],
                                                    ),
                                                  ),
                                                const PopupMenuDivider(),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('Hapus Meja', style: TextStyle(color: Colors.red)),
                                                    ],
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
                        ),
                ),
              ],
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildStatusCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

