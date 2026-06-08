import 'dart:io';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import '../../features/pos/data/sales_repository.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/database/app_database.dart';
import '../../core/di/injection.dart';

class PrintService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  final SalesRepository _salesRepository = getIt<SalesRepository>();

  // Check if bluetooth is available and turned on
  Future<bool> isBluetoothAvailable() async {
    final bool? isAvail = await _bluetooth.isAvailable;
    final bool? isOn = await _bluetooth.isOn;
    return (isAvail ?? false) && (isOn ?? false);
  }

  // Get paired/bonded devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  // Check if currently connected
  Future<bool> isConnected() async {
    final bool? connected = await _bluetooth.isConnected;
    return connected ?? false;
  }

  // Connect to device by MAC address
  Future<bool> connect(String macAddress) async {
    if (await isConnected()) {
      return true;
    }
    try {
      final devices = await getPairedDevices();
      final device = devices.firstWhere(
        (d) => d.address == macAddress,
        orElse: () => throw Exception('Device not found in bonded list'),
      );
      await _bluetooth.connect(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    if (await isConnected()) {
      await _bluetooth.disconnect();
    }
  }

  // Helper to format currency for receipt
  String _formatCurr(double amount) {
    return CurrencyFormatter.format(amount).replaceAll('Rp', '').trim();
  }

  // Test Print
  Future<bool> printTest(String deviceName, String macAddress) async {
    final connected = await connect(macAddress);
    if (!connected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.text("TEST KONEKSI PRINTER", styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(deviceName, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(macAddress, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  // Main Printing Method for Completed Orders
  Future<bool> printOrder(int orderId) async {
    // 1. Ambil MAC printer terdaftar
    final macAddress = await _salesRepository.getSetting('printer_address');
    if (macAddress == null || macAddress.isEmpty) {
      return false;
    }

    // 2. Hubungkan ke printer
    final connected = await connect(macAddress);
    if (!connected) return false;

    // 3. Ambil data order
    final details = await _salesRepository.getOrderDetails(orderId);
    if (details == null) return false;

    final Order order = details['order'];
    final List<Map<String, dynamic>> items = details['items'];
    final List<OrderPayment> payments = details['payments'];
    final Customer? customer = details['customer'];

    // 4. Ambil setting detail toko
    final shopName = await _salesRepository.getSetting('shop_name') ?? 'Toko POS Mobile';
    final shopPhone = await _salesRepository.getSetting('shop_phone') ?? '';
    final shopAddress = await _salesRepository.getSetting('shop_address') ?? '';
    final receiptHeader = await _salesRepository.getSetting('receipt_header') ?? 'TERIMA KASIH TELAH BERBELANJA';
    final receiptFooter = await _salesRepository.getSetting('receipt_footer') ?? '';
    final shopLogoPath = await _salesRepository.getSetting('shop_logo') ?? '';

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // --- LOGO TOKO ---
      if (shopLogoPath.isNotEmpty) {
        final logoFile = File(shopLogoPath);
        if (await logoFile.exists()) {
          try {
            final bytesLogo = await logoFile.readAsBytes();
            final imgDecoded = img.decodeImage(bytesLogo);
            if (imgDecoded != null) {
              // Resize image agar pas dengan lebar struk 58mm (misalnya lebar maksimal 180-200 pixel)
              final resizedImg = img.copyResize(imgDecoded, width: 180);
              bytes += generator.imageRaster(resizedImg, align: PosAlign.center);
              bytes += generator.feed(1);
            }
          } catch (_) {
            // Abaikan jika pemrosesan gambar gagal agar struk tetap tercetak
          }
        }
      }

      // --- HEADER ---
      bytes += generator.text(shopName, styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      if (shopAddress.isNotEmpty) {
        bytes += generator.text(shopAddress, styles: const PosStyles(align: PosAlign.center));
      }
      if (shopPhone.isNotEmpty) {
        bytes += generator.text("Telp: $shopPhone", styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));

      // --- INFO TRANSAKSI ---
      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
      bytes += generator.text("Nota : ${order.referenceNo}");
      bytes += generator.text("Tgl  : $dateStr");
      if (customer != null) {
        bytes += generator.text("Plg  : ${customer.name}");
      }
      if (order.notes != null && order.notes!.isNotEmpty) {
        bytes += generator.text("Ket  : ${order.notes}");
      }
      bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));

      // --- ITEMS ---
      for (var itemDetail in items) {
        final OrderItem item = itemDetail['item'];
        final Product? product = itemDetail['product'];
        final ProductUnit? unit = itemDetail['unit'];

        // Row 1: Nama Barang
        bytes += generator.text(product?.name ?? 'Produk Terhapus (ID: ${item.productId})', styles: const PosStyles(bold: true));
        
        // Row 2: Qty x Price dan Subtotal
        final qtyStr = item.quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
        final unitName = unit?.name ?? 'Satuan';
        final priceStr = _formatCurr(item.price);
        final itemSubtotalStr = _formatCurr(item.subtotal);
        
        // Buat detail row: "2.5 x 10.000             25.000"
        final leftCol = "$qtyStr $unitName x $priceStr";
        final spacesNeeded = 32 - leftCol.length - itemSubtotalStr.length;
        final spaces = spacesNeeded > 0 ? " " * spacesNeeded : " ";
        
        bytes += generator.text("$leftCol$spaces$itemSubtotalStr");
        
        // Jika ada diskon per item
        if (item.discountAmount > 0) {
          final discStr = "-${_formatCurr(item.discountAmount)}";
          final discLeftCol = "  Diskon Item";
          final discSpacesNeeded = 32 - discLeftCol.length - discStr.length;
          final discSpaces = discSpacesNeeded > 0 ? " " * discSpacesNeeded : " ";
          bytes += generator.text("$discLeftCol$discSpaces$discStr");
        }
      }
      bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));

      // --- SUMMARY FOOTER ---
      final subtotalStr = _formatCurr(order.subtotal);
      final grandTotalStr = _formatCurr(order.grandTotal);
      
      bytes += generator.text("Subtotal        : " + " " * (16 - subtotalStr.length) + subtotalStr);
      
      if (order.discountAmount > 0) {
        final discStr = "-${_formatCurr(order.discountAmount)}";
        bytes += generator.text("Diskon Global   : " + " " * (16 - discStr.length) + discStr);
      }
      
      if (order.taxAmount > 0) {
        final taxStr = _formatCurr(order.taxAmount);
        bytes += generator.text("Pajak           : " + " " * (16 - taxStr.length) + taxStr);
      }
      
      bytes += generator.text("Grand Total     : " + " " * (16 - grandTotalStr.length) + grandTotalStr, styles: const PosStyles(bold: true));
      bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));

      // --- PAYMENTS ---
      for (var p in payments) {
        final payMethodName = p.paymentMethod == 'cash'
            ? 'Tunai'
            : p.paymentMethod == 'qris'
                ? 'QRIS'
                : p.paymentMethod == 'card'
                    ? 'EDC/Kartu'
                    : 'Transfer';
        final payAmountStr = _formatCurr(p.amount);
        bytes += generator.text("$payMethodName            : " + " " * (16 - payAmountStr.length) + payAmountStr);
      }

      if (order.changeAmount > 0) {
        final changeStr = _formatCurr(order.changeAmount);
        bytes += generator.text("Kembalian       : " + " " * (16 - changeStr.length) + changeStr);
      }

      bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);

      // --- FOOTER CUSTOM NOTES ---
      if (receiptHeader.isNotEmpty) {
        bytes += generator.text(receiptHeader, styles: const PosStyles(align: PosAlign.center));
      }
      if (receiptFooter.isNotEmpty) {
        bytes += generator.text(receiptFooter, styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.feed(3);
      bytes += generator.cut();

      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }
}
