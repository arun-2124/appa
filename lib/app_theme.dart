import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Color tokens (LIGHT) ───────────────────────────────────────────────
// Single source of truth — main.dart, history_screen.dart, and
// settings_screen.dart each used to declare their own private copies of
// these, which is exactly why dark mode never reached them. Import this
// file everywhere instead of redeclaring constants locally.
const Color kPrimary       = Color(0xFF6B3FA0);
const Color kPrimaryLight  = Color(0xFFF0E6FF);
const Color kAccentAmber   = Color(0xFFEF9F27);
const Color kSuccess       = Color(0xFF2E7D32);
const Color kSuccessLight  = Color(0xFFE8F5E9);
const Color kWarning       = Color(0xFFF57C00);
const Color kWarningLight  = Color(0xFFFFF3E0);
const Color kDanger        = Color(0xFFC62828);
const Color kDangerLight   = Color(0xFFFFEBEE);
const Color kBackground    = Color(0xFFFAF7FF);
const Color kSurface       = Color(0xFFFFFFFF);
const Color kTextPrimary   = Color(0xFF1A1A2E);
const Color kTextSecondary = Color(0xFF6B6B80);
const Color kCardBorder    = Color(0xFFE8E0F0);
const Color kTakenBorder   = Color(0xFFA5D6A7);

// ─── Color tokens (DARK) ────────────────────────────────────────────────
const Color kPrimaryDark       = Color(0xFFB28EDB);
const Color kPrimaryLightDark  = Color(0xFF2A2240);
const Color kSuccessDark       = Color(0xFF66BB6A);
const Color kSuccessLightDark  = Color(0xFF1C3320);
const Color kWarningDark       = Color(0xFFFFB74D);
const Color kWarningLightDark  = Color(0xFF3A2A12);
const Color kDangerDark        = Color(0xFFEF5350);
const Color kDangerLightDark   = Color(0xFF3A1A1A);
const Color kBackgroundDark    = Color(0xFF14101F);
const Color kSurfaceDark       = Color(0xFF1E1830);
const Color kTextPrimaryDark   = Color(0xFFF2EFFA);
const Color kTextSecondaryDark = Color(0xFFB0A8C2);
const Color kCardBorderDark    = Color(0xFF332A4A);
const Color kTakenBorderDark   = Color(0xFF3D6B40);

// ─── Theme-aware color lookup ──────────────────────────────────────────
// Use AppColors.primary(context) etc. instead of the bare kXxx constants
// in any widget whose appearance should change with brightness.
class AppColors {
  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color primary(BuildContext c) => _isDark(c) ? kPrimaryDark : kPrimary;
  static Color primaryLight(BuildContext c) =>
      _isDark(c) ? kPrimaryLightDark : kPrimaryLight;
  static Color background(BuildContext c) =>
      _isDark(c) ? kBackgroundDark : kBackground;
  static Color surface(BuildContext c) => _isDark(c) ? kSurfaceDark : kSurface;
  static Color textPrimary(BuildContext c) =>
      _isDark(c) ? kTextPrimaryDark : kTextPrimary;
  static Color textSecondary(BuildContext c) =>
      _isDark(c) ? kTextSecondaryDark : kTextSecondary;
  static Color cardBorder(BuildContext c) =>
      _isDark(c) ? kCardBorderDark : kCardBorder;
  static Color takenBorder(BuildContext c) =>
      _isDark(c) ? kTakenBorderDark : kTakenBorder;
  static Color success(BuildContext c) => _isDark(c) ? kSuccessDark : kSuccess;
  static Color successLight(BuildContext c) =>
      _isDark(c) ? kSuccessLightDark : kSuccessLight;
  static Color warning(BuildContext c) => _isDark(c) ? kWarningDark : kWarning;
  static Color warningLight(BuildContext c) =>
      _isDark(c) ? kWarningLightDark : kWarningLight;
  static Color danger(BuildContext c) => _isDark(c) ? kDangerDark : kDanger;
  static Color dangerLight(BuildContext c) =>
      _isDark(c) ? kDangerLightDark : kDangerLight;
}

// ─── Theme mode controller ──────────────────────────────────────────────
// SettingsScreen's Dark Mode switch sets ThemeController.themeMode.value
// directly, AppaApp listens to it and rebuilds. ThemeController.init()
// restores the saved preference on launch so it persists between sessions.
class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('darkMode');
    if (saved == true) {
      themeMode.value = ThemeMode.dark;
    } else if (saved == false) {
      themeMode.value = ThemeMode.light;
    }
    // If never set, leave as ThemeMode.system.
  }

  static void cycle() {
    switch (themeMode.value) {
      case ThemeMode.light:
        themeMode.value = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        themeMode.value = ThemeMode.system;
        break;
      case ThemeMode.system:
        themeMode.value = ThemeMode.light;
        break;
    }
  }

  static IconData icon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}

// ─── Cross-screen refresh signal ────────────────────────────────────────
// Bumped whenever a medicine is added, marked taken, or deleted. Screens
// that read derived data (History, Analytics) can wrap their body in a
// ValueListenableBuilder<int> on this so they refresh immediately instead
// of waiting for a tab switch.
class MedicineEvents {
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);
  static void notifyChanged() => refreshTick.value++;
}

// ─── Shared ThemeData builder ────────────────────────────────────────────
ThemeData buildAppTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;

  final Color primary       = dark ? kPrimaryDark : kPrimary;
  final Color primaryBg     = dark ? kPrimaryLightDark : kPrimaryLight;
  final Color background    = dark ? kBackgroundDark : kBackground;
  final Color surface       = dark ? kSurfaceDark : kSurface;
  final Color textSecondary = dark ? kTextSecondaryDark : kTextSecondary;
  final Color cardBorder    = dark ? kCardBorderDark : kCardBorder;
  final Color danger        = dark ? kDangerDark : kDanger;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor : kPrimary,
      primary   : primary,
      secondary : kAccentAmber,
      surface   : surface,
      error     : danger,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? kSurfaceDark : kPrimary,
      foregroundColor: dark ? kTextPrimaryDark : Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: dark ? kTextPrimaryDark : Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: primaryBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: textSecondary, fontSize: 15),
      floatingLabelStyle: TextStyle(color: primary, fontSize: 13),
    ),
  );
}