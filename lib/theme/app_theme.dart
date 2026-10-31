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
    // Five destinations on a 360dp phone leave ~72dp per slot: the default 12sp
    // label wrapped "Kotak masuk" onto two lines and pushed its icon out of line.
    navigationBarTheme: NavigationBarThemeData(
      labelPadding: EdgeInsets.zero,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          )),
    ),
  );
}
