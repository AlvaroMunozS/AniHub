import 'package:flutter/widgets.dart';

/// Accent colors the user can pick. Each has one tone for dark surfaces and a
/// darker one for light surfaces, so that both keep the same contrast.
enum AppAccent {
  indigo(dark: Color(0xFF7D8AF5), light: Color(0xFF4F5BD5)),
  teal(dark: Color(0xFF4FC1B5), light: Color(0xFF0F7C72)),
  green(dark: Color(0xFF6CC08B), light: Color(0xFF2E8049)),
  amber(dark: Color(0xFFE8B34A), light: Color(0xFF9A6700)),
  orange(dark: Color(0xFFF08A4B), light: Color(0xFFC0531A)),
  pink(dark: Color(0xFFEE7BAE), light: Color(0xFFC23C7A));

  const AppAccent({required this.dark, required this.light});

  final Color dark;
  final Color light;
}
