import 'package:flutter/material.dart';

/// Accent follows the SekolahOS design prototype (teal).
const Color kAccent = Color(0xFF0F766E);

/// Buttons are squarish (12 dp corners, not the Material 3 pill) and 52 dp tall,
/// so they are easy to hit and read as buttons rather than chips.
final _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
);
const _buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
const _buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kAccent);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 52),
        padding: _buttonPadding,
        shape: _buttonShape,
        textStyle: _buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 52),
        padding: _buttonPadding,
        shape: _buttonShape,
        textStyle: _buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape: _buttonShape,
        textStyle: _buttonText,
      ),
    ),
    // A fixed toast lifts the docked "+" above itself; a floating one sits above
    // the button and leaves it where it is (see "a toast shows above the +").
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
