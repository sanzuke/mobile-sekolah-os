import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/app_shell.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/state/notification_watcher.dart';
import 'package:mobile_sekolah_os/state/session_controller.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

import 'support/fake_updater.dart';

Map<String, dynamic> _note(
  String id, {
  bool read = false,
  String title = 'Izin/cuti disetujui',
  Map<String, dynamic>? target = const {'type': 'leave_request', 'id': 7},
}) =>
    {
      'id': id,
      'type': 'LeaveRequestDecided',
      'title': title,
      'body': 'Sakit 2 Nov – 3 Nov 2026 disetujui.',
      'is_read': read,
      'created_at': '2026-11-01T03:00:00+00:00',
      'target': target,
    };

Map<String, dynamic> _leaveDetail() => {
      'id': 7,
      'type': 'sick',
      'type_label': 'Sakit',
      'start_date': '2026-11-02',
      'end_date': '2026-11-03',
      'reason': 'Demam',
      'status': 'approved',
      'status_label': 'Disetujui',
      'submitted_at': '2026-11-01T01:00:00+00:00',
      'decided_at': null,
      'decision_note': null,
      'has_attachment': false,
      'attachment_name': null,
      'can_cancel': false,
      'lessons': [],
      'approvals': [],
    };

/// A backend whose notifications can change between looks.
class _Backend {
  List<Map<String, dynamic>> notes = [];
  int notificationCalls = 0;
  int? failWith;

  http.Response _ok(Object data, [Object meta = const {}]) => http.Response(
      jsonEncode({'data': data, 'meta': meta, 'errors': null}), 200,
      headers: {'content-type': 'application/json'});

  ApiClient get client => ApiClient(
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/notifications')) {
            notificationCalls++;
            if (failWith != null) {
              return http.Response(
                  jsonEncode({
                    'data': null,
                    'meta': {},
                    'errors': {'message': 'Sesi berakhir.'}
                  }),
                  failWith!,
                  headers: {'content-type': 'application/json'});
            }
            return _ok(notes, {
              'last_page': 1,
              'unread_count': notes.where((n) => n['is_read'] == false).length,
            });
          }
          if (path.endsWith('/home')) {
            return _ok({
              'date': '2026-11-01',
              'day_name': 'Minggu',
              'semester': {'id': 1, 'name': 'S1', 'year': '2026/2027'},
              'week': null,
              'today': {'state': 'none', 'draft_count': 0, 'lessons': []},
              'next_lesson': null,
              'agenda': [],
              'announcements': [],
              'unread_notifications':
                  notes.where((n) => n['is_read'] == false).length,
              'duties': {'attendance': null},
            });
          }
          if (RegExp(r'/leave-requests/7$').hasMatch(path)) {
            return _ok(_leaveDetail());
          }
          return _ok(<String, dynamic>{});
        }),
      );
}

