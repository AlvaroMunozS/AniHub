import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../router.dart';
import '../shell/content_column.dart';
import '../theme/app_theme.dart';

const String _appIconAsset = 'assets/images/app_icon.png';
const double _headerIconSize = 96;

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ContentColumn(
        maxWidth: AppLayout.readableMaxWidth,
        child: ListView(
          children: <Widget>[
            const SizedBox(height: AppSpacing.s32),
            const Center(
              child: Image(
                image: AssetImage(_appIconAsset),
                width: _headerIconSize,
                height: _headerIconSize,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.l10n.settingsTitle),
              onTap: () => context.go(RoutePaths.settings),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.l10n.aboutTitle),
              onTap: () => context.go(RoutePaths.about),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }
}
