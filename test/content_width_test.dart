import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/widgets/content_width.dart';

void main() {
  Future<double> widthAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ContentWidth(child: child!),
      home: const Scaffold(body: SizedBox.expand(key: Key('page'))),
    ));
    return tester.getSize(find.byKey(const Key('page'))).width;
  }

  testWidgets('tablet content is capped and centred', (tester) async {
    expect(await widthAt(tester, const Size(1200, 1920)), kMaxContentWidth);
    final left = tester.getTopLeft(find.byKey(const Key('page'))).dx;
    expect(left, (1200 - kMaxContentWidth) / 2);
  });

  testWidgets('phone content keeps the full width', (tester) async {
    expect(await widthAt(tester, const Size(400, 800)), 400);
  });
}
