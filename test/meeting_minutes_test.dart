import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/meeting_models.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/meeting_minute_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/meeting_minute_form_screen.dart';
import 'package:mobile_sekolah_os/screens/meeting_minutes_screen.dart';
import 'package:mobile_sekolah_os/screens/notification_target.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/push_messaging.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _minute({
  int id = 5,
  String status = 'final',
  bool isAuthor = true,
  bool detail = false,
  String title = 'Rapat evaluasi pekan pertama',
}) => {
  'id': id,
  'title': title,
  'category': 'staff',
  'category_label': 'Rapat staf/guru',
  'held_on': '2026-11-02',
  'start_time': '08:00',
  'end_time': '09:30',
  'status': status,
  'is_author': isAuthor,
  'finalized_at': status == 'final' ? '2026-11-02T03:00:00+00:00' : null,
  if (!detail) ...{
    'attendee_count': 2,
    'action_count': 2,
    'open_action_count': 1,
  },
  if (detail) ...{
    'author': {'id': 1, 'name': 'Guru Penulis'},
    'location': 'Ruang guru',
    'agenda': 'Evaluasi KBM',
    'discussion': 'Pembahasan panjang tentang jadwal dan presensi.',
    'decisions': 'Presensi diisi tiap pertemuan.',
    'attendees': [
      {'id': 1, 'teacher_id': 2, 'name': 'Bu Peserta', 'attended': true},
      {'id': 2, 'teacher_id': null, 'name': 'Tamu Dinas', 'attended': true},
    ],
    'actions': [
      {
        'id': 11,
        'description': 'Menyusun format jurnal',
        'assignee': {'id': 2, 'name': 'Bu Peserta'},
        'due_date': '2026-11-10',
        'done': false,
        'done_at': null,
        'can_toggle': status == 'final',
      },
      {
        'id': 12,
        'description': 'Menyiapkan ruang rapat',
        'assignee': null,
        'due_date': null,
        'done': true,
        'done_at': '2026-11-03T01:00:00+00:00',
        'can_toggle': false,
      },
    ],
  },
};

http.Response _json(
  Object? body,
  int status, {
  Object meta = const {},
  Object? errors,
}) => http.Response(
  jsonEncode({'data': body, 'meta': meta, 'errors': errors}),
  status,
  headers: {'content-type': 'application/json'},
);

class _Api {
  final requests = <http.Request>[];
  List<Map<String, dynamic>> mine = [
    _minute(status: 'draft'),
    _minute(id: 6, title: 'Rapat komite'),
  ];
  List<Map<String, dynamic>> attended = [];
  Map<String, dynamic>? detail;
  http.Response Function(http.Request)? save;
  http.Response Function(http.Request)? toggle;

  http.Request? last(String method, String suffix) =>
      requests.cast<http.Request?>().lastWhere(
        (r) => r!.method == method && r.url.path.endsWith(suffix),
        orElse: () => null,
      );

  Map<String, dynamic> sent(String method, String suffix) =>
      jsonDecode(last(method, suffix)!.body) as Map<String, dynamic>;

  TeacherService get service => TeacherService(
    ApiClient(
      client: MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path.endsWith('/attendee-options')) {
          return _json([
            {'id': 2, 'name': 'Bu Peserta'},
            {'id': 3, 'name': 'Pak Rekan'},
          ], 200);
        }
        if (path.endsWith('/finalize')) {
          return _json(_minute(detail: true), 200);
        }
        if (path.endsWith('/done')) {
          return toggle?.call(req) ??
              _json({
                'id': 11,
                'description': 'Menyusun format jurnal',
                'assignee': {'id': 2, 'name': 'Bu Peserta'},
                'due_date': '2026-11-10',
                'done': jsonDecode(req.body)['done'],
                'can_toggle': true,
              }, 200);
        }
        if (req.method == 'DELETE') return _json({'deleted': true}, 200);
        if (req.method == 'POST' || req.method == 'PUT') {
          return save?.call(req) ??
              _json(
                _minute(
                  detail: true,
                  status: jsonDecode(req.body)['finalize'] == true
                      ? 'final'
                      : 'draft',
                ),
                200,
              );
        }
        if (RegExp(r'/meeting-minutes/\d+$').hasMatch(path)) {
          return _json(detail ?? _minute(detail: true), 200);
        }
        final attendedTab = req.url.queryParameters['scope'] == 'attended';
        return _json(
          attendedTab ? attended : mine,
          200,
          meta: {'last_page': 1},
        );
      }),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
  await tester.pumpAndSettle();
}

