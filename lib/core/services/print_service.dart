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

  // Format baris 2 kolom (Kiri rata kiri, Kanan rata kanan) anti-turun-baris
  String _formatRow(String left, String right, int maxWidth) {
    final rightClean = right.trim();
    if (left.length + rightClean.length + 1 > maxWidth) {
      final maxLeftLen = maxWidth - rightClean.length - 1;
      final safeLeft = maxLeftLen > 0 ? left.substring(0, maxLeftLen) : '';
      final spaces = maxWidth - safeLeft.length - rightClean.length;
      return "$safeLeft${' ' * (spaces > 0 ? spaces : 1)}$rightClean";
    }
    final spaces = maxWidth - left.length - rightClean.length;
    return "$left${' ' * spaces}$rightClean";
  }

  String _separator(int width) => '-' * width;

  // Test Print
  Future<bool> printTest(String deviceName, String macAddress) async {
    final connected = await connect(macAddress);
    if (!connected) return false;

    try {
      final paperSizeStr = await _salesRepository.getSetting('printer_paper_size') ?? '58';
      final paperSize = paperSizeStr == '80' ? PaperSize.mm80 : PaperSize.mm58;
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      final shopLogoPath = await _salesRepository.getSetting('shop_logo') ?? '';
      final printLogoStr = await _salesRepository.getSetting('printer_print_logo') ?? '1';

      if (printLogoStr == '1' && shopLogoPath.isNotEmpty) {
        final logoFile = File(shopLogoPath);
        if (await logoFile.exists()) {
          try {
            final bytesLogo = await logoFile.readAsBytes();
            final imgDecoded = img.decodeImage(bytesLogo);
            if (imgDecoded != null) {
              img.Image processedImg = imgDecoded;
              if (processedImg.hasAlpha) {
                final flat = img.Image(
                  width: processedImg.width,
                  height: processedImg.height,
                  numChannels: 3,
                );
                img.fill(flat, color: img.ColorRgb8(255, 255, 255));
                img.compositeImage(flat, processedImg);
                processedImg = flat;
              }

              final targetWidth = paperSize == PaperSize.mm80 ? 240 : 160;
              final resizedImg = img.copyResize(processedImg, width: targetWidth);
              final grayscaleImg = img.grayscale(resizedImg);

              try {
                bytes += generator.imageRaster(grayscaleImg, align: PosAlign.center);
              } catch (_) {
                try {
                  bytes += generator.image(grayscaleImg, align: PosAlign.center);
                } catch (_) {}
              }
              bytes += generator.feed(1);
            }
          } catch (_) {}
        }
      }

      bytes += generator.text("=== TEST KONEKSI PRINTER ===", styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("GawePOS - Kasir UMKM", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Printer: $deviceName", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("MAC: $macAddress", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Format Kertas: ${paperSizeStr}mm", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("--------------------------------", styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text("Printer berhasil terhubung dan siap digunakan!", styles: const PosStyles(align: PosAlign.center));
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
    final int pointsEarned = details['pointsEarned'] as int? ?? 0;
    final int pointsRedeemed = details['pointsRedeemed'] as int? ?? 0;

    // 4. Ambil setting detail toko & printer
    final shopName = await _salesRepository.getSetting('shop_name') ?? 'Toko POS Mobile';
    final shopPhone = await _salesRepository.getSetting('shop_phone') ?? '';
    final shopAddress = await _salesRepository.getSetting('shop_address') ?? '';
    final receiptHeader = await _salesRepository.getSetting('receipt_header') ?? 'TERIMA KASIH TELAH BERBELANJA';
    final receiptFooter = await _salesRepository.getSetting('receipt_footer') ?? '';
    final shopLogoPath = await _salesRepository.getSetting('shop_logo') ?? '';
    final paperSizeStr = await _salesRepository.getSetting('printer_paper_size') ?? '58';
    final paperSize = paperSizeStr == '80' ? PaperSize.mm80 : PaperSize.mm58;
    final printLogoStr = await _salesRepository.getSetting('printer_print_logo') ?? '1';
    final printBarcodeStr = await _salesRepository.getSetting('printer_print_barcode') ?? '1';
    final duplicateStr = await _salesRepository.getSetting('printer_duplicate') ?? '0';
    final int printCount = duplicateStr == '1' ? 2 : 1;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      final int printWidth = paperSize == PaperSize.mm80 ? 48 : 32;

      for (int copy = 0; copy < printCount; copy++) {
        if (copy > 0) {
          bytes += generator.text("=== SALINAN KASIR / ARSIP ===", styles: const PosStyles(align: PosAlign.center, bold: true));
        }

        // --- LOGO TOKO ---
        if (printLogoStr == '1' && shopLogoPath.isNotEmpty) {
          final logoFile = File(shopLogoPath);
          if (await logoFile.exists()) {
            try {
              final bytesLogo = await logoFile.readAsBytes();
              final imgDecoded = img.decodeImage(bytesLogo);
              if (imgDecoded != null) {
                // Konversi gambar jika ada transparansi PNG menjadi background putih
                img.Image processedImg = imgDecoded;
                if (processedImg.hasAlpha) {
                  final flat = img.Image(
                    width: processedImg.width,
                    height: processedImg.height,
                    numChannels: 3,
                  );
                  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
                  img.compositeImage(flat, processedImg);
                  processedImg = flat;
                }

                final targetWidth = paperSize == PaperSize.mm80 ? 240 : 160;
                final resizedImg = img.copyResize(processedImg, width: targetWidth);
                final grayscaleImg = img.grayscale(resizedImg);

                try {
                  bytes += generator.imageRaster(grayscaleImg, align: PosAlign.center);
                } catch (_) {
                  try {
                    bytes += generator.image(grayscaleImg, align: PosAlign.center);
                  } catch (_) {}
                }
                bytes += generator.feed(1);
              }
            } catch (_) {}
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
      bytes += generator.text(_separator(printWidth), styles: const PosStyles(align: PosAlign.center));

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
      // Barcode / QR Code transaksi (Aman dari Wide Error di printer 58mm & 80mm)
      if (printBarcodeStr == '1') {
        try {
          bytes += generator.feed(1);
          bytes += generator.qrcode(
            order.referenceNo,
            size: paperSize == PaperSize.mm80 ? QRSize.size4 : QRSize.size3,
            align: PosAlign.center,
          );
          bytes += generator.feed(1);
        } catch (_) {
          try {
            bytes += generator.barcode(
              Barcode.code128(order.referenceNo.split('')),
              width: 1,
              height: 35,
              align: PosAlign.center,
            );
          } catch (_) {}
        }
      }
      bytes += generator.text(_separator(printWidth), styles: const PosStyles(align: PosAlign.center));

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
        
        final leftCol = " $qtyStr $unitName x $priceStr";
        bytes += generator.text(_formatRow(leftCol, itemSubtotalStr, printWidth));
        
        // Jika ada catatan racikan/dapur khusus per item
        if (item.notes != null && item.notes!.isNotEmpty) {
          bytes += generator.text("  * Note: ${item.notes}", styles: const PosStyles(fontType: PosFontType.fontB));
        }

        // Jika ada diskon per item
        if (item.discountAmount > 0) {
          final discStr = "-${_formatCurr(item.discountAmount)}";
          bytes += generator.text(_formatRow("  Diskon Item", discStr, printWidth));
        }
      }
      bytes += generator.text(_separator(printWidth), styles: const PosStyles(align: PosAlign.center));

      // --- SUMMARY FOOTER ---
      final subtotalStr = _formatCurr(order.subtotal);
      final grandTotalStr = _formatCurr(order.grandTotal);
      
      bytes += generator.text(_formatRow("Subtotal", subtotalStr, printWidth));
      
      // Cetak Rincian Diskon Promosi (BOGO / Diskon Min Belanja / Tebus Murah)
      final List<OrderPromotion> promoList = details['promotions'] as List<OrderPromotion>? ?? [];
      double totalPromoDiscounts = 0.0;
      for (var p in promoList) {
        totalPromoDiscounts += p.discountAmount;
        final promoDiscStr = "-${_formatCurr(p.discountAmount)}";
        final promoLabel = "Promo: ${p.promotionName}";
        bytes += generator.text(_formatRow(promoLabel, promoDiscStr, printWidth));
      }

      final double remainingDiscount = order.discountAmount - totalPromoDiscounts;
      if (remainingDiscount > 0) {
        final discStr = "-${_formatCurr(remainingDiscount)}";
        bytes += generator.text(_formatRow("Diskon Tambahan", discStr, printWidth));
      } else if (order.discountAmount > 0 && promoList.isEmpty) {
        final discStr = "-${_formatCurr(order.discountAmount)}";
        bytes += generator.text(_formatRow("Diskon Global", discStr, printWidth));
      }
      
      if (order.taxAmount > 0) {
        final taxStr = _formatCurr(order.taxAmount);
        bytes += generator.text(_formatRow("Pajak", taxStr, printWidth));
      }
      
      bytes += generator.text(_formatRow("GRAND TOTAL", grandTotalStr, printWidth), styles: const PosStyles(bold: true));
      bytes += generator.text(_separator(printWidth), styles: const PosStyles(align: PosAlign.center));

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
        bytes += generator.text(_formatRow("Bayar ($payMethodName)", payAmountStr, printWidth));
      }

      if (order.changeAmount > 0) {
        final changeStr = _formatCurr(order.changeAmount);
        bytes += generator.text(_formatRow("Kembalian", changeStr, printWidth));
      }

      bytes += generator.text(_separator(printWidth), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(1);

      // --- POIN ---
      if (pointsEarned > 0 || pointsRedeemed > 0) {
        bytes += generator.text(_separator(printWidth), styles: const PosStyles(align: PosAlign.center));
        if (pointsEarned > 0) {
          bytes += generator.text("Poin didapat: +$pointsEarned", styles: const PosStyles(align: PosAlign.center));
        }
        if (pointsRedeemed > 0) {
          bytes += generator.text("Poin ditukar: -$pointsRedeemed", styles: const PosStyles(align: PosAlign.center));
        }
        bytes += generator.feed(1);
      }

      // --- FOOTER CUSTOM NOTES ---
      if (receiptHeader.isNotEmpty) {
        bytes += generator.text(receiptHeader, styles: const PosStyles(align: PosAlign.center));
      }
      if (receiptFooter.isNotEmpty) {
        bytes += generator.text(receiptFooter, styles: const PosStyles(align: PosAlign.center));
      }

        bytes += generator.feed(2);
        bytes += generator.cut();
      }

      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }
}
