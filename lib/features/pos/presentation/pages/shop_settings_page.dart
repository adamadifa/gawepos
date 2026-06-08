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
  
  // State logo toko
  File? _logoImageFile;
  String? _existingLogoPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    // Pasang listener untuk memperbarui preview struk secara langsung saat mengetik
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMd)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppConstants.primaryColor),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppConstants.primaryColor),
              title: const Text('Galeri Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickLogo(ImageSource.gallery);
              },
            ),
          ],
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

    // Simpan logo toko jika ada yang baru dipilih
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
      } catch (e) {
        // Gagal menyimpan file logo secara fisik
      }
    } else if (_existingLogoPath == null) {
      // Jika logo dihapus
      await _salesRepository.saveSetting('shop_logo', '');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan toko berhasil disimpan!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Profil & Struk Toko',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _saveSettings,
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (isWide) {
                  // Tampilan Desktop/Tablet: Sandingkan Form & Preview
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildShopSection(),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _saveSettings,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: Text(
                                'SIMPAN PROFIL TOKO',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, color: AppConstants.borderLightColor),
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
                  // Tampilan HP: Susun vertikal Form, lalu Preview Struk di bawah
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
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(
                          'SIMPAN PROFIL TOKO',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: const BorderSide(color: AppConstants.borderLightColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Profil & Header Struk Toko'),
            const Divider(),
            const SizedBox(height: 8),
            
            // UI Picker Logo Toko
            Center(
              child: Column(
                children: [
                  Text(
                    'Logo Toko (Muncul di Struk)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppConstants.textLightColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showLogoSourceSheet,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppConstants.borderLightColor),
                          ),
                          child: _logoImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_logoImageFile!, fit: BoxFit.cover),
                                )
                              : (_existingLogoPath != null && _existingLogoPath!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(_existingLogoPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, o, s) => const Icon(
                                          Icons.storefront_rounded,
                                          size: 40,
                                          color: AppConstants.textLightColor,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.storefront_rounded,
                                      size: 40,
                                      color: AppConstants.textLightColor,
                                    ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppConstants.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
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
                          color: AppConstants.errorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            TextField(
              controller: _shopNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Toko *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopPhoneController,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon Toko',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shopAddressController,
              decoration: const InputDecoration(
                labelText: 'Alamat Toko',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiptHeaderController,
              decoration: const InputDecoration(
                labelText: 'Header Struk (Pesan Terima Kasih)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiptFooterController,
              decoration: const InputDecoration(
                labelText: 'Footer Struk (Catatan Penjualan)',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UI Widget Preview Struk Kertas Real-time
  Widget _buildReceiptPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Live Preview Struk'),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: Column(
              children: [
                // Logo preview di struk
                if (_logoImageFile != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Image.file(_logoImageFile!, height: 50, width: 50, fit: BoxFit.cover),
                  )
                else if (_existingLogoPath != null && _existingLogoPath!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Image.file(File(_existingLogoPath!), height: 50, width: 50, fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => const SizedBox(),
                    ),
                  ),
                
                // Info header toko
                Text(
                  _shopNameController.text.isEmpty ? 'NAMA TOKO ANDA' : _shopNameController.text.toUpperCase(),
                  style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                if (_shopAddressController.text.isNotEmpty)
                  Text(
                    _shopAddressController.text,
                    style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                if (_shopPhoneController.text.isNotEmpty)
                  Text(
                    'Telp: ${_shopPhoneController.text}',
                    style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 8),
                Text(
                  '- - - - - - - - - - - - - - - -',
                  style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
                ),
                
                // Info detail transaksi dummy
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nota : TRX-YYYYMMDD-0001', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black54)),
                      Text('Tgl  : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black54)),
                      Text('Kasir: Admin', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                Text(
                  '- - - - - - - - - - - - - - - -',
                  style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
                ),
                
                // Item dummy list belanja
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTOH BARANG 1', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1.000 Pcs x 25.000', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                          Text('25.000', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('CONTOH BARANG 2', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('2.000 Pcs x 15.000', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                          Text('30.000', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Text(
                  '- - - - - - - - - - - - - - - -',
                  style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
                ),
                
                // Total detail dummy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                    Text('55.000', style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bayar (Tunai)', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                    Text('100.000', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kembalian', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                    Text('45.000', style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87)),
                  ],
                ),
                
                Text(
                  '- - - - - - - - - - - - - - - -',
                  style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black38),
                ),
                
                // Struk header & footer
                if (_receiptHeaderController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _receiptHeaderController.text,
                    style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_receiptFooterController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _receiptFooterController.text,
                    style: GoogleFonts.courierPrime(fontSize: 11, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppConstants.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppConstants.textDarkColor,
          ),
        ),
      ],
    );
  }
}
