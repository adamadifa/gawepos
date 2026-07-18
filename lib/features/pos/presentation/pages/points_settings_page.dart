import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';

class PointsSettingsPage extends StatefulWidget {
  const PointsSettingsPage({super.key});

  @override
  State<PointsSettingsPage> createState() => _PointsSettingsPageState();
}

class _PointsSettingsPageState extends State<PointsSettingsPage> {
  final SalesRepository _salesRepository = getIt<SalesRepository>();

  bool _enabled = false;
  final _earnRateController = TextEditingController();
  final _redeemValueController = TextEditingController();
  final _minRedeemController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _earnRateController.dispose();
    _redeemValueController.dispose();
    _minRedeemController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await _salesRepository.getPointsSettings();
    final enabledStr = await _salesRepository.getSetting('points_enabled');

    setState(() {
      _enabled = enabledStr == '1';
      _earnRateController.text = settings['earnRate'].toString();
      _redeemValueController.text = settings['redeemValue'].toString();
      _minRedeemController.text = settings['minRedeem'].toString();
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final earnRate = int.tryParse(_earnRateController.text);
    final redeemValue = int.tryParse(_redeemValueController.text);
    final minRedeem = int.tryParse(_minRedeemController.text);

    if (earnRate == null || earnRate < 1) {
      _showError('Nilai tukar poin (Rupiah) harus diisi dengan angka minimal 1.');
      return;
    }
    if (redeemValue == null || redeemValue < 1) {
      _showError('Nilai 1 poin dalam Rupiah harus diisi dengan angka minimal 1.');
      return;
    }
    if (minRedeem == null || minRedeem < 1) {
      _showError('Poin minimal tukar harus diisi dengan angka minimal 1.');
      return;
    }

    await _salesRepository.saveSetting('points_enabled', _enabled ? '1' : '0');
    await _salesRepository.saveSetting('points_earn_rate', earnRate.toString());
    await _salesRepository.saveSetting('points_redeem_value', redeemValue.toString());
    await _salesRepository.saveSetting('points_min_redeem', minRedeem.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan poin berhasil disimpan!')),
      );
      Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppConstants.primaryColor;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Pengaturan Poin',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: themeColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
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
                        _buildSectionHeader('Aktifkan Poin Pelanggan'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Izinkan pelanggan mengumpulkan dan menukarkan poin dari transaksi.',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              activeTrackColor: themeColor,
                              onChanged: (v) => setState(() => _enabled = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
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
                        _buildSectionHeader('Nilai Tukar Poin'),
                        const SizedBox(height: 16),
                        Text(
                          'Setiap Rp berapa pelanggan mendapat 1 poin?',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _earnRateController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '1000',
                            prefixText: 'Rp ',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '1 poin = Rp ... diskon?',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _redeemValueController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '10',
                            prefixText: '1 poin = Rp ',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Poin minimal yang bisa ditukarkan dalam sekali transaksi.',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _minRedeemController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '100',
                            prefixText: 'Min. ',
                            suffixText: ' poin',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
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
                        _buildSectionHeader('Informasi'),
                        const SizedBox(height: 8),
                        Text(
                          'Contoh:\n'
                          '- Jika "Nilai Tukar" = Rp 1.000, pembelian Rp 50.000 = 50 poin.\n'
                          '- Jika "1 poin = Rp 10", menukar 250 poin = 250 × 10 = Rp 2.500 diskon.\n'
                          '- Minimal penukaran = 100 poin (poin kurang dari 100 tidak bisa ditukar).',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
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
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppConstants.textDarkColor,
          ),
        ),
      ],
    );
  }
}
