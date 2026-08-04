import 'package:flutter/material.dart';

/// Brand palette sampled from the Panchshil Pulse artwork.
///
/// [primary] is the launcher-icon blue, [accent] the orange in the wordmark,
/// and [ink] the near-black used for the logotype.
abstract final class AppColors {
  static const primary = Color(0xFF2674DA);
  static const primaryDark = Color(0xFF1B57AB);
  static const primaryLight = Color(0xFF5B98E8);
  static const accent = Color(0xFFF58220);
  static const accentSoft = Color(0xFFFFE7D2);
  static const ink = Color(0xFF231F20);

  // Light surfaces
  static const lightBackground = Color(0xFFF6F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1F1F2);
  static const lightBorder = Color(0xFFE3E6EC);
  static const lightTextPrimary = Color(0xFF231F20);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextTertiary = Color(0xFF9AA1AC);

  // Dark surfaces
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkSurfaceAlt = Color(0xFF2F2E2E);
  static const darkBorder = Color(0xFF3A3A3C);
  static const darkTextPrimary = Color(0xFFF1F1F2);
  static const darkTextSecondary = Color(0xFFA1A1A6);
  static const darkTextTertiary = Color(0xFF6E6E73);

  // Status
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2674DA);

  /// Category tints used across event chips and the Discover grid.
  static const categoryTints = <Color>[
    Color(0xFF2674DA),
    Color(0xFFF58220),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
  ];

  static Color tintFor(Object? seed) =>
      categoryTints[(seed?.hashCode ?? 0).abs() % categoryTints.length];
}
