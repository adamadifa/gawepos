import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';

class OrderNotesSettingsPage extends StatefulWidget {
  const OrderNotesSettingsPage({super.key});

  // Factory Defaults
  static const List<String> defaultFoodNotes = [
    'Pedas Lv 0 (Original)',
    'Pedas Lv 1',
    'Pedas Lv 2',
    'Pedas Lv 3',
    'Pedas Lv 5 (Ekstra)',
    'Kuah Nyemek',
    'Kuah Banyak',
    'Kuah Kering / Goreng',
    'Tanpa Daun Bawang',
    'Tanpa Micin',
    'Extra Telur',
    'Bungkus / Take Away',
  ];

  static const List<String> defaultBeverageNotes = [
    'Normal Sugar',
    'Less Sugar (50%)',
    'No Sugar (0%)',
    'Normal Ice',
    'Less Ice',
    'No Ice / Hangat',
    'Extra Ice',
    'Extra Shot Espresso',
    'Less Sweet',
    'Cup / Take Away',
  ];

  static const List<String> defaultGeneralNotes = [
    'Bungkus Rapi',
    'Minta Kantong Plastik',
    'Pisah Kantong',
    'Jangan Pakai Sedotan',
    'Nota Print Terpisah',
  ];

  @override
  State<OrderNotesSettingsPage> createState() => _OrderNotesSettingsPageState();
}

class _OrderNotesSettingsPageState extends State<OrderNotesSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _salesRepo = getIt<SalesRepository>();

  bool _isLoading = true;

  // List of chip presets for each category
  List<String> _foodNotes = [];
  List<String> _beverageNotes = [];
  List<String> _generalNotes = [];

  final _addTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addTextController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    final foodStr = await _salesRepo.getSetting('food_order_notes');
    final bevStr = await _salesRepo.getSetting('beverage_order_notes');
    final genStr = await _salesRepo.getSetting('general_order_notes');

    setState(() {
      _foodNotes = foodStr != null
          ? List<String>.from(jsonDecode(foodStr))
          : List<String>.from(OrderNotesSettingsPage.defaultFoodNotes);

      _beverageNotes = bevStr != null
          ? List<String>.from(jsonDecode(bevStr))
          : List<String>.from(OrderNotesSettingsPage.defaultBeverageNotes);

      _generalNotes = genStr != null
          ? List<String>.from(jsonDecode(genStr))
          : List<String>.from(OrderNotesSettingsPage.defaultGeneralNotes);

      _isLoading = false;
    });
  }

  Future<void> _saveNotes() async {
    await _salesRepo.saveSetting('food_order_notes', jsonEncode(_foodNotes));
    await _salesRepo.saveSetting('beverage_order_notes', jsonEncode(_beverageNotes));
    await _salesRepo.saveSetting('general_order_notes', jsonEncode(_generalNotes));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Preset catatan berhasil disimpan!', style: GoogleFonts.poppins(fontSize: 12.5)),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showAddChipDialog(int tabIndex) {
    _addTextController.clear();
    final String catName = tabIndex == 0 ? 'Makanan & Dapur' : (tabIndex == 1 ? 'Minuman & Barista' : 'Umum');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_comment_rounded, color: Color(0xFF0F172A), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Tambah Preset ($catName)',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
        content: TextField(
          controller: _addTextController,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Misal: Extra Kencur, Oatmilk, Sedotan...',
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
              final text = _addTextController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (tabIndex == 0) {
                    if (!_foodNotes.contains(text)) _foodNotes.add(text);
                  } else if (tabIndex == 1) {
                    if (!_beverageNotes.contains(text)) _beverageNotes.add(text);
                  } else {
                    if (!_generalNotes.contains(text)) _generalNotes.add(text);
                  }
                });
                _saveNotes();
              }
              Navigator.pop(ctx);
            },
            child: Text('TAMBAH', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _resetToDefault(int tabIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Kembalikan Preset Standar?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        content: Text(
          'Daftar catatan cepat kategori ini akan direset kembali ke pilihan bawaan pabrik.',
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
            onPressed: () {
              setState(() {
                if (tabIndex == 0) {
                  _foodNotes = List<String>.from(OrderNotesSettingsPage.defaultFoodNotes);
                } else if (tabIndex == 1) {
                  _beverageNotes = List<String>.from(OrderNotesSettingsPage.defaultBeverageNotes);
                } else {
                  _generalNotes = List<String>.from(OrderNotesSettingsPage.defaultGeneralNotes);
                }
              });
              _saveNotes();
              Navigator.pop(ctx);
            },
            child: Text('RESET STANDAR', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
              'Atur tombol cepat racikan dapur & barista kasir',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0F172A),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12.5),
          tabs: const [
            Tab(icon: Icon(Icons.soup_kitchen_rounded, size: 18), text: 'Makanan'),
            Tab(icon: Icon(Icons.local_cafe_rounded, size: 18), text: 'Minuman'),
            Tab(icon: Icon(Icons.shopping_bag_outlined, size: 18), text: 'Umum'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotesList(
                  notes: _foodNotes,
                  tabIndex: 0,
                  badgeColor: const Color(0xFFDC2626),
                  icon: Icons.soup_kitchen_rounded,
                  title: 'Preset Catatan Makanan & Dapur',
                  desc: 'Otomatis aktif saat memilih menu seblak, makanan, mie, bakso, atau camilan.',
                ),
                _buildNotesList(
                  notes: _beverageNotes,
                  tabIndex: 1,
                  badgeColor: const Color(0xFF78350F),
                  icon: Icons.local_cafe_rounded,
                  title: 'Preset Catatan Minuman & Barista',
                  desc: 'Otomatis aktif saat memilih produk kopi, teh, boba, jus, atau minuman dingin.',
                ),
                _buildNotesList(
                  notes: _generalNotes,
                  tabIndex: 2,
                  badgeColor: const Color(0xFF2563EB),
                  icon: Icons.shopping_bag_outlined,
                  title: 'Preset Catatan Umum & Retail',
                  desc: 'Otomatis aktif saat memilih barang umum, titipan, atau transaksi lainnya.',
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddChipDialog(_tabController.index),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('Tambah Catatan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5)),
      ),
    );
  }

  Widget _buildNotesList({
    required List<String> notes,
    required int tabIndex,
    required Color badgeColor,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Info Banner Card
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
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(desc, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _resetToDefault(tabIndex),
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF64748B)),
                label: Text('Reset', style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Daftar Chip Pilihan Cepat Kasir (${notes.length} Item)',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF334155)),
        ),
        const SizedBox(height: 10),

        if (notes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text(
              'Belum ada catatan preset. Tap tombol Tambah Catatan di bawah.',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: notes.map((note) {
              return Chip(
                label: Text(
                  note,
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
                    notes.remove(note);
                  });
                  _saveNotes();
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
