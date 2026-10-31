import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/grade_entry_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';

http.Response _json(Object data, {Map<String, dynamic> meta = const {}}) =>
    http.Response(jsonEncode({'data': data, 'meta': meta, 'errors': null}), 200,
        headers: {'content-type': 'application/json'});

void main() {
  test('ClassesData picks the running period, else the latest started one', () {
    final data = ClassesData.fromJson({
      'semester': {'name': 'Semester 1', 'year': '2026/2027'},
      'classes': [],
      'exam_periods': [
        {'id': 1, 'name': 'NH 1', 'start_date': '2026-07-13', 'end_date': '2026-09-08'},
        {'id': 2, 'name': 'NH 2', 'start_date': '2026-09-09', 'end_date': '2026-11-05'},
        {'id': 3, 'name': 'PAS', 'start_date': '2026-12-12', 'end_date': '2026-12-17'},
      ],
    });
    expect(data.defaultPeriod(DateTime(2026, 10, 31))!.id, 2);
    expect(data.defaultPeriod(DateTime(2026, 11, 20))!.id, 2); // between periods
    expect(data.defaultPeriod(DateTime(2026, 1, 1))!.id, 1); // before all
  });

  testWidgets('only changed cells are sent; invalid score blocks saving',
      (tester) async {
    Map<String, dynamic>? sentBody;
    final client = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'PUT') {
          sentBody = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'saved': 1, 'skipped': 0});
        }
        return _json([
          {'student_id': 1, 'nis': '001', 'name': 'Ali', 'grade_value': 80, 'predicate': 'Baik'},
          {'student_id': 2, 'nis': '002', 'name': 'Budi', 'grade_value': null},
        ], meta: {'kkm': 70});
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: GradeEntryScreen(
        service: TeacherService(client),
        onUnauthorized: () {},
        classInfo: const ClassInfo(
            id: 9, name: '8A', isHomeroom: false, studentCount: 2, subjects: []),
        subject: const SubjectInfo(id: 4, name: 'Fiqih', path: 'Fiqih', kkm: 70),
        periods: const [ExamPeriodInfo(id: 5, name: 'NH 1')],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('80'), findsOneWidget); // existing value prefilled

    // Nothing typed yet: nothing to save.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    // Budi: 65 is valid but below KKM 70.
    await tester.enterText(find.byType(TextField).last, '65,5');
    await tester.pump();
    expect(find.textContaining('Di bawah KKM'), findsOneWidget);
    expect(find.text('Simpan (1 nilai)'), findsOneWidget);

    // Out of range blocks saving.
    await tester.enterText(find.byType(TextField).last, '101');
    await tester.pump();
    expect(find.text('0–100'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, '65,5');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(sentBody!['exam_period_id'], 5);
    expect(sentBody!['grades'], [
      {'student_id': 2, 'grade_value': 65.5}, // Ali (unchanged) is not sent
    ]);
  });

  testWidgets('Simpan rides above the keyboard instead of hiding behind it',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
    tester.view.devicePixelRatio = 3.0;
    // An on-screen keyboard 450dp tall (1350px) covers the lower half of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 1350);
    addTearDown(tester.view.reset);

    final client = ApiClient(
      client: MockClient((req) async => _json([
            {'student_id': 1, 'nis': '001', 'name': 'Ali', 'grade_value': null},
          ], meta: {'kkm': 70})),
    );
    await tester.pumpWidget(MaterialApp(
      home: GradeEntryScreen(
        service: TeacherService(client),
        onUnauthorized: () {},
        classInfo: const ClassInfo(
            id: 9, name: '8A', isHomeroom: false, studentCount: 1, subjects: []),
        subject: const SubjectInfo(id: 4, name: 'Fiqih', path: 'Fiqih', kkm: 70),
        periods: const [ExamPeriodInfo(id: 5, name: 'NH 1')],
      ),
    ));
    await tester.pumpAndSettle();

    final keyboardTopDp = (2400 - 1350) / 3.0;
    final saveBottom = tester.getBottomLeft(find.byType(FilledButton)).dy;
    expect(saveBottom, lessThanOrEqualTo(keyboardTopDp),
        reason: 'Simpan ($saveBottom dp) would sit under the keyboard (top at $keyboardTopDp dp)');
  });
}
