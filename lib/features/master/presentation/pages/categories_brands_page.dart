import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/category_cubit.dart';
import '../bloc/brand_cubit.dart';

class CategoriesBrandsPage extends StatefulWidget {
  const CategoriesBrandsPage({super.key});

  @override
  State<CategoriesBrandsPage> createState() => _CategoriesBrandsPageState();
}

class _CategoriesBrandsPageState extends State<CategoriesBrandsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<CategoryCubit>().loadCategories();
    context.read<BrandCubit>().loadBrands();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Clean Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A), size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Kategori & Merek',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE2E8F0)),
            
            // Segmented TabBar Container
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Kategori Produk'),
                    Tab(text: 'Merek (Brand)'),
                  ],
                ),
              ),
            ),

            // TabBar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CategoryTabContent(),
                  _BrandTabContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CATEGORY TAB CONTENT ───────────────────────────────────────────
class _CategoryTabContent extends StatelessWidget {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  void _showFormDialog(BuildContext context, {Category? category}) {
    String selectedNoteType = category?.defaultNoteType ?? 'food';
    if (category != null) {
      _nameController.text = category.name;
      _descController.text = category.description ?? '';
    } else {
      _nameController.clear();
      _descController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedName = category != null;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isNameValid = _nameController.text.trim().isNotEmpty;
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.category_rounded,
                                    color: Color(0xFF0F172A), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                category == null ? 'Tambah Kategori' : 'Ubah Kategori',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Field: Nama Kategori
                      Text(
                        'Nama Kategori',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Makanan, Minuman, Pakaian...',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.label_outline_rounded, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          errorText: (hasInteractedName && !isNameValid) ? 'Nama kategori wajib diisi' : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          ),
                        ),
                        onChanged: (_) {
                          setModalState(() {
                            hasInteractedName = true;
                          });
                        },
                      ),
                      const SizedBox(height: 14),

