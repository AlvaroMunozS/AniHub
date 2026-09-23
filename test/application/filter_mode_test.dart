import 'package:anihub/application/usecases/usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cycles any, only, exclude and back to any', () {
    expect(FilterMode.any.next, FilterMode.only);
    expect(FilterMode.only.next, FilterMode.exclude);
    expect(FilterMode.exclude.next, FilterMode.any);
  });

  test('matches every value, only true or only false', () {
    expect(<bool>[true, false].map(FilterMode.any.matches), <bool>[true, true]);
    expect(<bool>[true, false].map(FilterMode.only.matches), <bool>[
      true,
      false,
    ]);
    expect(<bool>[true, false].map(FilterMode.exclude.matches), <bool>[
      false,
      true,
    ]);
  });
}
