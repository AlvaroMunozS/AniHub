import 'package:anihub/ui/format/byte_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps small sizes in bytes', () {
    expect(formatByteSize(0, 'es'), '0 B');
    expect(formatByteSize(999, 'es'), '999 B');
  });

  test('uses the largest unit with at most one decimal', () {
    expect(formatByteSize(1000, 'en'), '1 KB');
    expect(formatByteSize(12400000, 'en'), '12.4 MB');
    expect(formatByteSize(3250000000, 'en'), '3.3 GB');
  });

  test('follows the decimal separator of the locale', () {
    expect(formatByteSize(12400000, 'es'), '12,4 MB');
  });

  test('moves up a unit instead of rounding to 1000', () {
    expect(formatByteSize(999960, 'en'), '1 MB');
  });
}
