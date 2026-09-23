import 'package:anihub/domain/values/relation_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every known relation type', () {
    for (final RelationKind kind in RelationKind.values) {
      expect(RelationKind.tryFromWire(kind.wire), kind);
    }
  });

  test('returns null for an unknown relation type', () {
    expect(RelationKind.tryFromWire('adaptation'), isNull);
  });

  test('returns null for a missing relation type', () {
    expect(RelationKind.tryFromWire(null), isNull);
  });
}
