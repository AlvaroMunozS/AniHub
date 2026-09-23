import 'package:anihub/domain/ports/external_links.dart';

/// Records the opened links and answers [opens] for each of them.
class FakeExternalLinks implements ExternalLinks {
  FakeExternalLinks({this.opens = true});

  final bool opens;
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return opens;
  }
}
