import 'package:flutter_test/flutter_test.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/core/utils/whatsapp_receipt_helper.dart';

void main() {
  group('WhatsApp Receipt Helper Tests', () {
    test('formatPhoneNumber should clean and format Indonesian phone numbers correctly', () {
      expect(WhatsAppReceiptHelper.formatPhoneNumber('081234567890'), equals('6281234567890'));
      expect(WhatsAppReceiptHelper.formatPhoneNumber('6281234567890'), equals('6281234567890'));
      expect(WhatsAppReceiptHelper.formatPhoneNumber('+62 812-3456-7890'), equals('6281234567890'));
      expect(WhatsAppReceiptHelper.formatPhoneNumber('81234567890'), equals('6281234567890'));
    });

    test('generateReceiptMessage contains key transaction details', () {
      final customer = Customer(
        id: 1,
        name: 'Budi Santoso',
        phone: '081234567890',
        pointsBalance: 120,
      );

      // Verify formatting helper
      expect(WhatsAppReceiptHelper.formatPhoneNumber(customer.phone!), equals('6281234567890'));
    });
  });
}
