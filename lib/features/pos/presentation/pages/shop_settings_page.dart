import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';

class ShopSettingsPage extends StatefulWidget {
  const ShopSettingsPage({super.key});

  @override
  State<ShopSettingsPage> createState() => _ShopSettingsPageState();
}

class _ShopSettingsPageState extends State<ShopSettingsPage> {
  final SalesRepository _salesRepository = getIt<SalesRepository>();

  final _shopNameController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _receiptHeaderController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  bool _isLoading = false;

  File? _logoImageFile;
  String? _existingLogoPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _shopNameController.addListener(_rebuildOnType);
    _shopPhoneController.addListener(_rebuildOnType);
    _shopAddressController.addListener(_rebuildOnType);
    _receiptHeaderController.addListener(_rebuildOnType);
    _receiptFooterController.addListener(_rebuildOnType);
  }

  void _rebuildOnType() {
    setState(() {});
  }

  @override
  void dispose() {
    _shopNameController.removeListener(_rebuildOnType);
    _shopPhoneController.removeListener(_rebuildOnType);
    _shopAddressController.removeListener(_rebuildOnType);
    _receiptHeaderController.removeListener(_rebuildOnType);
    _receiptFooterController.removeListener(_rebuildOnType);

    _shopNameController.dispose();
    _shopPhoneController.dispose();
    _shopAddressController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final shopName = await _salesRepository.getSetting('shop_name');
    final shopPhone = await _salesRepository.getSetting('shop_phone');
    final shopAddress = await _salesRepository.getSetting('shop_address');
    final rHeader = await _salesRepository.getSetting('receipt_header');
    final rFooter = await _salesRepository.getSetting('receipt_footer');
    final shopLogo = await _salesRepository.getSetting('shop_logo');

    setState(() {
      _shopNameController.text = shopName ?? '';
      _shopPhoneController.text = shopPhone ?? '';
      _shopAddressController.text = shopAddress ?? '';
      _receiptHeaderController.text = rHeader ?? '';
      _receiptFooterController.text = rFooter ?? '';
      _existingLogoPath = shopLogo;
      _isLoading = false;
    });
  }

  Future<void> _pickLogo(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _logoImageFile = File(pickedFile.path);
      });
    }
  }

  void _showLogoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0F172A)),
                title: Text('Ambil dari Kamera', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0F172A)),
                title: Text('Pilih dari Galeri', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    await _salesRepository.saveSetting('shop_name', _shopNameController.text.trim());
    await _salesRepository.saveSetting('shop_phone', _shopPhoneController.text.trim());
    await _salesRepository.saveSetting('shop_address', _shopAddressController.text.trim());
    await _salesRepository.saveSetting('receipt_header', _receiptHeaderController.text.trim());
    await _salesRepository.saveSetting('receipt_footer', _receiptFooterController.text.trim());

    if (_logoImageFile != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final logoDir = Directory('${appDir.path}/logos');
        if (!await logoDir.exists()) {
          await logoDir.create(recursive: true);
        }
        final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedLogoFile = await _logoImageFile!.copy('${logoDir.path}/$fileName');
        await _salesRepository.saveSetting('shop_logo', savedLogoFile.path);
      } catch (_) {}
    } else if (_existingLogoPath == null) {
      await _salesRepository.saveSetting('shop_logo', '');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Pengaturan toko berhasil disimpan!', style: GoogleFonts.poppins(fontSize: 12.5)),
            ],
          ),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 750;

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
              'Profil & Struk Toko',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Identitas usaha & tampilan cetak struk kasir',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFF0F172A)),
            onPressed: _saveSettings,
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildShopSection(),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _saveSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'SIMPAN PROFIL TOKO',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildReceiptPreviewSection(),
                        ),
                      ),
                    ],
                  );
                } else {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildShopSection(),
                      const SizedBox(height: 20),
                      _buildReceiptPreviewSection(),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'SIMPAN PROFIL TOKO',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                }
              },
            ),
    );
  }

  Widget _buildShopSection() {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Identitas Toko & Header Struk'),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Logo Picker
          Center(
            child: Column(
              children: [
                Text(
                  'Logo Toko (Cetak di Struk)',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showLogoSourceSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: _logoImageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(_logoImageFile!, fit: BoxFit.cover),
                              )
                            : (_existingLogoPath != null && _existingLogoPath!.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(
                                      File(_existingLogoPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) => const Icon(
                                        Icons.storefront_rounded,
                                        size: 36,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.storefront_rounded,
                                    size: 36,
                                    color: Color(0xFF94A3B8),
                                  ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if ((_logoImageFile != null) || (_existingLogoPath != null && _existingLogoPath!.isNotEmpty))
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _logoImageFile = null;
                        _existingLogoPath = null;
                      });
                    },
                    child: Text(
                      'Hapus Logo',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFDC2626),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),

          _buildInputField(
            controller: _shopNameController,
            label: 'Nama Usaha / Toko',
            hint: 'Contoh: Toko Berkah Mandiri',
            icon: Icons.store_rounded,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _shopPhoneController,
            label: 'Nomor Telepon Toko',
            hint: 'Contoh: 0812-3456-7890',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _shopAddressController,
            label: 'Alamat Toko',
            hint: 'Contoh: Jl. Ahmad Yani No. 123, Bandung',
            icon: Icons.location_on_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _receiptHeaderController,
            label: 'Header Struk (Pesan Pembuka)',
            hint: 'Contoh: Selamat Datang & Selamat Berbelanja',
            icon: Icons.message_rounded,
          ),
          const SizedBox(height: 14),
          _buildInputField(
            controller: _receiptFooterController,
            label: 'Footer Struk (Catatan Penutup)',
            hint: 'Contoh: Barang yang sudah dibeli tidak dapat ditukar',
            icon: Icons.notes_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Live Preview Struk Kertas Kasir'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo preview
              if (_logoImageFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Image.file(_logoImageFile!, height: 44, width: 44, fit: BoxFit.cover),
                )
              else if (_existingLogoPath != null && _existingLogoPath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Image.file(
                    File(_existingLogoPath!),
                    height: 44,
                    width: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => const SizedBox(),
                  ),
                ),

              // Header
              Text(
                _shopNameController.text.isEmpty ? 'NAMA TOKO ANDA' : _shopNameController.text.toUpperCase(),
                style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              if (_shopAddressController.text.isNotEmpty)
                Text(
                  _shopAddressController.text,
                  style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              if (_shopPhoneController.text.isNotEmpty)
                Text(
                  'Telp: ${_shopPhoneController.text}',
                  style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 6),
              Text(
                '- - - - - - - - - - - - - - - -',
                style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nota : TRX-YYYYMMDD-0001', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black54)),
                    Text('Tgl  : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black54)),
                    Text('Kasir: Admin Toko', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black54)),
                  ],
                ),
              ),
              Text(
                '- - - - - - - - - - - - - - - -',
                style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTOH BARANG A', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1 Pcs x 25.000', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                        Text('25.000', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('CONTOH BARANG B', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('2 Pcs x 15.000', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                        Text('30.000', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),

              Text(
                '- - - - - - - - - - - - - - - -',
                style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grand Total', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.black87)),
                  Text('55.000', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.black87)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bayar (Tunai)', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                  Text('100.000', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kembalian', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                  Text('45.000', style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87)),
                ],
              ),

              Text(
                '- - - - - - - - - - - - - - - -',
                style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
              ),

              if (_receiptHeaderController.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _receiptHeaderController.text,
                  style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_receiptFooterController.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _receiptFooterController.text,
                  style: GoogleFonts.courierPrime(fontSize: 10.5, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
