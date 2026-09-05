import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/database/app_database.dart';
import '../../core/di/injection.dart';
import '../../features/pos/data/sales_repository.dart';

class WhatsAppReceiptHelper {
  /// Format nomor HP ke standar internasional Indonesia (628xxx)
  static String formatPhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('8')) {
      cleaned = '62$cleaned';
    }
    return cleaned;
  }

  /// Generate teks struk digital WhatsApp yang rapi dan terstruktur
  static Future<String> generateReceiptMessage({
    required Order order,
    required List<Map<String, dynamic>> items,
    required List<OrderPayment> payments,
    Customer? customer,
    String? cashierName,
    int pointsEarned = 0,
    int pointsRedeemed = 0,
  }) async {
    final salesRepo = getIt<SalesRepository>();
    final shopName = await salesRepo.getSetting('shop_name') ?? 'GawePOS Store';
    final shopPhone = await salesRepo.getSetting('shop_phone') ?? '';
    final shopAddress = await salesRepo.getSetting('shop_address') ?? '';
    final receiptHeader = await salesRepo.getSetting('receipt_header') ?? 'TERIMA KASIH TELAH BERBELANJA';
    final receiptFooter = await salesRepo.getSetting('receipt_footer') ?? 'Simpan struk digital ini sebagai bukti transaksi yang sah.';

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
    final buffer = StringBuffer();

    // Header Toko
    buffer.writeln('*$shopName*');
    if (shopAddress.isNotEmpty) buffer.writeln(shopAddress);
    if (shopPhone.isNotEmpty) buffer.writeln('Telp/WA: $shopPhone');
    buffer.writeln('--------------------------------');
    buffer.writeln('🧾 *BUKTI PEMBAYARAN DIGITAL*');
    buffer.writeln('No. Nota : `${order.referenceNo}`');
    buffer.writeln('Waktu    : $dateStr');
    if (cashierName != null && cashierName.isNotEmpty) {
      buffer.writeln('Kasir    : $cashierName');
    }
    if (customer != null) {
      buffer.writeln('Pelanggan: ${customer.name}');
    }
    buffer.writeln('--------------------------------');

    // Rincian Item
    buffer.writeln('*RINCIAN BELANJA:*');
    for (var entry in items) {
      final item = entry['item'] as OrderItem;
      final product = entry['product'] as Product?;
      final unit = entry['unit'] as ProductUnit?;

      final name = product?.name ?? 'Item #${item.productId}';
      final unitName = unit?.name ?? '';
      final qtyStr = CurrencyFormatter.formatQty(item.quantity);
      final priceStr = CurrencyFormatter.format(item.price);
      final subtotalStr = CurrencyFormatter.format(item.subtotal);

      buffer.writeln('• *$name*');
      buffer.writeln('  $qtyStr $unitName x $priceStr = $subtotalStr');
      if (item.discountAmount > 0) {
        buffer.writeln('  _(Disc Item: -${CurrencyFormatter.format(item.discountAmount)})_');
      }
    }
    buffer.writeln('--------------------------------');

    // Ringkasan Pembayaran
    buffer.writeln('Subtotal      : ${CurrencyFormatter.format(order.subtotal)}');
    if (order.discountAmount > 0) {
      buffer.writeln('Diskon Global : -${CurrencyFormatter.format(order.discountAmount)}');
    }
    if (order.taxAmount > 0) {
      buffer.writeln('Pajak (PPN)   : +${CurrencyFormatter.format(order.taxAmount)}');
    }
    buffer.writeln('*TOTAL AKHIR  : ${CurrencyFormatter.format(order.grandTotal)}*');
    buffer.writeln('--------------------------------');

    // Metode Bayar
    for (var p in payments) {
      final methodUpper = p.paymentMethod.toUpperCase();
      buffer.writeln('Bayar ($methodUpper) : ${CurrencyFormatter.format(p.amount)}');
    }
    if (order.changeAmount > 0) {
      buffer.writeln('Kembalian     : ${CurrencyFormatter.format(order.changeAmount)}');
    }

    // Informasi Poin Loyalitas
    if (pointsEarned > 0 || pointsRedeemed > 0 || (customer != null && customer.pointsBalance > 0)) {
      buffer.writeln('--------------------------------');
      buffer.writeln('⭐ *POIN MEMBER*');
      if (pointsEarned > 0) buffer.writeln('Poin Didapat  : +$pointsEarned Poin');
      if (pointsRedeemed > 0) buffer.writeln('Poin Ditukar  : -$pointsRedeemed Poin');
      if (customer != null) buffer.writeln('Sisa Saldo    : ${customer.pointsBalance} Poin');
    }

    // Catatan Kaki / Footer
    buffer.writeln('--------------------------------');
    if (receiptHeader.isNotEmpty) buffer.writeln(receiptHeader);
    if (receiptFooter.isNotEmpty) buffer.writeln(receiptFooter);
    buffer.writeln('--------------------------------');
    buffer.writeln('_Dibuat otomatis oleh GawePOS_');

    return buffer.toString();
  }

  /// Buka aplikasi WhatsApp secara langsung ke nomor tujuan tertentu
  static Future<bool> openWhatsAppDirect({
    required String phoneNumber,
    required String message,
  }) async {
    final formattedPhone = formatPhoneNumber(phoneNumber);
    final encodedText = Uri.encodeComponent(message);

    // 1. Coba Deep Link WhatsApp Native App terlebih dahulu
    final nativeUri = Uri.parse('whatsapp://send?phone=$formattedPhone&text=$encodedText');
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 2. Fallback ke URL resmi wa.me / api.whatsapp.com
    final webUri = Uri.parse('https://wa.me/$formattedPhone?text=$encodedText');
    try {
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      final apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$formattedPhone&text=$encodedText');
      return await launchUrl(apiUri, mode: LaunchMode.externalApplication);
    }
  }

  /// Bagikan teks struk via Share dialog (Mendukung WhatsApp, Telegram, Salin Teks, dll.)
  static Future<void> shareReceiptText(String message, {String? subject}) async {
    await Share.share(
      message,
      subject: subject ?? 'Bukti Pembayaran Struk Digital',
    );
  }

  /// Tampilkan Bottom Sheet Modal Modern untuk memasukkan / mengonfirmasi Nomor WhatsApp Pelanggan
  static Future<void> showSendWhatsAppModal({
    required BuildContext context,
    required String receiptMessage,
    Customer? initialCustomer,
    String? defaultPhone,
  }) async {
    final phoneController = TextEditingController(
      text: defaultPhone ?? initialCustomer?.phone ?? '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header with WhatsApp Icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Color(0xFF25D366),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kirim Struk WhatsApp',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              initialCustomer != null
                                  ? 'Pelanggan: ${initialCustomer.name}'
                                  : 'Masukkan nomor WhatsApp pelanggan',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Phone Input Field
                  Text(
                    'Nomor WhatsApp',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    autofocus: phoneController.text.isEmpty,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 081234567890',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        child: Text(
                          '🇮🇩 +62',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: isDarkTheme ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF25D366),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Pesan struk belanja lengkap akan langsung terisi dan siap dikirimkan.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      // Opsi Share Lainnya
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            shareReceiptText(receiptMessage);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: isDarkTheme ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            'Lainnya',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Tombol Buka WhatsApp
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final rawPhone = phoneController.text.trim();
                            if (rawPhone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Silakan masukkan nomor WhatsApp terlebih dahulu.'),
                                  backgroundColor: Color(0xFFDC2626),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            try {
                              final success = await openWhatsAppDirect(
                                phoneNumber: rawPhone,
                                message: receiptMessage,
                              );
                              if (!success) {
                                // Fallback to share sheet
                                await shareReceiptText(receiptMessage);
                              }
                            } catch (_) {
                              await shareReceiptText(receiptMessage);
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          label: Text(
                            'Kirim WhatsApp',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
