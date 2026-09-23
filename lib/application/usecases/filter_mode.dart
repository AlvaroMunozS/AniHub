/// State of a library filter that can keep or hide the entries with a
/// property.
enum FilterMode {
  /// The property is ignored.
  any,

  /// Only entries with the property pass.
  only,

  /// Only entries without the property pass.
  exclude;

  /// The mode after this one when the filter is tapped: any, only, exclude,
  /// then any again.
  FilterMode get next => switch (this) {
    FilterMode.any => FilterMode.only,
    FilterMode.only => FilterMode.exclude,
    FilterMode.exclude => FilterMode.any,
  };

  /// Whether an entry for which the property is [value] passes.
  bool matches(bool value) => switch (this) {
    FilterMode.any => true,
    FilterMode.only => value,
    FilterMode.exclude => !value,
  };
}
