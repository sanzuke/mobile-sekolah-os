import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

void main() {
  // Real wrapping can't be asserted in a widget test: the test font (Ahem) is far
  // wider than Roboto, so every label wraps there. The wrap fix was verified on a
  // device screenshot (360dp phone, five destinations). This guards the settings
  // that fix relies on from being dropped by accident.
  test('bottom nav keeps the compact label style that fits five destinations', () {
    final nav = buildTheme().navigationBarTheme;

    expect(nav.labelPadding, EdgeInsets.zero);
    final selected = nav.labelTextStyle!.resolve({WidgetState.selected})!;
    final normal = nav.labelTextStyle!.resolve({})!;
    expect(selected.fontSize, 11);
    expect(normal.fontSize, 11);
    expect(selected.fontWeight, FontWeight.w700);
  });
}
