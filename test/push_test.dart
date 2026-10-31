import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/screens/app_shell.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/services/biometric_service.dart';
import 'package:mobile_sekolah_os/services/push_messaging.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/state/push_registrar.dart';
import 'package:mobile_sekolah_os/state/session_controller.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

import 'support/fake_updater.dart';

class _Push implements PushMessaging {
  bool allowed = true;
  String? fcmToken = 'tok-1111111111111111111';
  PushMessage? launch;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> requestPermission() async => allowed;

  @override
  Future<String?> token() async => fcmToken;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForeground => foreground.stream;

  @override
  Stream<PushMessage> get onOpened => opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => launch;
}

/// Records every request as "METHOD path" (plus body for the device calls).
class _Server {
  final log = <String>[];
  final bodies = <String, Map<String, dynamic>>{};
  bool failDevices = false;

  http.Response _ok(Object data, [Object meta = const {}]) => http.Response(
      jsonEncode({'data': data, 'meta': meta, 'errors': null}), 200,
      headers: {'content-type': 'application/json'});

  ApiClient get client => ApiClient(
        client: MockClient((req) async {
          final path = req.url.path.replaceFirst('/api', '');
          log.add('${req.method} $path');
          if (req.body.isNotEmpty && req.headers['content-type']?.contains('json') == true) {
            bodies['${req.method} $path'] = jsonDecode(req.body) as Map<String, dynamic>;
          }
          if (path.endsWith('/devices') && failDevices) {
            return http.Response(
                jsonEncode({'data': null, 'meta': {}, 'errors': {'message': 'x'}}), 500,
                headers: {'content-type': 'application/json'});
          }
          if (path.endsWith('/login')) {
            return _ok({
              'token': 't',
              'teacher': {'id': 1, 'name': 'Guru Uji', 'email': 'g@x.id'},
            });
          }
          if (path.endsWith('/notifications')) {
            return _ok([], {'last_page': 1, 'unread_count': 0});
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
              'unread_notifications': 0,
              'duties': {'attendance': null},
            });
          }
          if (RegExp(r'/leave-requests/7$').hasMatch(path)) {
            return _ok({
              'id': 7,
              'type': 'sick',
              'type_label': 'Sakit',
              'start_date': '2026-11-02',
              'end_date': '2026-11-03',
              'reason': 'Demam',
              'status': 'approved',
              'status_label': 'Disetujui',
              'has_attachment': false,
              'can_cancel': false,
              'lessons': [],
              'approvals': [],
            });
          }
          return _ok(<String, dynamic>{});
        }),
      );
}

void main() {
  group('PushRegistrar', () {
    late _Server server;
    late _Push push;
    late PushRegistrar registrar;

    setUp(() {
      server = _Server();
      push = _Push();
      registrar =
          PushRegistrar(service: TeacherService(server.client), messaging: push);
    });

    test('registers this phone once permission is given', () async {
      await registrar.register();
      expect(server.log, ['POST /v1/teacher/devices']);
      expect(server.bodies['POST /v1/teacher/devices'],
          {'token': 'tok-1111111111111111111', 'platform': 'android'});
    });

    test('no permission, no token, no request', () async {
      push.allowed = false;
      await registrar.register();
      push.allowed = true;
      push.fcmToken = null;
      await registrar.register();
      expect(server.log, isEmpty);
    });

    test('a rotated token is registered again', () async {
      await registrar.register();
      push.refresh.add('tok-2222222222222222222');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(server.log.where((l) => l.startsWith('POST')).length, 2);
      expect(server.bodies['POST /v1/teacher/devices']!['token'],
          'tok-2222222222222222222');
    });

    test('unregister removes the token it registered', () async {
      await registrar.register();
      await registrar.unregister();
      expect(server.log.last, 'DELETE /v1/teacher/devices');
      expect(server.bodies['DELETE /v1/teacher/devices']!['token'],
          'tok-1111111111111111111');
    });

    test('a server error is swallowed both ways', () async {
      server.failDevices = true;
      await registrar.register();
      await registrar.unregister();
      expect(server.log, isNotEmpty); // it tried, and nothing threw
    });
  });

  group('SessionController', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('signing in registers the phone; signing out unregisters it before logging out',
        () async {
      final server = _Server();
      final push = _Push();
      final session = SessionController(
        AuthService(client: server.client),
        biometric: BiometricLogin(gate: _NoBiometrics()),
        push: PushRegistrar(
            service: TeacherService(server.client), messaging: push),
      );

      await session.login('g@x.id', 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(server.log, contains('POST /v1/teacher/devices'));

      await session.logout();
      final delete = server.log.indexOf('DELETE /v1/teacher/devices');
      final logout = server.log.indexOf('POST /v1/teacher/logout');
      expect(delete, isNonNegative);
      expect(logout, greaterThan(delete),
          reason: 'the token must be removed while the session is still valid');
      expect(session.status, SessionStatus.signedOut);
    });

    test('a failing unregister never blocks signing out', () async {
      final server = _Server();
      final session = SessionController(
        AuthService(client: server.client),
        biometric: BiometricLogin(gate: _NoBiometrics()),
        push: PushRegistrar(
            service: TeacherService(server.client), messaging: _Push()),
      );
      await session.login('g@x.id', 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      server.failDevices = true;

      await session.logout();

      expect(session.status, SessionStatus.signedOut);
    });
  });

  group('AppShell', () {
    Future<(_Server, _Push)> pump(WidgetTester tester, {_Push? push}) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final server = _Server();
      final p = push ?? _Push();
      final session = SessionController(AuthService(client: server.client),
          biometric: BiometricLogin(gate: _NoBiometrics()))
        ..teacher = const AuthenticatedTeacher(id: 1, name: 'Guru Uji');
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: AppShell(
          session: session,
          service: TeacherService(server.client),
          updater: FakeUpdater(),
          push: p,
        ),
      ));
      await tester.pumpAndSettle();
      return (server, p);
    }

    int checks(_Server s) =>
        s.log.where((l) => l == 'GET /v1/teacher/notifications').length;

    testWidgets('a push that arrives while the app is open triggers a look at once',
        (tester) async {
      final (server, push) = await pump(tester);
      final before = checks(server);

      push.foreground.add(const PushMessage(type: 'leave_request', leaveRequestId: 7));
      await tester.pumpAndSettle();

      expect(checks(server), before + 1, reason: 'no waiting for the 45-second tick');
    });

    testWidgets('tapping a push opens the request and reads its notification',
        (tester) async {
      final (server, push) = await pump(tester);

      push.opened.add(const PushMessage(
          type: 'leave_request', leaveRequestId: 7, notificationId: 'abc-123'));
      await tester.pumpAndSettle();

      expect(find.text('Detail pengajuan'), findsOneWidget);
      expect(server.log, contains('POST /v1/teacher/notifications/abc-123/read'));
    });

    testWidgets('a push that launched the app opens the request too',
        (tester) async {
      final push = _Push()
        ..launch = const PushMessage(type: 'leave_request', leaveRequestId: 7);
      await pump(tester, push: push);

      expect(find.text('Detail pengajuan'), findsOneWidget);
    });

    testWidgets('a push of an unknown kind opens the notifications list',
        (tester) async {
      final (_, push) = await pump(tester);

      push.opened.add(const PushMessage(type: 'something_new'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada notifikasi baru'), findsOneWidget);
    });
  });
}

class _NoBiometrics implements BiometricGate {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
