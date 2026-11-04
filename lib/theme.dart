// Link's colors, the same as desktop Link (src/renderer/style.css).
import 'package:flutter/material.dart';

const accents = [
  Color(0xFF8A6CEF), Color(0xFF7C5CFF), Color(0xFF4F8FF7), Color(0xFF24A8A8),
  Color(0xFF44CF6E), Color(0xFFE9973F), Color(0xFFFB464C), Color(0xFFE05BA8),
];

class LinkColors extends ThemeExtension<LinkColors> {
  const LinkColors({
    required this.primary,
    required this.primaryAlt,
    required this.secondary,
    required this.border,
    required this.field,
    required this.text,
    required this.muted,
    required this.faint,
    required this.icon,
    required this.accent,
  });

  final Color primary, primaryAlt, secondary, border, field, text, muted, faint, icon, accent;

  static LinkColors dark(Color accent) => LinkColors(
        primary: const Color(0xFF1E1E1E),
        primaryAlt: const Color(0xFF242424),
        secondary: const Color(0xFF262626),
        border: const Color(0xFF363636),
        field: const Color(0xFF2B2B2B),
        text: const Color(0xFFDADADA),
        muted: const Color(0xFFB3B3B3),
        faint: const Color(0xFF6F6F6F),
        icon: const Color(0xFFA3A3A3),
        accent: accent,
      );

  static LinkColors light(Color accent) => LinkColors(
        primary: const Color(0xFFFFFFFF),
        primaryAlt: const Color(0xFFFAFAFA),
        secondary: const Color(0xFFF6F6F6),
        border: const Color(0xFFE3E3E3),
        field: const Color(0xFFF2F2F2),
        text: const Color(0xFF222222),
        muted: const Color(0xFF5C5C5C),
        faint: const Color(0xFFABABAB),
        icon: const Color(0xFF5C5C5C),
        accent: accent,
      );

  // Private tabs always use a deep purple-black, so it's obvious at a glance.
  static const privateBackground = Color(0xFF1A1426);

  @override
  LinkColors copyWith() => this;

  @override
  LinkColors lerp(LinkColors? other, double t) => t < 0.5 || other == null ? this : other;
}

ThemeData buildTheme(Brightness brightness, Color accent) {
  final c = brightness == Brightness.dark ? LinkColors.dark(accent) : LinkColors.light(accent);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(
    primary: accent,
    onPrimary: Colors.white,
    surface: c.primary,
    onSurface: c.text,
    surfaceContainerHighest: c.secondary,
    outline: c.border,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.primary,
    extensions: [c],
    dividerColor: c.border,
    iconTheme: IconThemeData(color: c.icon),
    appBarTheme: AppBarTheme(backgroundColor: c.primary, foregroundColor: c.text, elevation: 0, scrolledUnderElevation: 0),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.primaryAlt, showDragHandle: true),
    listTileTheme: ListTileThemeData(iconColor: c.icon, textColor: c.text),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : c.faint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : c.field),
    ),
    snackBarTheme: SnackBarThemeData(backgroundColor: c.secondary, contentTextStyle: TextStyle(color: c.text), behavior: SnackBarBehavior.floating),
  );
}

extension LinkTheme on BuildContext {
  LinkColors get colors => Theme.of(this).extension<LinkColors>()!;
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
