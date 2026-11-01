import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/journal_models.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/journal_form_screen.dart';
import 'package:mobile_sekolah_os/screens/journal_lessons_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _cls(
  int scheduleId,
  int gradeId,
  String name, {
  String? topic,
}) => {
  'schedule_id': scheduleId,
  'grade_id': gradeId,
  'name': name,
  'attendance': {'state': 'pending'},
  'journal': topic == null
      ? {'state': 'pending', 'topic': null}
      : {'state': 'submitted', 'topic': topic},
};

Map<String, dynamic> _lesson(
  int jp,
  String subject,
  List<Map<String, dynamic>> classes,
) => {
  'session_number': jp,
  'start': '0$jp:00',
  'end': '0$jp:35',
  'subject': subject,
  'subject_id': 1,
  'classes': classes,
};

List<LessonItem> _items(List<Map<String, dynamic>> lessons) => [
  for (final l in lessons) LessonItem.fromJson(l),
];

JournalTarget _target({
  List<int> ids = const [11, 12],
  List<int> written = const [],
  String classes = '8D',
}) => JournalTarget(
  subject: 'Fiqih',
  classNames: classes,
  jpLabel: 'JP 1–2',
  start: '07:50',
  end: '09:00',
  scheduleIds: ids,
  writtenScheduleIds: written,
);

