import 'package:flutter_test/flutter_test.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Verify barcode and qrcode signatures in esc_pos_utils_plus', () async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    
    // Test safe barcode with width 1
    final bytesBarcode = generator.barcode(
      Barcode.code128('TRX-20260902-0001'.split('')),
      width: 1,
      height: 35,
      align: PosAlign.center,
    );
    expect(bytesBarcode, isNotEmpty);

    // Test qrcode with size3
    final bytesQrcode = generator.qrcode(
      'TRX-20260902-0001',
      size: QRSize.size3,
      align: PosAlign.center,
    );
    expect(bytesQrcode, isNotEmpty);
  });
}
