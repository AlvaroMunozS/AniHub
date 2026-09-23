import 'package:anihub/domain/values/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

AppVersion _v(String raw) => AppVersion.tryParse(raw)!;

void main() {
  test('parses stable and pre-release versions, with or without a v', () {
    expect(_v('1.2.3').toString(), '1.2.3');
    expect(_v('v1.2.3').toString(), '1.2.3');
    expect(_v('1.2.3-beta.1').toString(), '1.2.3-beta.1');
    expect(_v('1.2.3').isPrerelease, isFalse);
    expect(_v('1.2.3-beta.1').isPrerelease, isTrue);
  });

  test('rejects anything that is not a semantic version', () {
    for (final String raw in <String>[
      '',
      '1.2',
      '1.2.3.4',
      '01.2.3',
      '1.2.3+4',
      '1.2.3-',
      '1.2.3-beta..1',
      'latest',
    ]) {
      expect(AppVersion.tryParse(raw), isNull, reason: raw);
    }
  });

  test('orders versions by semantic versioning precedence', () {
    final List<String> ordered = <String>[
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0',
      '1.0.1',
      '1.1.0-beta.1',
      '1.1.0',
      '1.10.0',
      '2.0.0',
    ];

    for (int i = 0; i + 1 < ordered.length; i++) {
      expect(
        _v(ordered[i]).compareTo(_v(ordered[i + 1])),
        lessThan(0),
        reason: '${ordered[i]} < ${ordered[i + 1]}',
      );
    }
  });

  test('treats the v prefix as the same version', () {
    expect(_v('v1.2.3'), _v('1.2.3'));
    expect(_v('v1.2.3') > _v('1.2.3'), isFalse);
  });
}
