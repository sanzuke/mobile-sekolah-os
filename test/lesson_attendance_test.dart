import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/lesson_attendance_screen.dart';
import 'package:mobile_sekolah_os/screens/lessons_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';

Map<String, dynamic> _cls(int scheduleId, int gradeId, String name,
        {bool submitted = false, int present = 0, int total = 0}) =>
    {
      'schedule_id': scheduleId,
      'grade_id': gradeId,
      'name': name,
      'attendance': submitted
          ? {'state': 'submitted', 'present': present, 'late': 0, 'total': total}
          : {'state': 'pending'},
    };

Map<String, dynamic> _lesson(int jp, String subject, List<Map<String, dynamic>> classes) => {
      'session_number': jp,
      'start': '0$jp:00',
      'end': '0$jp:35',
      'subject': subject,
      'classes': classes,
    };

http.Response _json(Object data) => http.Response(
    jsonEncode({'data': data, 'meta': {}, 'errors': null}), 200,
    headers: {'content-type': 'application/json'});

void main() {
  group('buildLessonBlocks', () {
    test('merges back-to-back JP of the same class and subject', () {
      final blocks = buildLessonBlocks([
        LessonItem.fromJson(_lesson(1, 'Fiqih', [_cls(10, 1, '8A')])),
        LessonItem.fromJson(_lesson(2, 'Fiqih', [_cls(11, 1, '8A')])),
        LessonItem.fromJson(_lesson(3, 'Fiqih', [_cls(12, 2, '8B')])),
        LessonItem.fromJson(_lesson(4, 'Fiqih', [_cls(13, 2, '8B')])),
      ]);

      expect(
        blocks.map((b) => '${b.className} ${b.jpLabel} ${b.scheduleIds.join(',')}'),
        ['8A JP 1–2 10,11', '8B JP 3–4 12,13'],
      );
      expect(blocks.first.start, '01:00');
      expect(blocks.first.end, '02:35');
    });

    test('a gap or a different subject starts a new block', () {
      final blocks = buildLessonBlocks([
        LessonItem.fromJson(_lesson(1, 'Fiqih', [_cls(10, 1, '8A')])),
        LessonItem.fromJson(_lesson(3, 'Fiqih', [_cls(11, 1, '8A')])), // JP 2 missing
        LessonItem.fromJson(_lesson(4, 'Akidah', [_cls(12, 1, '8A')])), // other subject
      ]);

      expect(blocks.map((b) => b.jpLabel), ['JP 1', 'JP 3', 'JP 4']);
    });

    test('a kelas gabungan becomes one block per class; state and summary', () {
      final blocks = buildLessonBlocks([
        LessonItem.fromJson(_lesson(1, 'Kajian', [
          _cls(10, 1, '9A', submitted: true, present: 27, total: 30),
          _cls(20, 2, '9B'),
        ])),
        LessonItem.fromJson(_lesson(2, 'Kajian', [
          _cls(11, 1, '9A', submitted: true, present: 27, total: 30),
          _cls(21, 2, '9B', submitted: true, present: 20, total: 25),
        ])),
      ]);

      final a = blocks.firstWhere((b) => b.className == '9A');
      final b = blocks.firstWhere((b) => b.className == '9B');
      expect(a.state, 'submitted');
      expect(a.summary, '27/30 hadir');
      expect(b.state, 'partial'); // JP 1 not recorded, JP 2 recorded
    });
  });

  testWidgets('LessonsScreen lists merged blocks with their state', (tester) async {
    final client = ApiClient(
      client: MockClient((req) async => _json([
            _lesson(1, 'Fiqih', [_cls(10, 1, '8A')]),
            _lesson(2, 'Fiqih', [_cls(11, 1, '8A')]),
          ])),
    );
    await tester.pumpWidget(MaterialApp(
      home: LessonsScreen(
        service: TeacherService(client),
        onUnauthorized: () {},
        date: '2026-10-31',
        today: DateTime(2026, 10, 31),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('JP 1–2 · Fiqih'), findsOneWidget);
    expect(find.text('Belum presensi'), findsOneWidget);
    // Today is the newest allowed day: no "next day".
    expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed,
        isNull);
  });

  testWidgets('saves the same statuses to every JP of the block', (tester) async {
    final puts = <String, Map<String, dynamic>>{};
    final client = ApiClient(
      client: MockClient((req) async {
        if (req.method == 'PUT') {
          puts[req.url.path] = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'saved': 2});
        }
        return _json({
          'lesson': {},
          'session': {'state': 'pending', 'editable': true},
          'warnings': <String>[],
          'students': [
            {'student_id': 1, 'nis': '001', 'name': 'Ali', 'status': null, 'note': null},
            {'student_id': 2, 'nis': '002', 'name': 'Budi', 'status': null, 'note': null},
          ],
        });
      }),
    );
    final block = buildLessonBlocks([
      LessonItem.fromJson(_lesson(1, 'Fiqih', [_cls(10, 1, '8A')])),
      LessonItem.fromJson(_lesson(2, 'Fiqih', [_cls(11, 1, '8A')])),
    ]).single;

    await tester.pumpWidget(MaterialApp(
      home: LessonAttendanceScreen(
        service: TeacherService(client),
        onUnauthorized: () {},
        block: block,
        date: '2026-10-31',
      ),
    ));
    await tester.pumpAndSettle();

    // Everyone starts "Hadir"; saving a pending block is allowed without edits.
    expect(find.text('Hadir 2'), findsOneWidget);
    expect(find.text('Simpan presensi JP 1–2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chip-2-sick')));
    await tester.pump();
    expect(find.text('Sakit 1'), findsOneWidget);

    await tester.tap(find.text('Simpan presensi JP 1–2'));
    await tester.pumpAndSettle();

    expect(puts.keys.toSet(), {
      '/api/v1/teacher/schedules/10/attendance',
      '/api/v1/teacher/schedules/11/attendance',
    });
    for (final body in puts.values) {
      expect(body['date'], '2026-10-31');
      expect(body['records'], [
        {'student_id': 1, 'status': 'present'},
        {'student_id': 2, 'status': 'sick'},
      ]);
    }
  });

  testWidgets('a locked lesson is read-only and cannot be saved', (tester) async {
    final client = ApiClient(
      client: MockClient((req) async => _json({
            'lesson': {},
            'session': {
              'state': 'submitted',
              'editable': false,
              'locked_message': 'Batas koreksi presensi 7 hari sudah lewat. Hubungi admin.',
            },
            'warnings': <String>[],
            'students': [
              {'student_id': 1, 'nis': '001', 'name': 'Ali', 'status': 'sick', 'note': null},
            ],
          })),
    );
    final block = buildLessonBlocks([
      LessonItem.fromJson(_lesson(1, 'Fiqih', [_cls(10, 1, '8A', submitted: true, present: 0, total: 1)])),
    ]).single;

    await tester.pumpWidget(MaterialApp(
      home: LessonAttendanceScreen(
        service: TeacherService(client),
        onUnauthorized: () {},
        block: block,
        date: '2026-10-01',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Batas koreksi presensi'), findsOneWidget);
    expect(find.text('Sakit 1'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
