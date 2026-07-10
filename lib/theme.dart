import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The VaultBoard palette: deep grays and slates with a cool indigo accent.
class VaultColors {
  static const background = Color(0xFF0D0F13);
  static const surface = Color(0xFF14171D);
  static const surfaceRaised = Color(0xFF1B1F27);
  static const column = Color(0xFF161A21);
  static const card = Color(0xFF1F242E);
  static const border = Color(0xFF2A303C);
  static const accent = Color(0xFF7C9AFF);
  static const textPrimary = Color(0xFFE6EAF2);
  static const textSecondary = Color(0xFF9AA3B2);

  /// Accent colors offered when creating a board.
  static const boardPalette = <Color>[
    Color(0xFF7C9AFF), // indigo
    Color(0xFF4DD0B1), // teal
    Color(0xFFFFB74D), // amber
    Color(0xFFEF7A85), // rose
    Color(0xFFB78CFF), // violet
    Color(0xFF64C7E8), // sky
    Color(0xFF9CCC65), // lime
    Color(0xFFFF8A65), // coral
  ];
}

ThemeData buildVaultTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VaultColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: VaultColors.accent,
    surface: VaultColors.surface,
    surfaceContainerHighest: VaultColors.surfaceRaised,
    onSurface: VaultColors.textPrimary,
    outlineVariant: VaultColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: VaultColors.background,
    dividerColor: VaultColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VaultColors.surfaceRaised,
      hintStyle: const TextStyle(color: VaultColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VaultColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VaultColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VaultColors.accent, width: 1.4),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: VaultColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: VaultColors.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: VaultColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: VaultColors.border),
      ),
      textStyle: const TextStyle(color: VaultColors.textPrimary, fontSize: 12),
    ),
  );
}

/// Lets mouse users drag-scroll lists and shows scrollbars where expected.
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
