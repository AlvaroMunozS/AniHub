/// Whether [a] and [b] contain equal elements in the same order.
///
/// The domain layer takes no package dependencies, so `ListEquality` from
/// `package:collection` is not available here.
bool sameElements<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