http.Response _json(Object? body, int status, {Object? errors}) =>
    http.Response(
      jsonEncode({'data': body, 'meta': {}, 'errors': errors}),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _journal({
  bool submitted = false,
  bool editable = true,
  String? topic,
  String? material,
  String? notes,
  String? lockedMessage,
}) => {
  'journal': {
    'state': submitted ? 'submitted' : 'pending',
    'topic': topic,
    'material': material,
    'notes': notes,
    'editable': editable,
    'locked_message': lockedMessage,
  },
};

class _Api {
  final requests = <http.Request>[];
  Map<String, dynamic> stored = _journal();
  http.Response Function(http.Request)? onPut;
  List<Map<String, dynamic>> lessons = [];

  List<http.Request> of(String method) =>
      requests.where((r) => r.method == method).toList();

  TeacherService get service => TeacherService(
    ApiClient(
      client: MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path.endsWith('/lessons')) return _json(lessons, 200);
        if (path.contains('/journal')) {
          if (req.method == 'GET') return _json(stored, 200);
          if (req.method == 'PUT') {
            return onPut?.call(req) ?? _json({'message': 'ok'}, 200);
          }
          if (req.method == 'DELETE') return _json({'message': 'ok'}, 200);
        }
        return _json(<String, dynamic>{}, 200);
      }),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(720, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
  await tester.pumpAndSettle();
}

Widget _form(_Api api, JournalTarget target) => JournalFormScreen(
  service: api.service,
  onUnauthorized: () {},
  target: target,
  date: '2026-10-31',
);

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  group('models', () {
    test('a class carries its journal state and topic into the blocks', () {
      final blocks = buildLessonBlocks(
        _items([
          _lesson(1, 'Fiqih', [_cls(11, 4, '8D', topic: 'Thaharah')]),
          _lesson(2, 'Fiqih', [_cls(12, 4, '8D')]),
        ]),
      );

      final sessions = blocks.single.sessions;
      expect(sessions[0].journalSubmitted, isTrue);
      expect(sessions[0].journalTopic, 'Thaharah');
      expect(sessions[1].journalSubmitted, isFalse);
    });

    test('an older server that sends no journal reads as not written', () {
      final c = LessonClass.fromJson({
        'schedule_id': 1,
        'grade_id': 2,
        'name': '8D',
        'attendance': {'state': 'pending'},
      });
      expect(c.journalSubmitted, isFalse);
      expect(c.journalTopic, isNull);
    });

    test(
      'one target per lesson: a kelas gabungan and its JP range are one entry',
      () {
        final blocks = buildLessonBlocks(
          _items([
            _lesson(1, 'Fiqih', [_cls(11, 4, '9A'), _cls(21, 5, '9B')]),
            _lesson(2, 'Fiqih', [_cls(12, 4, '9A'), _cls(22, 5, '9B')]),
            _lesson(3, 'Akidah', [_cls(13, 4, '9A')]),
          ]),
        );

        final targets = journalTargets(blocks);

        expect(targets.length, 2);
        expect(targets[0].classNames, '9A + 9B');
        expect(targets[0].jpLabel, 'JP 1–2');
        expect(targets[0].scheduleIds.toSet(), {11, 12, 21, 22});
        expect(targets[1].subject, 'Akidah');
      },
    );

    test('the state is pending, partial or submitted by how many rows have a journal', () {
      JournalTarget make(List<String?> topics) => journalTargets(
        buildLessonBlocks(
          _items([
            for (var i = 0; i < topics.length; i++)
              _lesson(i + 1, 'Fiqih', [
                _cls(10 + i, 4, '8D', topic: topics[i]),
              ]),
          ]),
        ),
      ).single;

      expect(make([null, null]).state, 'pending');
      expect(make(['Bab 1', null]).state, 'partial');
      expect(make(['Bab 1', 'Bab 1']).state, 'submitted');
      expect(make(['Bab 1', null]).topic, 'Bab 1');
      expect(make(['Bab 1', null]).prefillScheduleId, 10);
      expect(make([null, null]).prefillScheduleId, isNull);
    });

    test(
      'a schedule card finds its journal target, and null when nothing matches',
      () {
        final group = groupLessons([
          Lesson.fromJson({
            'session_number': 1,
            'start': '01:00',
            'end': '01:35',
            'subject': 'Fiqih',
            'classes': '8D',
            'status': 'done',
          }),
          Lesson.fromJson({
            'session_number': 2,
            'start': '01:35',
            'end': '02:10',
            'subject': 'Fiqih',
            'classes': '8D',
            'status': 'done',
          }),
        ]).single;
        final blocks = buildLessonBlocks(
          _items([
            _lesson(1, 'Fiqih', [_cls(11, 4, '8D', topic: 'A')]),
            _lesson(2, 'Fiqih', [_cls(12, 4, '8D', topic: 'A')]),
          ]),
        );

        expect(journalForGroup(group, blocks)!.state, 'submitted');
        expect(journalForGroup(group, []), isNull);
      },
    );

    test(
      'HomeData reads duties.journal and knows whether the server reports it',
      () {
        Map<String, dynamic> home(Map<String, dynamic> duties) => {
          'date': '2026-10-31',
          'day_name': 'Sabtu',
          'today': {'state': 'ok', 'draft_count': 0, 'lessons': []},
          'duties': duties,
        };

        final reported = HomeData.fromJson(
          home({
            'attendance': null,
            'journal': {'done': 1, 'total': 2, 'percent': 50},
          }),
        );
        expect(reported.journalDutyReported, isTrue);
        expect(reported.journalDuty!.percent, 50);

        final nullJournal = HomeData.fromJson(
          home({'attendance': null, 'journal': null}),
        );
        expect(nullJournal.journalDutyReported, isTrue);
        expect(nullJournal.journalDuty, isNull);

        final older = HomeData.fromJson(home({'attendance': null}));
        expect(older.journalDutyReported, isFalse);
      },
    );
  });

  group('form', () {
    testWidgets('a new journal starts empty and reads the server once', (
      tester,
    ) async {
      final api = _Api();
      await _pump(tester, _form(api, _target()));

      expect(api.of('GET').single.url.path, endsWith('/schedules/11/journal'));
      expect(api.of('GET').single.url.queryParameters['date'], '2026-10-31');
      expect(find.text('Fiqih'), findsOneWidget);
      expect(find.textContaining('8D · JP 1–2'), findsOneWidget);
      expect(
        find.textContaining('Isi yang sama disimpan untuk semua kelas dan JP'),
        findsOneWidget,
      );
      expect(find.text('Hapus'), findsNothing); // nothing written yet
    });

    testWidgets('an existing journal is prefilled from the row that has one', (
      tester,
    ) async {
      final api = _Api()
        ..stored = _journal(
          submitted: true,
          topic: 'Bab Thaharah',
          material: 'Macam air',
          notes: 'Diulang',
        );
      await _pump(tester, _form(api, _target(written: [12])));

      expect(api.of('GET').single.url.path, endsWith('/schedules/12/journal'));
      expect(find.text('Bab Thaharah'), findsOneWidget);
      expect(find.text('Macam air'), findsOneWidget);
      expect(find.text('Diulang'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets('saving writes the same text to every class and JP', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        _form(api, _target(ids: [11, 12, 21, 22], classes: '9A + 9B')),
      );
      await tester.enterText(_field('Topik'), '  Bab Thaharah ');
      await tester.enterText(
        _field('Materi / kegiatan (opsional)'),
        'Macam air',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan jurnal'));
      await tester.pumpAndSettle();

      final puts = api.of('PUT');
      expect(puts.map((r) => r.url.path.split('/').reversed.skip(1).first), [
        '11',
        '12',
        '21',
        '22',
      ]);
      for (final r in puts) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['date'], '2026-10-31');
        expect(body['topic'], 'Bab Thaharah');
        expect(body['material'], 'Macam air');
        expect(body['notes'], '');
      }
    });

    testWidgets(
      'a topic that is too short is refused before anything is sent',
      (tester) async {
        final api = _Api();
        await _pump(tester, _form(api, _target()));
        await tester.enterText(_field('Topik'), 'ab');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan jurnal'));
        await tester.pumpAndSettle();

        expect(
          find.text('Tuliskan topik pembelajaran, minimal 3 karakter.'),
          findsOneWidget,
        );
        expect(api.of('PUT'), isEmpty);
      },
    );

    testWidgets('a server refusal is shown and the form stays', (tester) async {
      final api = _Api()
        ..onPut = (_) => _json(
          null,
          422,
          errors: {
            'message':
                'Batas koreksi jurnal 7 hari sudah lewat. Hubungi admin.',
          },
        );
      await _pump(tester, _form(api, _target()));
      await tester.enterText(_field('Topik'), 'Bab Thaharah');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan jurnal'));
      await tester.pumpAndSettle();

      expect(find.text('Jurnal mengajar'), findsOneWidget);
      expect(find.textContaining('Batas koreksi jurnal'), findsOneWidget);
      expect(api.of('PUT').length, 1); // stops at the first refusal
    });

    testWidgets('outside the correction window it is read-only and says why', (
      tester,
    ) async {
      final api = _Api()
        ..stored = _journal(
          submitted: true,
          editable: false,
          topic: 'Bab Thaharah',
          lockedMessage:
              'Batas koreksi jurnal 7 hari sudah lewat. Hubungi admin.',
        );
      await _pump(tester, _form(api, _target(written: [11])));

      expect(
        find.text('Batas koreksi jurnal 7 hari sudah lewat. Hubungi admin.'),
        findsOneWidget,
      );
      expect(find.text('Simpan jurnal'), findsNothing);
      expect(find.text('Hapus'), findsNothing);
      expect(tester.widget<TextField>(_field('Topik')).enabled, isFalse);
    });

    testWidgets(
      'deleting asks first, then removes it from every row that has one',
      (tester) async {
        final api = _Api()
          ..stored = _journal(submitted: true, topic: 'Bab Thaharah');
        await _pump(
          tester,
          _form(api, _target(ids: [11, 12], written: [11, 12])),
        );

        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();
        expect(api.of('DELETE'), isEmpty);
        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(api.of('DELETE').length, 2);
        expect(jsonDecode(api.of('DELETE').first.body), {'date': '2026-10-31'});
      },
    );
  });

  group('day list', () {
    List<Map<String, dynamic>> twoLessons() => [
      _lesson(1, 'Fiqih', [
        _cls(11, 4, '9A', topic: 'Bab 1'),
        _cls(21, 5, '9B', topic: 'Bab 1'),
      ]),
      _lesson(2, 'Fiqih', [
        _cls(12, 4, '9A', topic: 'Bab 1'),
        _cls(22, 5, '9B', topic: 'Bab 1'),
      ]),
      _lesson(5, 'Tafsir', [_cls(15, 4, '9A')]),
    ];

    testWidgets('lists each lesson once, with its journal state and topic', (
      tester,
    ) async {
      final api = _Api()..lessons = twoLessons();
      await _pump(
        tester,
        JournalLessonsScreen(
          service: api.service,
          onUnauthorized: () {},
          date: '2026-10-31',
          today: DateTime(2026, 10, 31),
        ),
      );

      expect(find.text('Fiqih'), findsOneWidget);
      expect(find.textContaining('9A + 9B'), findsOneWidget);
      expect(find.text('Jurnal terisi'), findsOneWidget);
      expect(find.text('Bab 1'), findsOneWidget);
      expect(find.text('Tafsir'), findsOneWidget);
      expect(find.text('Belum jurnal'), findsOneWidget);
    });

    testWidgets('tapping a lesson opens its form', (tester) async {
      final api = _Api()..lessons = twoLessons();
      await _pump(
        tester,
        JournalLessonsScreen(
          service: api.service,
          onUnauthorized: () {},
          date: '2026-10-31',
          today: DateTime(2026, 10, 31),
        ),
      );

      await tester.tap(find.text('Tafsir'));
      await tester.pumpAndSettle();

      expect(find.text('Simpan jurnal'), findsOneWidget);
      expect(
        api.of('GET').any((r) => r.url.path.endsWith('/schedules/15/journal')),
        isTrue,
      );
    });

    testWidgets(
      'says so on a day without lessons, and navigation stops at the 7-day window',
      (tester) async {
        final api = _Api();
        await _pump(
          tester,
          JournalLessonsScreen(
            service: api.service,
            onUnauthorized: () {},
            date: '2026-10-24',
            today: DateTime(2026, 10, 31),
          ),
        );

        expect(
          find.text('Tidak ada jadwal mengajar pada tanggal ini.'),
          findsOneWidget,
        );
        // 24 Oct is exactly 7 days back: the oldest allowed, so "previous" is disabled.
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_left),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_right),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  });
}
