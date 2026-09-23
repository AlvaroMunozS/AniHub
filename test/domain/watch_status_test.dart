import 'package:anihub/domain/values/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every known status', () {
    for (final WatchStatus status in WatchStatus.values) {
      expect(WatchStatus.fromWire(status.wire), status);
    }
  });

  test('throws an ArgumentError for an unknown status', () {
    expect(() => WatchStatus.fromWire('dropped'), throwsArgumentError);
  });
}
