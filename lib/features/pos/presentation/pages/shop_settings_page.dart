import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
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

    setState(() {
      _shopNameController.text = shopName ?? '';
      _shopPhoneController.text = shopPhone ?? '';
      _shopAddressController.text = shopAddress ?? '';
      _receiptHeaderController.text = rHeader ?? '';
      _receiptFooterController.text = rFooter ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    await _salesRepository.saveSetting('shop_name', _shopNameController.text.trim());
    await _salesRepository.saveSetting('shop_phone', _shopPhoneController.text.trim());
    await _salesRepository.saveSetting('shop_address', _shopAddressController.text.trim());
    await _salesRepository.saveSetting('receipt_header', _receiptHeaderController.text.trim());
    await _salesRepository.saveSetting('receipt_footer', _receiptFooterController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan toko berhasil disimpan!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          : ListView(
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
