import 'package:flutter/material.dart';

/// Accent follows the SekolahOS design prototype (teal).
const Color kAccent = Color(0xFF0F766E);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kAccent);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(centerTitle: false),
    // A fixed toast lifts the docked "+" above itself; a floating one sits above
    // the button and leaves it where it is (see "a toast shows above the +").
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