Widget _formHost(
  _Api api, {
  MeetingMinute? existing,
  void Function(MeetingMinute?)? onPop,
}) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          final r = await Navigator.of(context).push<MeetingMinute>(
            MaterialPageRoute(
              builder: (_) => MeetingMinuteFormScreen(
                service: api.service,
                onUnauthorized: () {},
                existing: existing,
                now: DateTime(2026, 11, 2),
              ),
            ),
          );
          onPop?.call(r);
        },
        child: const Text('open'),
      ),
    ),
  ),
);

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  group('list', () {
    testWidgets('my minutes show status, schedule and open tasks', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        MeetingMinutesScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Notulen saya'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Final'), findsOneWidget);
      expect(find.text('Rapat komite'), findsOneWidget);
      expect(find.textContaining('2 Nov 2026 · 08:00–09:30'), findsWidgets);
      expect(find.text('1 dari 2 tugas terbuka'), findsWidgets);
      expect(api.requests.first.url.queryParameters['scope'], 'mine');
    });

    testWidgets(
      'the attended tab asks for the attended scope and can be empty',
      (tester) async {
        final api = _Api();
        await _pump(
          tester,
          MeetingMinutesScreen(service: api.service, onUnauthorized: () {}),
        );

        await tester.tap(find.text('Saya hadiri'));
        await tester.pumpAndSettle();

        expect(
          api.requests.any((r) => r.url.queryParameters['scope'] == 'attended'),
          isTrue,
        );
        expect(find.text('Belum ada notulen untuk Anda'), findsOneWidget);
      },
    );

    testWidgets('an empty list invites the first minutes', (tester) async {
      final api = _Api()..mine = [];
      await _pump(
        tester,
        MeetingMinutesScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Belum ada notulen'), findsOneWidget);
    });

    testWidgets('tapping a row opens it', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        MeetingMinutesScreen(service: api.service, onUnauthorized: () {}),
      );

      await tester.tap(find.text('Rapat komite'));
      await tester.pumpAndSettle();

      expect(find.text('Pembahasan'), findsOneWidget);
    });
  });

  group('detail', () {
    Future<_Api> open(
      WidgetTester tester, {
      Map<String, dynamic>? detail,
    }) async {
      final api = _Api()..detail = detail;
      await _pump(
        tester,
        MeetingMinuteDetailScreen(
          service: api.service,
          onUnauthorized: () {},
          id: 5,
        ),
      );
      return api;
    }

    testWidgets('a final minute shows its notes, people and tasks, read-only', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Rapat evaluasi pekan pertama'), findsOneWidget);
      expect(find.text('Ruang guru'), findsOneWidget);
      expect(
        find.text('Pembahasan panjang tentang jadwal dan presensi.'),
        findsOneWidget,
      );
      expect(find.text('Presensi diisi tiap pertemuan.'), findsOneWidget);
      expect(find.text('Bu Peserta'), findsWidgets);
      expect(find.text('Tamu Dinas'), findsOneWidget);
      expect(find.text('Menyusun format jurnal'), findsOneWidget);
      expect(find.textContaining('tenggat 10 Nov 2026'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
      expect(find.text('Finalkan'), findsNothing);
    });

    testWidgets(
      'only tasks the server allows are tickable, and ticking is sent',
      (tester) async {
        final api = await open(tester);

        final boxes = tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .toList();
        expect(boxes[0].onChanged, isNotNull);
        expect(boxes[1].onChanged, isNull);

        await tester.tap(find.text('Menyusun format jurnal'));
        await tester.pumpAndSettle();

        expect(api.sent('POST', '/actions/11/done'), {'done': true});
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
              .value,
          isTrue,
        );
      },
    );

    testWidgets("a refusal on ticking shows the server's reason", (
      tester,
    ) async {
      final api = await open(tester);
      api.toggle = (_) => _json(
        null,
        403,
        errors: {
          'message':
              'Hanya penulis atau penerima tugas yang dapat menandainya.',
          'details': {},
        },
      );

      await tester.tap(find.text('Menyusun format jurnal'));
      await tester.pumpAndSettle();

      expect(
        find.text('Hanya penulis atau penerima tugas yang dapat menandainya.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isFalse,
      );
    });

    testWidgets(
      'a draft of mine offers Ubah and Finalkan, and finalising asks first',
      (tester) async {
        final api = await open(
          tester,
          detail: _minute(status: 'draft', detail: true),
        );

        expect(find.text('Draft'), findsOneWidget);
        expect(
          find.textContaining('hanya Anda yang bisa melihatnya'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Finalkan'));
        await tester.pumpAndSettle();
        expect(find.text('Finalkan notulen?'), findsOneWidget);

        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(api.last('POST', '/finalize'), isNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Finalkan'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Finalkan'),
          ),
        );
        await tester.pumpAndSettle();

        expect(api.last('POST', '/finalize'), isNotNull);
        expect(find.text('Notulen difinalkan.'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Finalkan'),
          findsNothing,
        ); // now locked
      },
    );

    testWidgets('a draft can be deleted after confirming', (tester) async {
      final api = await open(
        tester,
        detail: _minute(status: 'draft', detail: true),
      );

      await tester.tap(find.byTooltip('Hapus draft'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hapus'),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.last('DELETE', '/meeting-minutes/5'), isNotNull);
    });

    testWidgets("someone else's minutes have no edit buttons", (tester) async {
      await open(tester, detail: _minute(isAuthor: false, detail: true));

      expect(find.text('Ubah'), findsNothing);
      expect(find.byTooltip('Hapus draft'), findsNothing);
    });
  });

  group('form', () {
    testWidgets(
      'a title is required and the discussion must be real before finalising',
      (tester) async {
        final api = _Api();
        await _pump(tester, _formHost(api));
        await _openForm(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Finalkan'));
        await tester.pumpAndSettle();
        expect(find.text('Judul wajib diisi.'), findsOneWidget);
        expect(
          find.textContaining('Isi pembahasan minimal 10 karakter'),
          findsOneWidget,
        );
        expect(api.requests, isEmpty);

        await tester.enterText(_field('Judul rapat'), 'Rapat PSB');
        await tester.enterText(_field('Pembahasan'), 'pendek');
        await tester.tap(find.widgetWithText(FilledButton, 'Finalkan'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Isi pembahasan minimal 10 karakter'),
          findsOneWidget,
        );
        expect(api.requests, isEmpty);
      },
    );

    testWidgets(
      'a draft needs only a title and is sent with attendees and tasks',
      (tester) async {
        final api = _Api();
        MeetingMinute? popped;
        await _pump(tester, _formHost(api, onPop: (m) => popped = m));
        await _openForm(tester);

        await tester.enterText(_field('Judul rapat'), 'Rapat PSB');
        await tester.enterText(_field('Pembahasan'), 'Bahasan awal.');

        await tester.ensureVisible(find.text('Tambah tamu'));
        await tester.tap(find.text('Tambah tamu'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Nama tamu'),
          'Tamu Dinas',
        );
        await tester.tap(find.text('Tambah'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Tambah guru'));
        await tester.tap(find.text('Tambah guru'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pak Rekan'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Tambah tindak lanjut'));
        await tester.tap(find.text('Tambah tindak lanjut'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Tugas'),
          'Siapkan formulir',
        );
        await tester.tap(find.text('Simpan tugas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Simpan draft'));
        await tester.pumpAndSettle();

        final body = api.sent('POST', '/meeting-minutes');
        expect(body['title'], 'Rapat PSB');
        expect(body['category'], 'staff');
        expect(body['held_on'], '2026-11-02');
        expect(body['finalize'], false);
        expect(body['attendees'], [
          {'name': 'Tamu Dinas', 'attended': true},
          {'teacher_id': 3, 'name': 'Pak Rekan', 'attended': true},
        ]);
        expect(body['actions'], [
          {'description': 'Siapkan formulir'},
        ]);
        expect(popped?.id, 5);
        expect(find.text('Draft tersimpan.'), findsOneWidget);
      },
    );

    testWidgets('Finalkan confirms first, then sends finalize: true', (
      tester,
    ) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);
      await tester.enterText(_field('Judul rapat'), 'Rapat PSB');
      await tester.enterText(
        _field('Pembahasan'),
        'Pembahasan yang cukup panjang.',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Finalkan'));
      await tester.pumpAndSettle();
      expect(find.text('Finalkan notulen?'), findsOneWidget);
      expect(api.requests, isEmpty);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Finalkan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/meeting-minutes')['finalize'], true);
    });

    testWidgets('editing a draft pre-fills it and saves with PUT', (
      tester,
    ) async {
      final api = _Api();
      final existing = MeetingMinute.fromJson(
        _minute(status: 'draft', detail: true),
      );
      await _pump(tester, _formHost(api, existing: existing));
      await _openForm(tester);

      expect(find.text('Ubah draft'), findsOneWidget);
      expect(find.text('Rapat evaluasi pekan pertama'), findsOneWidget);
      expect(find.text('Menyusun format jurnal'), findsOneWidget);

      await tester.enterText(_field('Judul rapat'), 'Judul baru');
      await tester.tap(find.text('Simpan draft'));
      await tester.pumpAndSettle();

      expect(api.last('PUT', '/meeting-minutes/5'), isNotNull);
      expect(api.sent('PUT', '/meeting-minutes/5')['title'], 'Judul baru');
    });

    testWidgets('leaving with unsaved text asks first', (tester) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);
      await tester.enterText(_field('Judul rapat'), 'Belum disimpan');
      await tester
          .pump(); // the first edit rebuilds the screen so back is intercepted

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Keluar tanpa menyimpan?'), findsOneWidget);

      await tester.tap(find.text('Lanjut menulis'));
      await tester.pumpAndSettle();
      expect(find.text('Tulis notulen'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Keluar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tulis notulen'), findsNothing);
    });

    testWidgets('an untouched form leaves without asking', (tester) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Keluar tanpa menyimpan?'), findsNothing);
      expect(find.text('Tulis notulen'), findsNothing);
    });

    testWidgets(
      'a server refusal is shown by the field and the form stays open',
      (tester) async {
        final api = _Api();
        api.save = (_) => _json(
          null,
          422,
          errors: {
            'message': 'Data tidak valid.',
            'details': {
              'held_on': ['Tanggal terlalu jauh.'],
            },
          },
        );
        await _pump(tester, _formHost(api));
        await _openForm(tester);
        await tester.enterText(_field('Judul rapat'), 'Rapat PSB');

        await tester.tap(find.text('Simpan draft'));
        await tester.pumpAndSettle();

        expect(find.text('Data tidak valid.'), findsOneWidget);
        expect(find.text('Tanggal terlalu jauh.'), findsOneWidget);
        expect(find.text('Tulis notulen'), findsOneWidget);
      },
    );
  });

  group('opening from a notification or a push', () {
    test('a meeting_minute notification has somewhere to go', () {
      NotificationItem n(String type) => NotificationItem(
        id: 'x',
        title: 't',
        isRead: false,
        target: NotificationTarget(type: type, id: 5),
      );

      expect(hasNotificationTarget(n('meeting_minute')), isTrue);
      expect(hasNotificationTarget(n('leave_request')), isTrue);
      expect(hasNotificationTarget(n('something_else')), isFalse);
    });

    test('a push carries the minutes id', () {
      final m = PushMessage.fromData({
        'type': 'meeting_minute',
        'meeting_minute_id': '9',
        'notification_id': 'abc',
      });

      expect(m.type, 'meeting_minute');
      expect(m.meetingMinuteId, 9);
      expect(m.leaveRequestId, isNull);
    });
  });
}
