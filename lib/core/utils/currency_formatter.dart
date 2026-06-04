import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern('id_ID');

  static String format(double value) {
    return _rupiahFormat.format(value);
  }

  static String formatQty(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return _numberFormat.format(value);
  }
}
