import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/ports/external_links.dart';

/// Opens links in the browser or the app that handles them.
class UrlLauncherExternalLinks implements ExternalLinks {
  const UrlLauncherExternalLinks();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // Thrown instead of returning false when no app handles the link.
      return false;
    }
  }
}
