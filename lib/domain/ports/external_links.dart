/// Opens web pages outside the app.
abstract interface class ExternalLinks {
  /// Opens [url] in the browser. Returns false if no app could open it.
  Future<bool> open(Uri url);
}
