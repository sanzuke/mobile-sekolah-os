import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/widgets/menu_tile.dart';

void main() {
  // Found on a device with a larger system font: two-line labels overflowed the
  // fixed-height rows by 6px on "Semua menu".
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('two-line labels fit their row at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4800); // 360 x 1600 dp
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: MenuGrid(children: [
              for (final l in [
                'Kurikulum & RPP',
                'Data & Dokumen',
                'Rapat & Notulen',
                'Presensi',
              ])
                MenuTile(label: l, icon: Icons.book, onTap: () {}),
            ]),
          ),
        ),
      ));

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
    });
  }
}
