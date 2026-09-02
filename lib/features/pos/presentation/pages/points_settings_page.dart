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
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Pengaturan poin berhasil disimpan!', style: GoogleFonts.poppins(fontSize: 12.5)),
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 12.5)),
        backgroundColor: AppConstants.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              'Pengaturan Poin',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Program loyalitas perolehan & penukaran poin',
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
            onPressed: _save,
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Switch Card
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aktifkan Poin Pelanggan',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pelanggan otomatis mengumpulkan poin belanja.',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enabled,
                        activeThumbColor: const Color(0xFF0F172A),
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Form Values Card
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Nilai Konversi & Aturan Tukar'),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      Text(
                        'Setiap Pembelian Senilai (Dapat 1 Poin)',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _earnRateController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: '1000',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Text('Rp', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Nilai Tukar 1 Poin (Nominal Rupiah)',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _redeemValueController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: '10',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Text('1 Poin = Rp', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Minimal Poin untuk Penukaran',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _minRedeemController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: '100',
                          prefixIcon: const Icon(Icons.toll_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixText: 'poin',
                          suffixStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info Formula Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0F172A)),
                          const SizedBox(width: 8),
                          Text(
                            'Simulasi Perhitungan Poin',
                            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Jika Perolehan = Rp 1.000, transaksi Rp 50.000 akan menghasilkan 50 poin.\n'
                        '• Jika 1 Poin = Rp 10, maka 250 poin bernilai diskon potongan Rp 2.500.\n'
                        '• Pelanggan baru bisa menukarkan poin jika sudah mencapai batas minimal.',
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569), height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'SIMPAN PENGATURAN POIN',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
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
