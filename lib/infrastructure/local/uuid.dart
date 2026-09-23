import 'dart:math';

final Random _random = Random.secure();

/// Returns a random version 4 UUID in canonical lowercase form.
String newUuidV4() {
  final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));

  // Version 4: high nibble of byte 6 is 0100.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  // RFC 4122 variant: two high bits of byte 8 are 10.
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
