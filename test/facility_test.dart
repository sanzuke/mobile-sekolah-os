import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/facility_models.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/facility_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/facility_form_screen.dart';
import 'package:mobile_sekolah_os/screens/facility_reports_screen.dart';
import 'package:mobile_sekolah_os/screens/notification_target.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/push_messaging.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _report({
  int id = 5,
  String status = 'reported',
  bool canEdit = true,
  bool detail = false,
  String priority = 'sedang',
  String? note,
}) => {
  'id': id,
  'category': 'listrik',
  'category_label': 'Listrik',
  'priority': priority,
  'priority_label': {
    'rendah': 'Rendah',
    'sedang': 'Sedang',
    'mendesak': 'Mendesak',
  }[priority],
  'location': 'Kelas 8A',
  'status': status,
  'status_label': {
    'reported': 'Dilaporkan',
    'handling': 'Sedang ditangani',
    'resolved': 'Selesai',
    'rejected': 'Ditolak',
    'cancelled': 'Dibatalkan',
  }[status],
  'can_edit': canEdit,
  'created_at': '2026-11-01 08:30',
  'public_note': note,
  if (detail) 'description': 'Lampu belakang kelas mati sejak kemarin.',
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
  List<Map<String, dynamic>> list = [
    _report(),
    _report(
      id: 6,
      status: 'rejected',
      canEdit: false,
      note: 'Sudah dilaporkan.',
    ),
  ];
  Map<String, dynamic>? detail;
  http.Response Function(http.Request)? save;

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
        if (path.endsWith('/cancel')) {
          return _json(
            _report(status: 'cancelled', canEdit: false, detail: true),
            200,
          );
        }
        if (req.method == 'POST' || req.method == 'PUT') {
          return save?.call(req) ?? _json(_report(detail: true), 200);
        }
        if (RegExp(r'/facility-reports/\d+$').hasMatch(path)) {
          return _json(detail ?? _report(detail: true), 200);
        }
        final status = req.url.queryParameters['status'];
        return _json(
          status == null
              ? list
              : list.where((i) => i['status'] == status).toList(),
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
  FacilityReport? existing,
  void Function(FacilityReport?)? onPop,
}) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          final r = await Navigator.of(context).push<FacilityReport>(
            MaterialPageRoute(
              builder: (_) => FacilityFormScreen(
                service: api.service,
                onUnauthorized: () {},
                existing: existing,
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

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  group('list', () {
    testWidgets('shows category, priority, location and status', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        FacilityReportsScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Listrik · Sedang'), findsNWidgets(2));
      expect(find.text('Kelas 8A'), findsNWidgets(2));
      expect(find.text('Dilaporkan'), findsWidgets);
      expect(find.text('Ditolak'), findsWidgets);
    });

    testWidgets('filters by status through the server', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        FacilityReportsScreen(service: api.service, onUnauthorized: () {}),
      );

      // The filter row scrolls sideways: bring the chip into view first.
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Ditolak'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Ditolak'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ditolak'));
      await tester.pumpAndSettle();

      expect(api.requests.last.url.queryParameters['status'], 'rejected');
      expect(find.text('Listrik · Sedang'), findsOneWidget);
    });

    testWidgets('says so when there are no reports', (tester) async {
      final api = _Api()..list = [];
      await _pump(
        tester,
        FacilityReportsScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Belum ada laporan'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('an open report can be edited or withdrawn', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        FacilityDetailScreen(
          service: api.service,
          onUnauthorized: () {},
          id: 5,
        ),
      );

      expect(
        find.text('Lampu belakang kelas mati sejak kemarin.'),
        findsOneWidget,
      );
      expect(find.text('Ubah'), findsOneWidget);

      await tester.tap(find.text('Batalkan laporan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Batalkan laporan'));
      await tester.pumpAndSettle();

      expect(api.last('POST', '/facility-reports/5/cancel'), isNotNull);
      expect(find.text('Laporan ini dibatalkan oleh pelapor.'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
    });

    testWidgets('a rejected report shows the reason and no buttons', (
      tester,
    ) async {
      final api = _Api()
        ..detail = _report(
          status: 'rejected',
          canEdit: false,
          detail: true,
          note: 'Sudah dilaporkan.',
        );
      await _pump(
        tester,
        FacilityDetailScreen(
          service: api.service,
          onUnauthorized: () {},
          id: 5,
        ),
      );

      expect(find.text('Alasan penolakan'), findsOneWidget);
      expect(find.text('Sudah dilaporkan.'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
      expect(find.text('Batalkan laporan'), findsNothing);
    });

    testWidgets('a taken report shows the handler note', (tester) async {
      final api = _Api()
        ..detail = _report(
          status: 'resolved',
          canEdit: false,
          detail: true,
          note: 'Lampu diganti.',
        );
      await _pump(
        tester,
        FacilityDetailScreen(
          service: api.service,
          onUnauthorized: () {},
          id: 5,
        ),
      );

      expect(find.text('Tindakan dari petugas'), findsOneWidget);
      expect(find.text('Lampu diganti.'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('validates before sending anything', (tester) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kirim laporan'));
      await tester.pumpAndSettle();

      expect(find.text('Tuliskan lokasi, mis. Kelas 8A.'), findsOneWidget);
      expect(
        find.text('Jelaskan masalahnya minimal 10 karakter.'),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
    });

    testWidgets('sends the chosen fields and returns the saved report', (
      tester,
    ) async {
      final api = _Api();
      FacilityReport? popped;
      await _pump(tester, _formHost(api, onPop: (r) => popped = r));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Listrik'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mendesak'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Lokasi'), 'Kelas 8A');
      await tester.enterText(
        _field('Apa masalahnya'),
        'Lampu belakang kelas mati sejak kemarin.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim laporan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('kepala sekolah'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/facility-reports'), {
        'category': 'listrik',
        'priority': 'mendesak',
        'location': 'Kelas 8A',
        'description': 'Lampu belakang kelas mati sejak kemarin.',
      });
      expect(popped?.id, 5);
    });

    testWidgets('shows a server refusal and keeps the form', (tester) async {
      final api = _Api()
        ..save = (_) => _json(
          null,
          429,
          errors: {'message': 'Batas 10 laporan per hari sudah tercapai.'},
        );
      await _pump(tester, _formHost(api));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(_field('Lokasi'), 'Kelas 8A');
      await tester.enterText(
        _field('Apa masalahnya'),
        'Lampu belakang kelas mati sejak kemarin.',
      );
      await tester.tap(find.text('Kirim laporan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(find.text('Lapor sarpras'), findsOneWidget);
      expect(find.textContaining('Batas 10 laporan'), findsOneWidget);
    });
  });

  group('notification and push', () {
    test('a facility_report notification and push open the report', () {
      NotificationItem n(String type) => NotificationItem(
        id: 'x',
        title: 't',
        isRead: false,
        target: NotificationTarget(type: type, id: 5),
      );

      expect(hasNotificationTarget(n('facility_report')), isTrue);
      expect(hasNotificationTarget(n('something_else')), isFalse);

      final m = PushMessage.fromData({
        'type': 'facility_report',
        'facility_report_id': '5',
      });
      expect(m.facilityReportId, 5);
      expect(m.studentIncidentId, isNull);
    });
  });
}
