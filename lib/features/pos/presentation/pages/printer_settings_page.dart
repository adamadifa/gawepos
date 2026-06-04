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
  bool _isLoadingDevices = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBluetoothAndLoadDevices();
  }

  Future<void> _loadSettings() async {
    final mac = await _salesRepository.getSetting('printer_address');
    final name = await _salesRepository.getSetting('printer_name');
    setState(() {
      _selectedMac = mac;
      _selectedName = name;
    });
  }

  Future<void> _checkBluetoothAndLoadDevices() async {
    setState(() {
      _isLoadingDevices = true;
    });

    final available = await _printService.isBluetoothAvailable();
    if (available) {
      final list = await _printService.getPairedDevices();
      setState(() {
        _isBluetoothOn = true;
        _devices = list;
      });
    } else {
      setState(() {
        _isBluetoothOn = false;
        _devices = [];
      });
    }

    setState(() {
      _isLoadingDevices = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_selectedMac != null) {
      await _salesRepository.saveSetting('printer_address', _selectedMac!);
      await _salesRepository.saveSetting('printer_name', _selectedName ?? '');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan printer berhasil disimpan!')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _testPrint(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    final success = await _printService.printTest(device.name ?? 'Printer', device.address ?? '');
    
    setState(() {
      _isConnecting = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print berhasil dikirim!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghubungkan atau mencetak ke printer!'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Pengaturan Printer',
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
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPrinterSection(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  'SIMPAN PENGATURAN',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_isConnecting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Menghubungkan & Mencetak...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrinterSection() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Printer Bluetooth Thermal'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppConstants.primaryColor),
                  onPressed: _checkBluetoothAndLoadDevices,
                  tooltip: 'Segarkan',
                ),
              ],
            ),
            const Divider(),
            if (!_isBluetoothOn)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bluetooth_disabled_rounded, color: AppConstants.errorColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bluetooth mati atau tidak didukung. Pastikan bluetooth perangkat Anda aktif.',
                        style: TextStyle(fontSize: 12, color: AppConstants.errorColor),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isLoadingDevices)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_devices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Tidak ada perangkat Bluetooth dipasangkan (paired). Pasangkan printer thermal Anda terlebih dahulu di pengaturan perangkat Bluetooth.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppConstants.textLightColor),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final dev = _devices[index];
                  final isSelected = _selectedMac == dev.address;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.print_rounded,
                      color: isSelected ? AppConstants.primaryColor : AppConstants.textLightColor,
                    ),
                    title: Text(
                      dev.name ?? 'Perangkat Bluetooth',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(dev.address ?? '', style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _testPrint(dev),
                          child: const Text('TEST PRINT', style: TextStyle(fontSize: 11)),
                        ),
                        Radio<String>(
                          value: dev.address ?? '',
                          groupValue: _selectedMac ?? '',
                          onChanged: (val) {
                            setState(() {
                              _selectedMac = val;
                              _selectedName = dev.name;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
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
