import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';

class OrderNotesSettingsPage extends StatefulWidget {
  const OrderNotesSettingsPage({super.key});

  @override
  State<OrderNotesSettingsPage> createState() => _OrderNotesSettingsPageState();
}

class _OrderNotesSettingsPageState extends State<OrderNotesSettingsPage>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  TabController? _itemGroupTabController;
  final _salesRepo = getIt<SalesRepository>();

  bool _isLoading = true;
  List<OrderNoteGroup> _groups = [];
  List<String> _cartPresets = [];

  final _addOptionController = TextEditingController();
  final _addCartPresetController = TextEditingController();

  // Helper mapping icon
  static IconData getIconData(String iconKey) {
    switch (iconKey) {
      case 'food':
        return Icons.soup_kitchen_rounded;
      case 'beverage':
        return Icons.local_cafe_rounded;
      case 'general':
        return Icons.shopping_bag_outlined;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'fastfood':
        return Icons.fastfood_rounded;
      case 'icecream':
        return Icons.icecream_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'local_bar':
        return Icons.local_bar_rounded;
      case 'store':
        return Icons.store_mall_directory_rounded;
      case 'star':
        return Icons.star_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  static const List<Map<String, dynamic>> availableIcons = [
    {'key': 'food', 'label': 'Makanan', 'icon': Icons.soup_kitchen_rounded},
    {'key': 'beverage', 'label': 'Minuman', 'icon': Icons.local_cafe_rounded},
    {'key': 'restaurant', 'label': 'Dapur/Resto', 'icon': Icons.restaurant_rounded},
    {'key': 'fastfood', 'label': 'Camilan', 'icon': Icons.fastfood_rounded},
    {'key': 'icecream', 'label': 'Dessert/Es', 'icon': Icons.icecream_rounded},
    {'key': 'cake', 'label': 'Kue/Bakery', 'icon': Icons.cake_rounded},
    {'key': 'local_bar', 'label': 'Bar', 'icon': Icons.local_bar_rounded},
    {'key': 'general', 'label': 'Kemasan/Umum', 'icon': Icons.shopping_bag_outlined},
    {'key': 'star', 'label': 'Favorit/Kustom', 'icon': Icons.star_rounded},
  ];

  static const List<Map<String, dynamic>> availableColors = [
    {'name': 'Merah Dapur', 'color': Color(0xFFDC2626)},
    {'name': 'Cokelat Kopi', 'color': Color(0xFF78350F)},
    {'name': 'Biru Umum', 'color': Color(0xFF2563EB)},
    {'name': 'Hijau Segar', 'color': Color(0xFF16A34A)},
    {'name': 'Oranye Pedas', 'color': Color(0xFFEA580C)},
    {'name': 'Ungu Bakery', 'color': Color(0xFF9333EA)},
    {'name': 'Abu Netral', 'color': Color(0xFF475569)},
  ];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _itemGroupTabController?.dispose();
    _addOptionController.dispose();
    _addCartPresetController.dispose();
    super.dispose();
  }

  void _initItemGroupTabController(int initialIndex) {
    _itemGroupTabController?.dispose();
    final len = _groups.isEmpty ? 1 : _groups.length;
    final validIndex = initialIndex < len ? initialIndex : 0;
    _itemGroupTabController = TabController(length: len, vsync: this, initialIndex: validIndex);
    _itemGroupTabController!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final loadedGroups = await _salesRepo.getOrderNoteGroups();
    final loadedCartPresets = await _salesRepo.getCartOrderNotePresets();
    setState(() {
      _groups = loadedGroups;
      _cartPresets = loadedCartPresets;
      _isLoading = false;
    });
    _initItemGroupTabController(0);
  }

  Future<void> _saveGroups({bool showToast = true}) async {
    await _salesRepo.saveOrderNoteGroups(_groups);
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Perubahan preset item tersimpan!', style: GoogleFonts.poppins(fontSize: 12.5)),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _saveCartPresets({bool showToast = true}) async {
    await _salesRepo.saveCartOrderNotePresets(_cartPresets);
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Preset catatan keranjang & meja tersimpan!', style: GoogleFonts.poppins(fontSize: 12.5)),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showAddOptionDialog(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;
    _addOptionController.clear();
    final group = _groups[groupIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(group.colorValue).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(getIconData(group.icon), color: Color(group.colorValue), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tambah Opsi (${group.name})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: _addOptionController,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Misal: Level 5, Less Sweet, Bungkus Terpisah...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = _addOptionController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  final opts = List<String>.from(group.options);
                  if (!opts.contains(text)) {
                    opts.add(text);
                    _groups[groupIndex] = group.copyWith(options: opts);
                  }
                });
                _saveGroups();
              }
              Navigator.pop(ctx);
            },
            child: Text('TAMBAH', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddCartPresetDialog() {
    _addCartPresetController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Tambah Preset Keranjang / Meja',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan nomor meja, nomor mangkok hidangan, level pedas porsi seblak, atau instruksi pesanan.',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addCartPresetController,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Contoh: Meja 12, Mangkok #08, Kuah Ekstra Pedas...',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = _addCartPresetController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (!_cartPresets.contains(text)) {
                    _cartPresets.add(text);
                  }
                });
                _saveCartPresets();
              }
              Navigator.pop(ctx);
            },
            child: Text('TAMBAH', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showGroupFormDialog({OrderNoteGroup? existingGroup, int? groupIndex}) {
    final isEdit = existingGroup != null;
    final nameCtrl = TextEditingController(text: existingGroup?.name ?? '');
    String selectedIcon = existingGroup?.icon ?? 'food';
    Color selectedColor = existingGroup != null ? Color(existingGroup.colorValue) : const Color(0xFFDC2626);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_note_rounded : Icons.create_new_folder_rounded,
                  color: const Color(0xFF0F172A),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Ubah Kategori Catatan' : 'Tambah Kategori Catatan Baru',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nama Kategori / Grup Preset',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Makanan Berat, Steaks, Kopi Racik...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Pilih Ikon',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableIcons.map((ic) {
                      final isSelected = selectedIcon == ic['key'];
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setDlgState(() => selectedIcon = ic['key']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(ic['icon'], size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
                              const SizedBox(width: 5),
                              Text(
                                ic['label'],
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Pilih Warna Tema',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableColors.map((c) {
                      final colorVal = c['color'] as Color;
                      final isSelected = selectedColor.value == colorVal.value;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setDlgState(() => selectedColor = colorVal),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorVal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? colorVal : Colors.transparent,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: colorVal, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                c['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: colorVal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;

                  if (isEdit && groupIndex != null) {
                    setState(() {
                      _groups[groupIndex] = existingGroup.copyWith(
                        name: name,
                        icon: selectedIcon,
                        colorValue: selectedColor.value,
                      );
                    });
                  } else {
                    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
                    final newGroup = OrderNoteGroup(
                      id: id,
                      name: name,
                      icon: selectedIcon,
                      colorValue: selectedColor.value,
                      options: [],
                    );
                    setState(() {
                      _groups.add(newGroup);
                    });
                  }

                  _initItemGroupTabController(isEdit ? (groupIndex ?? 0) : _groups.length - 1);
                  _saveGroups();
                  Navigator.pop(ctx);
                },
                child: Text(isEdit ? 'SIMPAN' : 'BUAT KATEGORI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteGroup(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;
    final group = _groups[groupIndex];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Hapus Kategori Catatan "${group.name}"?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        content: Text(
          'Semua daftar opsi preset di dalam grup ini akan ikut dihapus. Kategori produk yang sebelumnya terhubung akan kembali ke mode tanpa racikan.',
          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                _groups.removeAt(groupIndex);
              });
              _initItemGroupTabController(0);
              _saveGroups();
              Navigator.pop(ctx);
            },
            child: Text('HAPUS', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Kembalikan Preset Standar Pabrik?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        content: Text(
          'Seluruh daftar kategori racikan item & preset catatan keranjang/meja akan dikembalikan ke bawaan standar pabrik.',
          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(ctx);
              final defGroups = await _salesRepo.resetOrderNoteGroupsToDefault();
              final defCartPresets = await _salesRepo.resetCartOrderNotePresetsToDefault();
              if (mounted) {
                setState(() {
                  _groups = defGroups;
                  _cartPresets = defCartPresets;
                });
                _initItemGroupTabController(0);
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Preset catatan berhasil direset ke standar!', style: GoogleFonts.poppins(fontSize: 12.5)),
                    backgroundColor: AppConstants.successColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('RESET STANDAR', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeItemGroupIndex = _itemGroupTabController?.index ?? 0;
    final isCartTab = _mainTabController.index == 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preset Catatan Pesanan',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Kelola catatan keranjang/meja & racikan item',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          if (!isCartTab)
            IconButton(
              tooltip: 'Tambah Grup Racikan Baru',
              icon: const Icon(Icons.add_box_rounded, color: Color(0xFF0F172A)),
              onPressed: () => _showGroupFormDialog(),
            )
          else
            IconButton(
              tooltip: 'Tambah Preset Keranjang',
              icon: const Icon(Icons.add_comment_rounded, color: Color(0xFF0F172A)),
              onPressed: () => _showAddCartPresetDialog(),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF0F172A)),
            onSelected: (val) {
              if (val == 'reset') {
                _resetToDefault();
              } else if (val == 'new_group') {
                _showGroupFormDialog();
              } else if (val == 'new_cart_preset') {
                _showAddCartPresetDialog();
              }
            },
            itemBuilder: (ctx) => [
              if (!isCartTab)
                PopupMenuItem(
                  value: 'new_group',
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text('Tambah Kategori Catatan', style: GoogleFonts.poppins(fontSize: 12.5)),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'new_cart_preset',
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text('Tambah Preset Keranjang', style: GoogleFonts.poppins(fontSize: 12.5)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Text('Reset Standar Pabrik', style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFFDC2626))),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _mainTabController,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0F172A),
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.tune_rounded, size: 18),
                  text: 'Catatan Per Item Produk',
                ),
                Tab(
                  icon: Icon(Icons.table_restaurant_rounded, size: 18),
                  text: 'Catatan Keranjang & Meja',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : TabBarView(
              controller: _mainTabController,
              children: [
                // TAB 1: CATATAN PER ITEM PRODUK (DINAMIS GRUP)
                _buildItemNotesTab(activeItemGroupIndex),
                // TAB 2: CATATAN KERANJANG / MEJA / HIDANGAN (SEBLAK PRASMANAN)
                _buildCartNotesTab(),
              ],
            ),
      floatingActionButton: isCartTab
          ? FloatingActionButton.extended(
              onPressed: () => _showAddCartPresetDialog(),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text('Tambah Chip Keranjang', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5)),
            )
          : (_groups.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showAddOptionDialog(activeItemGroupIndex),
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text('Tambah Opsi', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5)),
                )),
    );
  }

  Widget _buildItemNotesTab(int activeIndex) {
    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notes_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              'Belum ada kategori preset catatan item.',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
              onPressed: () => _showGroupFormDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Buat Kategori Baru', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Sub Header: Category Sub Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _itemGroupTabController,
            isScrollable: _groups.length > 3,
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0F172A),
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: _groups.map((g) {
              return Tab(
                icon: Icon(getIconData(g.icon), size: 16, color: Color(g.colorValue)),
                text: g.name,
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _itemGroupTabController,
            children: List.generate(_groups.length, (index) {
              final group = _groups[index];
              return _buildGroupView(group: group, index: index);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCartNotesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Info Banner Hidangan & Prasmanan
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catatan Order Keranjang & Hidangan',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Sangat cocok untuk menu Seblak Prasmanan, Meja Resto, atau Pesanan Grup. Kasir cukup memilih topping seblak ke keranjang, lalu menentukan nomor mangkok/meja, tingkat kepedasan, dan kuah di Catatan Keranjang.',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFFB45309), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Daftar Chip Cepat Keranjang (${_cartPresets.length} Preset)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF334155)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _showAddCartPresetDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: Text('Tambah Chip', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_cartPresets.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.table_restaurant_outlined, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'Belum ada preset catatan keranjang.\nTap "Tambah Chip" untuk menambahkan nomor meja / instruksi seblak.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cartPresets.map((preset) {
              final isTableOrBowl = preset.toLowerCase().contains('meja') || preset.toLowerCase().contains('mangkok');
              final isSpicyOrSoup = preset.toLowerCase().contains('pedas') || preset.toLowerCase().contains('kuah');

              Color chipBg = Colors.white;
              Color chipBorder = const Color(0xFFCBD5E1);
              Color chipText = const Color(0xFF0F172A);

              if (isTableOrBowl) {
                chipBg = const Color(0xFFF0FDF4);
                chipBorder = const Color(0xFFBBF7D0);
                chipText = const Color(0xFF166534);
              } else if (isSpicyOrSoup) {
                chipBg = const Color(0xFFFFF7ED);
                chipBorder = const Color(0xFFFFEDD5);
                chipText = const Color(0xFFC2410C);
              }

              return Chip(
                label: Text(
                  preset,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: chipText),
                ),
                backgroundColor: chipBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: chipBorder),
                ),
                deleteIcon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                onDeleted: () {
                  setState(() {
                    _cartPresets.remove(preset);
                  });
                  _saveCartPresets();
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildGroupView({required OrderNoteGroup group, required int index}) {
    final color = Color(group.colorValue);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Header Info Card
        Container(
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(getIconData(group.icon), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      'Tersedia ${group.options.length} opsi cepat racikan per item',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ubah Kategori',
                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF475569)),
                onPressed: () => _showGroupFormDialog(existingGroup: group, groupIndex: index),
              ),
              if (_groups.length > 1)
                IconButton(
                  tooltip: 'Hapus Kategori',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                  onPressed: () => _confirmDeleteGroup(index),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Daftar Chip Pilihan Cepat Kasir (${group.options.length} Item)',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF334155)),
        ),
        const SizedBox(height: 10),

        if (group.options.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.playlist_add_rounded, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'Belum ada opsi catatan di kategori ini.\nTap "Tambah Opsi" di bawah untuk menambahkan.',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.options.map((opt) {
              return Chip(
                label: Text(
                  opt,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                deleteIcon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                onDeleted: () {
                  setState(() {
                    final opts = List<String>.from(group.options);
                    opts.remove(opt);
                    _groups[index] = group.copyWith(options: opts);
                  });
                  _saveGroups();
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
