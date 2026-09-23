import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const double _railWidth = 2;

/// How far below its place a member starts sliding in.
const double _enterOffset = 8;

/// Marks a member of an expanded group with an accent rail on its left edge.
class GroupMemberSlot extends StatelessWidget {
  const GroupMemberSlot({required this.child, required this.indent, super.key});

  final Widget child;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: context.palette.accentSoft,
              width: _railWidth,
            ),
          ),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(AppRadius.pill),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s8),
          child: child,
        ),
      ),
    );
  }
}

/// Fades and slides a group member in when first built, and out when
/// [visible] turns false.
///
/// A [TweenAnimationBuilder] whose end follows [visible] covers both
/// directions without a controller: the first build animates from 0, and a
/// later change animates from the current value.
class GroupMemberTransition extends StatelessWidget {
  const GroupMemberTransition({
    required this.visible,
    required this.child,
    super.key,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: AppDuration.base,
      curve: AppDuration.curve,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * _enterOffset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
