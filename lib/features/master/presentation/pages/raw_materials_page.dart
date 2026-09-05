import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/master_repository.dart';
import 'raw_material_form_page.dart';

class RawMaterialsPage extends StatefulWidget {
  const RawMaterialsPage({super.key});

  @override
  State<RawMaterialsPage> createState() => _RawMaterialsPageState();
}

class _RawMaterialsPageState extends State<RawMaterialsPage> {
  final MasterRepository _repo = getIt<MasterRepository>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _rawMaterials = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRawMaterials();
  }

  Future<void> _loadRawMaterials() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.getRawMaterialsWithDetails();
      if (mounted) {
        setState(() {
          _rawMaterials = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSeedConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.coffee_rounded, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Sample Bahan Kedai Kopi',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistem akan membuat 23 data bahan baku standar kedai kopi lengkap dengan:',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            _buildFeatureBullet('Biji Espresso, Single Origin Gayo, Robusta Dampit'),
            _buildFeatureBullet('Fresh Milk, Oat Milk Barista, Evaporasi, SKM'),
            _buildFeatureBullet('Sirup Aren, Karamel, Vanila, Hazelnut, Simple Syrup'),
            _buildFeatureBullet('Matcha Premium, Cokelat Pure, Red Velvet, Boba'),
            _buildFeatureBullet('Cup PET 16oz/12oz, Paper Cup, Lid Sealer, Sedotan, Kantong'),
            _buildFeatureBullet('Harga beli/modal HPP dan stok awal siap racik'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _startSeedingWithProgress();
            },
            child: Text(
              'GENERATE SEKARANG',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  void _startSeedingWithProgress() {
    int currentProgress = 0;
    int totalProgress = 23;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Membuat Bahan Baku Kedai Kopi...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentProgress dari $totalProgress bahan diproses',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalProgress > 0 ? (currentProgress / totalProgress) : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    _repo.seedCoffeeRawMaterials(
      onProgress: (cur, tot) {
        currentProgress = cur;
        totalProgress = tot;
      },
    ).then((count) {
      if (mounted) {
        Navigator.pop(context); // Tutup dialog progress
        _loadRawMaterials();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Berhasil membuat $count bahan baku kedai kopi!',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }).catchError((e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat data dummy: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    });
  }

  void _openAddRawMaterial() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const RawMaterialFormPage(),
      ),
    );
    if (result == true) {
      _loadRawMaterials();
    }
  }

  void _openEditRawMaterial(Product product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RawMaterialFormPage(existingProduct: product),
      ),
    );
    if (result == true) {
      _loadRawMaterials();
    }
  }

  void _deleteRawMaterial(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Hapus Bahan Baku',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus bahan "${product.name}"? Jika bahan ini dipakai pada resep menu, resep tersebut akan terpengaruh.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('BATAL', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('HAPUS', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.deleteProduct(product.id);
      _loadRawMaterials();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bahan baku "${product.name}" berhasil dihapus.'),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _rawMaterials.where((m) {
      final Product p = m['product'];
      final name = p.name.toLowerCase();
      final sku = p.sku?.toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Clean Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master Bahan Baku',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Kelola bahan mentah & takaran racikan resep',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _showSeedConfirmDialog,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.playlist_add_rounded, color: Color(0xFF059669), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _openAddRawMaterial,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      'Tambah',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE2E8F0)),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.poppins(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Cari nama bahan baku (Kopi, Susu, Gula, Cup)...',
                    hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.eco_rounded, color: Color(0xFF059669), size: 36),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Belum Ada Bahan Baku',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tambahkan bahan mentah (Kopi, Susu, Sirup, Cup, dsb)\natau buat contoh bahan baku kedai kopi otomatis.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _showSeedConfirmDialog,
                                    icon: const Icon(Icons.coffee_rounded, size: 16, color: Color(0xFF059669)),
                                    label: Text(
                                      'Contoh Kedai Kopi',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF059669)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF059669)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    onPressed: _openAddRawMaterial,
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: Text('Tambah Manual', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final Product product = item['product'];
                            final List<ProductUnit> units = item['units'] ?? [];
                            final Category? category = item['category'];

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
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
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.eco_rounded, color: Color(0xFF059669), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.name,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                if (category != null)
                                                  Container(
                                                    margin: const EdgeInsets.only(right: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      category.name,
                                                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                                    ),
                                                  ),
                                                Text(
                                                  'SKU: ${product.sku ?? '-'}',
                                                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _openEditRawMaterial(product);
                                          } else if (val == 'delete') {
                                            _deleteRawMaterial(product);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F172A)),
                                                SizedBox(width: 8),
                                                Text('Ubah Detail'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                SizedBox(width: 8),
                                                Text('Hapus Bahan', style: TextStyle(color: Color(0xFFDC2626))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(height: 1, color: const Color(0xFFF1F5F9)),
                                  const SizedBox(height: 8),

                                  // Satuan Unit & Harga Beli/Modal
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: units.map((u) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          '${u.name}: ${CurrencyFormatter.format(u.costPrice)} / ${u.name}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF334155),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
