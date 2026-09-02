import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrintService _printService = getIt<PrintService>();
  final SalesRepository _salesRepository = getIt<SalesRepository>();

  List<BluetoothDevice> _devices = [];
  bool _isBluetoothOn = false;
  String? _selectedMac;
  String? _selectedName;
  String _paperSize = '58'; // '58' or '80'
  bool _autoPrint = true;
  bool _duplicateReceipt = false;
  bool _printLogo = true;
  bool _printBarcode = true;

  bool _isLoadingDevices = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBluetoothAndLoadDevices();
  }

  Future<void> _loadSettings() async {
    final mac = await _salesRepository.getSetting('printer_address');
    final name = await _salesRepository.getSetting('printer_name');
    final paperSize = await _salesRepository.getSetting('printer_paper_size') ?? '58';
    final autoPrint = (await _salesRepository.getSetting('printer_auto_print') ?? '1') == '1';
    final duplicate = (await _salesRepository.getSetting('printer_duplicate') ?? '0') == '1';
    final printLogo = (await _salesRepository.getSetting('printer_print_logo') ?? '1') == '1';
    final printBarcode = (await _salesRepository.getSetting('printer_print_barcode') ?? '1') == '1';

    if (mounted) {
      setState(() {
        _selectedMac = mac;
        _selectedName = name;
        _paperSize = paperSize;
        _autoPrint = autoPrint;
        _duplicateReceipt = duplicate;
        _printLogo = printLogo;
        _printBarcode = printBarcode;
      });
    }
  }

  Future<void> _checkBluetoothAndLoadDevices() async {
    setState(() {
      _isLoadingDevices = true;
    });

    final available = await _printService.isBluetoothAvailable();
    if (available) {
      final list = await _printService.getPairedDevices();
      if (mounted) {
        setState(() {
          _isBluetoothOn = true;
          _devices = list;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isBluetoothOn = false;
          _devices = [];
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingDevices = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_selectedMac != null) {
      await _salesRepository.saveSetting('printer_address', _selectedMac!);
      await _salesRepository.saveSetting('printer_name', _selectedName ?? '');
    }
    await _salesRepository.saveSetting('printer_paper_size', _paperSize);
    await _salesRepository.saveSetting('printer_auto_print', _autoPrint ? '1' : '0');
    await _salesRepository.saveSetting('printer_duplicate', _duplicateReceipt ? '1' : '0');
    await _salesRepository.saveSetting('printer_print_logo', _printLogo ? '1' : '0');
    await _salesRepository.saveSetting('printer_print_barcode', _printBarcode ? '1' : '0');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Pengaturan printer berhasil disimpan!', style: GoogleFonts.poppins(fontSize: 12.5)),
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

  Future<void> _testPrint(String name, String mac) async {
    setState(() {
      _isTesting = true;
    });

    await _salesRepository.saveSetting('printer_paper_size', _paperSize);
    final success = await _printService.printTest(name, mac);

    if (mounted) {
      setState(() {
        _isTesting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Test print struk berhasil dicetak!', style: GoogleFonts.poppins(fontSize: 12.5)),
              ],
            ),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Gagal menghubungkan ke printer! Pastikan printer menyala.', style: GoogleFonts.poppins(fontSize: 12.5)),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
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
              'Pengaturan Printer',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Printer Bluetooth kasir, format kertas & opsi cetak',
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Pindai Ulang Bluetooth',
            onPressed: _checkBluetoothAndLoadDevices,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Simpan Pengaturan',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ─── 1. HERO ACTIVE PRINTER STATUS ─────────────────────────
              _buildHeroPrinterCard(),
              const SizedBox(height: 18),

              // ─── 2. UKURAN KERTAS STRUK (PAPER SIZE) ────────────────────
              _buildPaperSizeSection(),
              const SizedBox(height: 18),

              // ─── 3. PREFERENSI CETAK TRANSAKSI ──────────────────────────
              _buildPrintPreferencesSection(),
              const SizedBox(height: 18),

              // ─── 4. DAFTAR PERANGKAT BLUETOOTH DIPASANGKAN ─────────────
              _buildPairedDevicesSection(),
              const SizedBox(height: 18),

              // ─── 5. PANDUAN PENGHUBUNGAN PRINTER ─────────────────────────
              _buildTroubleshootingGuide(),
              const SizedBox(height: 24),

              // ─── 6. TOMBOL SIMPAN ───────────────────────────────────────
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'SIMPAN PENGATURAN PRINTER',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ],
          ),

          // Loading overlay during test print
          if (_isTesting)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF0F172A)),
                      const SizedBox(height: 16),
                      Text(
                        'Menghubungkan ke Printer...',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mengirim perintah cetak struk uji coba',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── HERO ACTIVE PRINTER CARD ─────────────────────────────────────────────
  Widget _buildHeroPrinterCard() {
    final bool hasSelectedPrinter = _selectedMac != null && _selectedMac!.isNotEmpty;
    final bool isReady = hasSelectedPrinter && _isBluetoothOn;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReady
                        ? const Color(0xFF059669).withValues(alpha: 0.2)
                        : (!_isBluetoothOn
                            ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                            : const Color(0xFFD97706).withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isReady
                          ? const Color(0xFF059669).withValues(alpha: 0.4)
                          : (!_isBluetoothOn
                              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                              : const Color(0xFFD97706).withValues(alpha: 0.4)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isReady
                              ? const Color(0xFF34D399)
                              : (!_isBluetoothOn ? const Color(0xFFF87171) : const Color(0xFFFBBF24)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isReady
                              ? 'PRINTER AKTIF'
                              : (!_isBluetoothOn ? 'BLUETOOTH MATI' : 'BELUM ADA PRINTER'),
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isReady
                                ? const Color(0xFF34D399)
                                : (!_isBluetoothOn ? const Color(0xFFF87171) : const Color(0xFFFBBF24)),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Format: ${_paperSize}mm',
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Printer Details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSelectedPrinter ? (_selectedName ?? 'Printer Thermal') : 'Belum Ada Printer Dipilih',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSelectedPrinter ? (_selectedMac ?? '') : 'Pilih printer Bluetooth dari daftar di bawah',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Action Buttons
          if (hasSelectedPrinter)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _testPrint(_selectedName ?? 'Printer', _selectedMac!),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      'TES CETAK STRUK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMac = null;
                      _selectedName = null;
                    });
                  },
                  child: Text(
                    'Putuskan',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11.5, color: Colors.white70),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── PAPER SIZE SECTION ───────────────────────────────────────────────────
  Widget _buildPaperSizeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Ukuran Lebar Kertas Struk'),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              // 58mm Option
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paperSize = '58'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _paperSize == '58' ? const Color(0xFF1A56DB).withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _paperSize == '58' ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
                        width: _paperSize == '58' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _paperSize == '58' ? const Color(0xFF1A56DB) : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 16),
                            ),
                            if (_paperSize == '58')
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF1A56DB), size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '58 mm',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Standar Mobile Mini (32 Karakter)',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 80mm Option
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _paperSize = '80'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _paperSize == '80' ? const Color(0xFF1A56DB).withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _paperSize == '80' ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
                        width: _paperSize == '80' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _paperSize == '80' ? const Color(0xFF1A56DB) : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                            ),
                            if (_paperSize == '80')
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF1A56DB), size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '80 mm',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Printer Desktop Kasir (48 Karakter)',
                          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── PRINT PREFERENCES SECTION ───────────────────────────────────────────
  Widget _buildPrintPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Preferensi Cetak Transaksi'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          _buildSwitchTile(
            title: 'Cetak Struk Otomatis',
            subtitle: 'Otomatis mengirim instruksi cetak begitu transaksi berhasil dibayar.',
            value: _autoPrint,
            icon: Icons.flash_on_rounded,
            iconColor: const Color(0xFF0284C7),
            onChanged: (v) => setState(() => _autoPrint = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildSwitchTile(
            title: 'Cetak 2 Rangkap Struk',
            subtitle: 'Cetak 2 lembar: 1 untuk struk pembeli & 1 salinan arsip toko kasir.',
            value: _duplicateReceipt,
            icon: Icons.file_copy_rounded,
            iconColor: const Color(0xFF7C3AED),
            onChanged: (v) => setState(() => _duplicateReceipt = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildSwitchTile(
            title: 'Cetak Logo Toko di Header',
            subtitle: 'Sertakan gambar logo toko di bagian atas lembar kertas struk.',
            value: _printLogo,
            icon: Icons.image_rounded,
            iconColor: const Color(0xFF059669),
            onChanged: (v) => setState(() => _printLogo = v),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          _buildSwitchTile(
            title: 'Cetak QR Code / Barcode Nomor Nota',
            subtitle: 'Sertakan QR Code nomor transaksi di struk agar mudah dipindai tanpa error lebar kertas.',
            value: _printBarcode,
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFFD97706),
            onChanged: (v) => setState(() => _printBarcode = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: const Color(0xFF0F172A),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ─── PAIRED DEVICES SECTION ───────────────────────────────────────────────
  Widget _buildPairedDevicesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildSectionHeader('Daftar Perangkat Bluetooth'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: _checkBluetoothAndLoadDevices,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0F172A)),
                label: Text(
                  'Pindai',
                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          if (!_isBluetoothOn)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_disabled_rounded, color: Color(0xFFDC2626), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bluetooth nonaktif atau tidak terdeteksi. Silakan aktifkan Bluetooth di menu pengaturan perangkat Anda.',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            )
          else if (_isLoadingDevices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              ),
            )
          else if (_devices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.print_disabled_rounded, size: 30, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada printer Bluetooth dipasangkan.',
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Silakan buka Pengaturan Bluetooth di ponsel/tablet Anda, cari nama printer thermal kasir, dan hubungkan (PIN: 0000 atau 1234).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final dev = _devices[index];
                final isSelected = _selectedMac == dev.address;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMac = dev.address;
                      _selectedName = dev.name;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1A56DB).withValues(alpha: 0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1A56DB).withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1A56DB).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            color: isSelected ? const Color(0xFF1A56DB) : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dev.name ?? 'Printer Bluetooth',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A56DB).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'TERPILIH',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1A56DB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dev.address ?? '',
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _testPrint(dev.name ?? 'Printer', dev.address ?? ''),
                          child: Text(
                            'TEST',
                            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── TROUBLESHOOTING GUIDE ────────────────────────────────────────────────
  Widget _buildTroubleshootingGuide() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, size: 18, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Text(
                'Petunjuk Menghubungkan Printer Thermal',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildGuideStep('1', 'Nyalakan printer thermal kasir dan pastikan kertas struk terpasang dengan benar.'),
          const SizedBox(height: 6),
          _buildGuideStep('2', 'Buka menu Pengaturan Bluetooth di ponsel/tablet, cari nama printer, dan sambungkan (PIN pairing default biasanya 0000 atau 1234).'),
          const SizedBox(height: 6),
          _buildGuideStep('3', 'Kembali ke halaman ini, tekan tombol "Pindai", lalu ketuk nama printer untuk memilihnya sebagai printer aktif.'),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF475569), height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