                      // Field: Deskripsi
                      Text(
                        'Deskripsi (Opsional)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descController,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Keterangan tambahan untuk kategori...',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Field: Jenis Preset Catatan / Racikan
                      Text(
                        'Jenis Preset Catatan & Racikan Kasir',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Preset racikan yang otomatis tampil saat produk dalam kategori ini dipilih di kasir.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildNoteTypeSelectorOption(
                            type: 'food',
                            label: '🍜 Makanan & Dapur',
                            sublabel: 'Level Pedas, Kuah, Bawang',
                            activeColor: const Color(0xFFDC2626),
                            isSelected: selectedNoteType == 'food',
                            onTap: () => setModalState(() => selectedNoteType = 'food'),
                          ),
                          _buildNoteTypeSelectorOption(
                            type: 'beverage',
                            label: '☕ Minuman & Barista',
                            sublabel: 'Gula, Es, Shot Espresso',
                            activeColor: const Color(0xFF78350F),
                            isSelected: selectedNoteType == 'beverage',
                            onTap: () => setModalState(() => selectedNoteType = 'beverage'),
                          ),
                          _buildNoteTypeSelectorOption(
                            type: 'general',
                            label: '🛍️ Umum & Kemasan',
                            sublabel: 'Bungkus, Kantong, Nota',
                            activeColor: const Color(0xFF2563EB),
                            isSelected: selectedNoteType == 'general',
                            onTap: () => setModalState(() => selectedNoteType = 'general'),
                          ),
                          _buildNoteTypeSelectorOption(
                            type: 'none',
                            label: '❌ Tanpa Catatan',
                            sublabel: 'Tidak ada tombol racikan',
                            activeColor: const Color(0xFF64748B),
                            isSelected: selectedNoteType == 'none',
                            onTap: () => setModalState(() => selectedNoteType = 'none'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          onPressed: isNameValid
                              ? () {
                                  final name = _nameController.text.trim();
                                  if (category == null) {
                                    context.read<CategoryCubit>().addCategory(
                                      name,
                                      _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                                      defaultNoteType: selectedNoteType,
                                    );
                                  } else {
                                    context.read<CategoryCubit>().editCategory(
                                      category,
                                      name,
                                      _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                                      defaultNoteType: selectedNoteType,
                                    );
                                  }
                                  Navigator.pop(ctx);
                                }
                              : null,
                          label: Text(
                            category == null ? 'Simpan Kategori' : 'Perbarui Kategori',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoteTypeSelectorOption({
    required String type,
    required String label,
    required String sublabel,
    required Color activeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? activeColor : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  sublabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Kategori',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text('Apakah Anda yakin ingin menghapus kategori "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              context.read<CategoryCubit>().deleteCategory(category.id);
              Navigator.pop(ctx);
            },
            child: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAppSnackbar(BuildContext context, String message, {bool isError = false}) {
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
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Content Area
        Expanded(
          child: BlocConsumer<CategoryCubit, CategoryState>(
            listener: (context, state) {
              if (state is CategorySaved) {
                _showAppSnackbar(
                  context,
                  state.isEdit
                      ? 'Kategori "${state.categoryName}" berhasil diperbarui.'
                      : 'Kategori "${state.categoryName}" berhasil ditambahkan.',
                );
              } else if (state is CategoryDeleted) {
                _showAppSnackbar(
                  context,
                  'Kategori "${state.categoryName}" berhasil dihapus.',
                );
              } else if (state is CategoryError) {
                _showAppSnackbar(context, state.message, isError: true);
              }
            },
            builder: (context, state) {
              if (state is CategoryLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is CategoryError) {
                return Center(child: Text(state.message));
              }
              if (state is CategoryLoaded) {
                final list = state.categories;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada kategori.',
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.category_rounded, color: Color(0xFF0F172A), size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.description != null && item.description!.isNotEmpty) ...[
                              Text(
                                item.description!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.defaultNoteType == 'food'
                                    ? const Color(0xFFDC2626).withValues(alpha: 0.1)
                                    : (item.defaultNoteType == 'beverage'
                                        ? const Color(0xFF78350F).withValues(alpha: 0.1)
                                        : (item.defaultNoteType == 'general'
                                            ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                            : const Color(0xFF64748B).withValues(alpha: 0.1))),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.defaultNoteType == 'food'
                                    ? '🍜 Racikan Makanan'
                                    : (item.defaultNoteType == 'beverage'
                                        ? '☕ Racikan Minuman'
                                        : (item.defaultNoteType == 'general'
                                            ? '🛍️ Racikan Umum'
                                            : '❌ Tanpa Racikan')),
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: item.defaultNoteType == 'food'
                                      ? const Color(0xFFDC2626)
                                      : (item.defaultNoteType == 'beverage'
                                          ? const Color(0xFF78350F)
                                          : (item.defaultNoteType == 'general'
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF64748B))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, category: item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF334155),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showDeleteDialog(context, item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
        
        // Add Button Bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _showFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Tambah Kategori',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── BRAND TAB CONTENT ──────────────────────────────────────────────
class _BrandTabContent extends StatelessWidget {
  final _nameController = TextEditingController();

  void _showFormDialog(BuildContext context, {Brand? brand}) {
    if (brand != null) {
      _nameController.text = brand.name;
    } else {
      _nameController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedName = brand != null;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isNameValid = _nameController.text.trim().isNotEmpty;
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.stars_rounded,
                                    color: Color(0xFF2563EB), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                brand == null ? 'Tambah Merek' : 'Ubah Merek',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Field: Nama Merek
                      Text(
                        'Nama Merek (Brand)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Indofood, Unilever, Samsung...',
                          hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.stars_outlined, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          errorText: (hasInteractedName && !isNameValid) ? 'Nama merek wajib diisi' : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          ),
                        ),
                        onChanged: (_) {
                          setModalState(() {
                            hasInteractedName = true;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          onPressed: isNameValid
                              ? () {
                                  final name = _nameController.text.trim();
                                  if (brand == null) {
                                    context.read<BrandCubit>().addBrand(name);
                                  } else {
                                    context.read<BrandCubit>().editBrand(brand, name);
                                  }
                                  Navigator.pop(ctx);
                                }
                              : null,
                          label: Text(
                            brand == null ? 'Simpan Merek' : 'Perbarui Merek',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Brand brand) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Merek',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text('Apakah Anda yakin ingin menghapus merek "${brand.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              context.read<BrandCubit>().deleteBrand(brand.id);
              Navigator.pop(ctx);
            },
            child: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAppSnackbar(BuildContext context, String message, {bool isError = false}) {
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
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Content Area
        Expanded(
          child: BlocConsumer<BrandCubit, BrandState>(
            listener: (context, state) {
              if (state is BrandSaved) {
                _showAppSnackbar(
                  context,
                  state.isEdit
                      ? 'Merek "${state.brandName}" berhasil diperbarui.'
                      : 'Merek "${state.brandName}" berhasil ditambahkan.',
                );
              } else if (state is BrandDeleted) {
                _showAppSnackbar(
                  context,
                  'Merek "${state.brandName}" berhasil dihapus.',
                );
              } else if (state is BrandError) {
                _showAppSnackbar(context, state.message, isError: true);
              }
            },
            builder: (context, state) {
              if (state is BrandLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is BrandError) {
                return Center(child: Text(state.message));
              }
              if (state is BrandLoaded) {
                final list = state.brands;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada merek (brand).',
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.stars_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, brand: item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF334155),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showDeleteDialog(context, item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
        
        // Add Button Bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _showFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Tambah Merek',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
