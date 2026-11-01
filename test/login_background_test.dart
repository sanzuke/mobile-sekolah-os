import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';
import 'package:mobile_sekolah_os/widgets/animated_login_background.dart';

Widget _app({required bool animate, bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: MaterialApp(
    theme: buildTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: AnimatedLoginBackground(
        animate: animate,
        child: const Center(child: Text('isi')),
      ),
    ),
  ),
);

void main() {
  testWidgets('the backdrop moves and keeps its content on top', (
    tester,
  ) async {
    await tester.pumpWidget(_app(animate: true));
    await tester.pump(const Duration(seconds: 1));

    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    expect(find.text('isi'), findsOneWidget);
  });

  testWidgets('it stands still when told to', (tester) async {
    await tester.pumpWidget(_app(animate: false));
    await tester.pump(const Duration(seconds: 1));

    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(find.text('isi'), findsOneWidget);
  });

  testWidgets('it stands still when the device asks to remove animations', (
    tester,
  ) async {
    await tester.pumpWidget(_app(animate: true, reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));

    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  testWidgets('buttons are squarish and at least 52 dp tall', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Masuk')),
              OutlinedButton(onPressed: () {}, child: const Text('Lain')),
            ],
          ),
        ),
      ),
    );

    for (final finder in [
      find.byType(FilledButton),
      find.byType(OutlinedButton),
    ]) {
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(52));
      final shape = tester
          .widget<Material>(
            find.descendant(of: finder, matching: find.byType(Material)).first,
          )
          .shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
    }
  });
}
