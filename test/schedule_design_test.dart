import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/schedule_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _lesson(int jp, String start, String end, String subject, String classes,
        {String status = 'upcoming', String? room}) =>
    {
      'session_number': jp,
      'start': start,
      'end': end,
      'subject': subject,
      'classes': classes,
      'room': room,
      'status': status,
    };

Lesson _l(int jp, String subject, String classes, {String status = 'upcoming'}) =>
    Lesson.fromJson(_lesson(jp, '0$jp:00', '0$jp:35', subject, classes, status: status));

Map<String, dynamic> _cls(int scheduleId, int gradeId, String name, {bool submitted = false}) => {
      'schedule_id': scheduleId,
      'grade_id': gradeId,
      'name': name,
      'attendance': submitted
          ? {'state': 'submitted', 'present': 26, 'late': 0, 'total': 28}
          : {'state': 'pending'},
    };

void main() {
  group('groupLessons', () {
    test('merges back-to-back JP of the same subject and classes', () {
      final g = groupLessons([
        _l(2, 'Fiqih', '8D'),
        _l(1, 'Fiqih', '8D'), // out of order on purpose
        _l(3, 'Akidah', '8D'),
      ]);

      expect(g.map((x) => x.jpLabel), ['JP 1–2', 'JP 3']);
      expect(g.first.start, '01:00');
      expect(g.first.end, '02:35');
    });

    test('a gap, another subject or other classes start a new group', () {
      final g = groupLessons([
        _l(1, 'Fiqih', '8D'),
        _l(3, 'Fiqih', '8D'), // JP 2 missing
        _l(4, 'Fiqih', '8C'), // different class
      ]);

      expect(g.map((x) => x.jpLabel), ['JP 1', 'JP 3', 'JP 4']);
    });

    test('status: current wins, all done is done, otherwise upcoming', () {
      expect(groupLessons([_l(1, 'F', 'A', status: 'done'), _l(2, 'F', 'A', status: 'current')])
          .single.status, 'current');
      expect(groupLessons([_l(1, 'F', 'A', status: 'done'), _l(2, 'F', 'A', status: 'done')])
          .single.status, 'done');
      expect(groupLessons([_l(1, 'F', 'A', status: 'done'), _l(2, 'F', 'A', status: 'next')])
          .single.status, 'next');
    });
  });

  group('attendanceForGroup', () {
    final group = groupLessons([_l(1, 'Fiqih', '8D'), _l(2, 'Fiqih', '8D')]).single;

    LessonBlock block(int jpFrom, int jpTo, {required bool submitted}) => buildLessonBlocks([
          for (var jp = jpFrom; jp <= jpTo; jp++)
            LessonItem.fromJson({
              'session_number': jp,
              'start': '0$jp:00',
              'end': '0$jp:35',
              'subject': 'Fiqih',
              'classes': [_cls(100 + jp, 1, '8D', submitted: submitted)],
            }),
        ]).single;

    test('null when nothing matches', () {
      expect(attendanceForGroup(group, []), isNull);
    });

    test('pending, submitted (with summary) and partial', () {
      expect(attendanceForGroup(group, [block(1, 2, submitted: false)])!.state, 'pending');
      final done = attendanceForGroup(group, [block(1, 2, submitted: true)])!;
      expect((done.state, done.summary), ('submitted', '26/28 hadir'));

      final partial = attendanceForGroup(
          group, [block(1, 1, submitted: true), block(2, 2, submitted: false)])!;
      expect(partial.state, 'partial');
    });
  });

  Future<void> pump(WidgetTester tester, {bool withBlocks = true}) async {
    tester.view.physicalSize = const Size(1440, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final client = ApiClient(
      client: MockClient((req) async {
        final path = req.url.path;
        Object data = <String, dynamic>{};
        if (path.endsWith('/schedule')) {
          data = {
            'semester': {'id': 1, 'name': 'Semester 1', 'year': '2026/2027'},
            'week': {
              'number': 16,
              'total': 25,
              'start': '2026-10-26',
              'end': '2026-11-01',
              'sessions_per_week': 34,
            },
            'days': [
              {
                'day': 1,
                'name': 'Senin',
                'date': '2026-10-26',
                'is_today': false,
                'state': 'ok',
                'lessons': [_lesson(1, '07:50', '08:25', 'Tafsir', '7B')],
              },
              {
                'day': 6,
                'name': 'Sabtu',
                'date': '2026-10-31',
                'is_today': true,
                'state': 'ok',
                'lessons': [
                  _lesson(1, '07:50', '08:25', 'Musthalah Hadits', '8D', status: 'done'),
                  _lesson(2, '08:25', '09:00', 'Musthalah Hadits', '8D', status: 'done'),
                  _lesson(5, '10:30', '11:05', 'Tafsir', '7B', room: 'R2'),
                ],
              },
              {
                'day': 7,
                'name': 'Minggu',
                'date': '2026-11-01',
                'is_today': false,
                'state': 'ok',
                'lessons': [_lesson(1, '19:30', '20:30', 'Kajian', '9A + 9B')],
              },
            ],
          };
        } else if (path.endsWith('/lessons')) {
          data = withBlocks && req.url.queryParameters['date'] == '2026-10-31'
              ? [
                  {
                    'session_number': 1,
                    'start': '07:50',
                    'end': '08:25',
                    'subject': 'Musthalah Hadits',
                    'classes': [_cls(11, 4, '8D', submitted: true)],
                  },
                  {
                    'session_number': 2,
                    'start': '08:25',
                    'end': '09:00',
                    'subject': 'Musthalah Hadits',
                    'classes': [_cls(12, 4, '8D', submitted: true)],
                  },
                  {
                    'session_number': 5,
                    'start': '10:30',
                    'end': '11:05',
                    'subject': 'Tafsir',
                    'classes': [_cls(15, 2, '7B')],
                  },
                ]
              : <Object>[];
        }
        return http.Response(jsonEncode({'data': data, 'meta': {}, 'errors': null}), 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SafeArea(
          child: ScheduleScreen(
            service: TeacherService(client),
            onUnauthorized: () {},
            now: DateTime(2026, 10, 31, 10, 0),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('title, week summary, seven day chips, today selected', (tester) async {
    await pump(tester);

    expect(find.text('Jadwal mengajar'), findsOneWidget);
    expect(find.text('Pekan 16/25 · 26 Okt – 1 Nov 2026 · 34 sesi'), findsOneWidget);
    for (final day in [26, 27, 28, 29, 30, 31, 1]) {
      expect(find.byKey(ValueKey('day-$day')), findsOneWidget, reason: 'chip $day');
    }
    expect(find.text('Sabtu, 31 Okt 2026'), findsOneWidget);
  });

  testWidgets('back-to-back JP become one card with attendance state and shortcuts',
      (tester) async {
    await pump(tester);

    expect(find.text('JP 1–2'), findsOneWidget); // merged
    expect(find.text('JP 5'), findsOneWidget);
    expect(find.text('Musthalah Hadits'), findsOneWidget);
    expect(find.text('8D · 07:50 – 09:00'), findsOneWidget);
    expect(find.text('7B · 10:30 – 11:05 · R2'), findsOneWidget);

    // From /lessons: the first card is recorded, the second is not.
    expect(find.text('26/28 hadir'), findsOneWidget);
    expect(find.text('Belum presensi'), findsOneWidget);

    expect(find.text('Presensi'), findsNWidgets(2));
    expect(find.text('Jurnal'), findsNWidgets(2));
    expect(find.text('RPP'), findsNWidgets(2));

    await tester.tap(find.text('Jurnal').first);
    await tester.pump();
    expect(find.text('Jurnal akan segera hadir'), findsOneWidget);
  });

  testWidgets('another day shows its own lessons; a day without school says so',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('day-26')));
    await tester.pumpAndSettle();
    expect(find.text('Senin, 26 Okt 2026'), findsOneWidget);
    expect(find.text('Tafsir'), findsOneWidget);
    expect(find.text('7B · 07:50 – 08:25'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-30'))); // Friday: not in the API
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada kegiatan belajar'), findsOneWidget);
    expect(find.text('Pilih hari lain untuk melihat sesi mengajar.'), findsOneWidget);
  });

  testWidgets('a future day cannot be recorded: Presensi is disabled', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('day-1'))); // Sunday 1 Nov, after "today"
    await tester.pumpAndSettle();

    expect(find.text('Kajian'), findsOneWidget);
    expect(find.text('9A + 9B · 19:30 – 20:30'), findsOneWidget);
    final presensi = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Presensi'), matching: find.byType(FilledButton)));
    expect(presensi.onPressed, isNull);
    expect(find.text('Belum presensi'), findsNothing); // no state for a future day
  });
}
