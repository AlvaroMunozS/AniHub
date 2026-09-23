import 'package:intl/intl.dart';

const List<String> _units = <String>['B', 'KB', 'MB', 'GB'];

/// Returns [bytes] in the largest unit that keeps the number at 1 or more,
/// with at most one decimal in the number format of [locale].
///
/// Units are powers of 1000, as in Android's storage settings.
String formatByteSize(int bytes, String locale) {
  double value = bytes.toDouble();
  int unit = 0;
  // 999.95 and above would round up to "1000" in the smaller unit.
  while (value >= 999.95 && unit < _units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${NumberFormat('0.#', locale).format(value)} ${_units[unit]}';
}