void main() {
  group('NotificationWatcher', () {
    late _Backend backend;
    late List<List<NotificationItem>> announced;
    late ValueNotifier<int> unread;
    var unauthorized = 0;

    NotificationWatcher watcher() => NotificationWatcher(
          service: TeacherService(backend.client),
          unread: unread,
          onNew: announced.add,
          onUnauthorized: () => unauthorized++,
        );

    setUp(() {
      backend = _Backend();
      announced = [];
      unread = ValueNotifier(0);
      unauthorized = 0;
    });

    test('the first look only records what is there; later arrivals are announced',
        () async {
      backend.notes = [_note('a')];
      final w = watcher();

      await w.check();
      expect(announced, isEmpty, reason: 'old notifications are not news');
      expect(unread.value, 1);

      backend.notes = [_note('b', title: 'Izin/cuti ditolak'), _note('a')];
      await w.check();

      expect(announced, hasLength(1));
      expect(announced.single.map((n) => n.id), ['b']);
      expect(unread.value, 2);

      await w.check();
      expect(announced, hasLength(1), reason: 'the same one is announced once');
    });

    test('something already read elsewhere is not announced', () async {
      final w = watcher();
      await w.check();
      backend.notes = [_note('c', read: true)];
      await w.check();
      expect(announced, isEmpty);
    });

    test('two looks at once make one request', () async {
      final w = watcher();
      await Future.wait([w.check(), w.check(), w.check()]);
      expect(backend.notificationCalls, 1);
    });

    test('an expired session is reported, not announced', () async {
      backend.failWith = 401;
      await watcher().check();
      expect(unauthorized, 1);
      expect(announced, isEmpty);
    });

    test('being offline is silent and retried later', () async {
      backend.failWith = 500;
      final w = watcher();
      await w.check();
      expect(unauthorized, 0);

      backend.failWith = null;
      backend.notes = [_note('a')];
      await w.check(); // seeds now
      backend.notes = [_note('b'), _note('a')];
      await w.check();
      expect(announced.single.single.id, 'b');
    });
  });

  group('in the app', () {
    Future<_Backend> pump(WidgetTester tester,
        {List<Map<String, dynamic>>? notes}) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final backend = _Backend()
        ..notes = notes ??
            [_note('old', read: true, title: 'Pengumuman lama', target: null)];
      final session = SessionController(AuthService(client: backend.client))
        ..teacher = const AuthenticatedTeacher(id: 1, name: 'Guru Uji');
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: AppShell(
          session: session,
          service: TeacherService(backend.client),
          updater: FakeUpdater(),
        ),
      ));
      await tester.pumpAndSettle();
      return backend;
    }

    testWidgets('a decision that arrives while the app is open is announced and opens',
        (tester) async {
      final backend = await pump(tester);
      expect(find.text('Izin/cuti disetujui'), findsNothing);

      backend.notes = [_note('new')];
      await tester.pump(const Duration(seconds: 46)); // the next look
      await tester.pumpAndSettle();

      expect(find.text('Izin/cuti disetujui'), findsOneWidget);
      expect(find.text('Sakit 2 Nov – 3 Nov 2026 disetujui.'), findsOneWidget);

      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();
      expect(find.text('Detail pengajuan'), findsOneWidget);
      expect(find.text('Disetujui'), findsWidgets);
    });

    testWidgets('a backgrounded app does not poll; coming back looks at once',
        (tester) async {
      final backend = await pump(tester);
      final before = backend.notificationCalls;

      // The framework only allows the real sequence of states.
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(const Duration(seconds: 150));
      expect(backend.notificationCalls, before, reason: 'no polling in background');

      backend.notes = [_note('new')];
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();

      expect(backend.notificationCalls, greaterThan(before));
      expect(find.text('Izin/cuti disetujui'), findsOneWidget);
    });

    testWidgets('an already loaded Notifikasi list reloads when news arrives',
        (tester) async {
      final backend = await pump(tester);
      await tester.tap(find.text('Kotak masuk').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifikasi').first);
      await tester.pumpAndSettle();
      expect(find.text('Izin/cuti disetujui'), findsNothing);

      backend.notes = [_note('new'), _note('old', read: true, title: 'Pengumuman lama', target: null)];
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      // once in the toast and once as a card in the reloaded list
      expect(find.text('Izin/cuti disetujui'), findsNWidgets(2));
    });

    testWidgets('tapping a decision card opens that request; an info card does not',
        (tester) async {
      await pump(tester, notes: [
        _note('a'),
        _note('b', title: 'Pengumuman baru', target: null),
      ]);
      await tester.tap(find.text('Kotak masuk').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifikasi').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget,
          reason: 'only the decision card links somewhere');

      await tester.tap(find.text('Pengumuman baru'));
      await tester.pumpAndSettle();
      expect(find.text('Detail pengajuan'), findsNothing);

      await tester.tap(find.text('Izin/cuti disetujui'));
      await tester.pumpAndSettle();
      expect(find.text('Detail pengajuan'), findsOneWidget);
    });
  });
}
