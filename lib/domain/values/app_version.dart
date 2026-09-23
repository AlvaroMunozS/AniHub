/// A semantic version of the app, `major.minor.patch` with an optional
/// pre-release suffix such as `-beta.1`.
///
/// Build metadata is not part of it: Android tracks the build number
/// separately.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = const <String>[],
  ]);

  static final RegExp _pattern = RegExp(
    r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );

  final int major;
  final int minor;
  final int patch;

  /// The dot-separated identifiers after `-`, empty for a stable version.
  final List<String> preRelease;

  bool get isPrerelease => preRelease.isNotEmpty;

  /// Parses `X.Y.Z` or `X.Y.Z-pre`, with an optional leading `v` as in git
  /// tags. Returns null for anything else.
  static AppVersion? tryParse(String raw) {
    final RegExpMatch? match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4]?.split('.') ?? const <String>[],
    );
  }

  /// Orders versions by semantic versioning precedence: a pre-release comes
  /// before its stable version, and numeric identifiers compare as numbers.
  @override
  int compareTo(AppVersion other) {
    for (final (int a, int b) in <(int, int)>[
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    if (isPrerelease != other.isPrerelease) return isPrerelease ? -1 : 1;
    for (int i = 0; i < preRelease.length && i < other.preRelease.length; i++) {
      final int order = _compareIdentifiers(preRelease[i], other.preRelease[i]);
      if (order != 0) return order;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  static int _compareIdentifiers(String a, String b) {
    final int? numberA = int.tryParse(a);
    final int? numberB = int.tryParse(b);
    if (numberA != null && numberB != null) return numberA.compareTo(numberB);
    // Numeric identifiers rank below alphanumeric ones.
    if (numberA != null) return -1;
    if (numberB != null) return 1;
    return a.compareTo(b);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() =>
      '$major.$minor.$patch${isPrerelease ? '-${preRelease.join('.')}' : ''}';
}
