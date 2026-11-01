import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/facility_models.dart';
import 'package:mobile_sekolah_os/models/incident_models.dart';
import 'package:mobile_sekolah_os/models/leave_models.dart';
import 'package:mobile_sekolah_os/models/vehicle_models.dart';
import 'package:mobile_sekolah_os/screens/inbox_screen.dart';
import 'package:mobile_sekolah_os/screens/menu_entries.dart';
import 'package:mobile_sekolah_os/screens/my_reports.dart';
import 'package:mobile_sekolah_os/screens/shell_actions.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _leave({
  int id = 1,
  String submittedAt = '2026-11-01T01:30:00+00:00',
}) => {
  'id': id,
  'type': 'sakit',
  'type_label': 'Izin sakit',
  'start_date': '2026-11-03',
  'end_date': '2026-11-04',
  'reason': 'Demam',
  'status': 'pending',
  'status_label': 'Menunggu',
  'submitted_at': submittedAt,
};

Map<String, dynamic> _incident({
  int id = 3,
  String occurredAt = '2026-11-01 10:00',
}) => {
  'id': id,
  'category': 'discipline',
  'category_label': 'Pelanggaran',
  'severity': 'sedang',
  'severity_label': 'Sedang',
  'occurred_at': occurredAt,
  'status': 'handling',
  'status_label': 'Sedang ditangani',
  'can_edit': false,
  'students': [
    {'id': 1, 'name': 'Ahmad Fauzi', 'grade_name': '8A'},
  ],
  'public_note': null,
};

Map<String, dynamic> _facility({
  int id = 5,
  String createdAt = '2026-11-01 23:07',
}) => {
  'id': id,
  'category': 'bangunan',
  'category_label': 'Bangunan',
  'priority': 'sedang',
  'priority_label': 'Sedang',
  'location': 'Kelas AB',
  'status': 'reported',
  'status_label': 'Dilaporkan',
  'can_edit': true,
  'created_at': createdAt,
  'public_note': null,
  'description': 'Atap bocor.',
};

Map<String, dynamic> _vehicle({
  int id = 7,
  String startAt = '2026-11-10 07:00',
}) => {
  'id': id,
  'purpose': 'Study tour',
  'destination': 'Museum Geologi',
  'start_at': startAt,
  'end_at': '2026-11-10 15:00',
  'passenger_count': 25,
  'status': 'approved',
  'status_label': 'Disetujui',
  'can_edit': false,
  'can_cancel': true,
  'vehicle': {'name': 'Bus', 'plate_number': 'D 1 AB'},
  'driver_name': 'Pak Asep',
  'public_note': null,
};

class _Api {
  final requests = <String>[];
  List<Map<String, dynamic>> leaves = [_leave()];
  List<Map<String, dynamic>> incidents = [_incident()];
  List<Map<String, dynamic>> facilities = [_facility()];
  List<Map<String, dynamic>> vehicles = [_vehicle()];
  bool vehiclesFail = false;

  int count(String part) => requests.where((p) => p.contains(part)).length;

  http.Response _ok(
    Object? data, {
    Object meta = const {'last_page': 1, 'pending_count': 0},
  }) => http.Response(
    jsonEncode({'data': data, 'meta': meta, 'errors': null}),
    200,
    headers: {'content-type': 'application/json'},
  );

  TeacherService get service => TeacherService(
    ApiClient(
      client: MockClient((req) async {
        final path = req.url.path;
        requests.add(path);
        if (path.endsWith('/leave-requests')) return _ok(leaves);
        if (path.endsWith('/incidents')) return _ok(incidents);
        if (path.endsWith('/facility-reports')) return _ok(facilities);
        if (path.endsWith('/vehicle-requests')) {
          if (vehiclesFail) {
            return http.Response(
              jsonEncode({
                'data': null,
                'meta': {},
                'errors': {'message': 'boom'},
              }),
              500,
              headers: {'content-type': 'application/json'},
            );
          }
          return _ok(vehicles);
        }
        if (RegExp(r'/facility-reports/\d+$').hasMatch(path)) {
          return _ok(_facility());
        }
        return _ok(<Object>[]);
      }),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(720, 3200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: home),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _list(_Api api, ValueNotifier<int> reload, {VoidCallback? onCreate}) =>
    MyReportsList(
      service: api.service,
      onUnauthorized: () {},
      reload: reload,
      onCreate: onCreate,
    );

void main() {
  group('merge', () {
    test('puts all four kinds in one list, newest first, on one clock', () {
      final merged = mergeMyReports(
        // 01:30 UTC = 08:30 WIB, the earliest of the four
        leaves: [LeaveRequest.fromJson(_leave())],
        incidents: [
          StudentIncident.fromJson(_incident(occurredAt: '2026-11-01 10:00')),
        ],
        facilities: [
          FacilityReport.fromJson(_facility(createdAt: '2026-11-01 23:07')),
        ],
        vehicles: [
          VehicleRequest.fromJson(_vehicle(startAt: '2026-11-10 07:00')),
        ],
      );

      expect(merged.map((r) => r.kind), [
        ReportKind.vehicle, // 10 Nov, upcoming trips float to the top
        ReportKind.facility,
        ReportKind.incident,
        ReportKind.leave,
      ]);
      expect(merged.last.whenLabel, 'Diajukan 1 Nov 2026, 08:30');
      expect(merged[1].whenLabel, 'Dilaporkan 1 Nov 2026, 23:07');
    });

    test('ties go to the newer id, and an empty input gives an empty list', () {
      final merged = mergeMyReports(
        facilities: [
          FacilityReport.fromJson(_facility(id: 1)),
          FacilityReport.fromJson(_facility(id: 2)),
        ],
      );
      expect(merged.map((r) => r.id), [2, 1]);
      expect(mergeMyReports(), isEmpty);
    });
  });

  group('list', () {
    testWidgets(
      'fetches nothing until it is shown, then loads all four kinds',
      (tester) async {
        final api = _Api();
        final reload = ValueNotifier<int>(0);
        await _pump(tester, _list(api, reload));
        expect(api.requests, isEmpty);

        reload.value++;
        await tester.pumpAndSettle();

        for (final part in [
          '/leave-requests',
          '/incidents',
          '/facility-reports',
          '/vehicle-requests',
        ]) {
          expect(api.count(part), 1, reason: part);
        }
        expect(find.text('Izin sakit'), findsOneWidget);
        expect(find.text('Pelanggaran · Sedang'), findsOneWidget);
        expect(find.text('Bangunan · Sedang'), findsOneWidget);
        expect(find.text('Museum Geologi'), findsOneWidget);
        expect(find.text('Menunggu'), findsOneWidget);
        expect(find.text('Sedang ditangani'), findsOneWidget);
        expect(find.text('Dilaporkan'), findsWidgets);
        expect(find.text('Disetujui'), findsOneWidget);
      },
    );

    testWidgets('showing it again reloads', (tester) async {
      final api = _Api();
      final reload = ValueNotifier<int>(1);
      await _pump(tester, _list(api, reload));
      expect(api.count('/facility-reports'), 1);

      reload.value++;
      await tester.pumpAndSettle();

      expect(api.count('/facility-reports'), 2);
    });

    testWidgets('a filter chip narrows it to one kind', (tester) async {
      final api = _Api();
      await _pump(tester, _list(api, ValueNotifier<int>(1)));

      // The filter row scrolls sideways and builds lazily: bring the chip into view first.
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Sarpras'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Sarpras'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sarpras'));
      await tester.pumpAndSettle();

      expect(find.text('Bangunan · Sedang'), findsOneWidget);
      expect(find.text('Izin sakit'), findsNothing);
      expect(find.text('Museum Geologi'), findsNothing);
    });

    testWidgets('one kind failing does not hide the others', (tester) async {
      final api = _Api()..vehiclesFail = true;
      await _pump(tester, _list(api, ValueNotifier<int>(1)));

      expect(
        find.textContaining('Sebagian tidak dapat dimuat: Kendaraan'),
        findsOneWidget,
      );
      expect(find.text('Izin sakit'), findsOneWidget);
      expect(find.text('Museum Geologi'), findsNothing);
    });

    testWidgets('empty: says so and offers to create a report', (tester) async {
      final api = _Api()
        ..leaves = []
        ..incidents = []
        ..facilities = []
        ..vehicles = [];
      var created = 0;
      await _pump(
        tester,
        _list(api, ValueNotifier<int>(1), onCreate: () => created++),
      );

      expect(find.text('Belum ada laporan'), findsOneWidget);
      await tester.tap(find.text('Buat laporan'));
      expect(created, 1);
    });

    testWidgets(
      'tapping a card opens that kind\'s detail, and coming back reloads',
      (tester) async {
        final api = _Api();
        await _pump(tester, _list(api, ValueNotifier<int>(1)));
        expect(api.count('/facility-reports'), 1);

        await tester.tap(find.text('Bangunan · Sedang'));
        await tester.pumpAndSettle();
        expect(find.text('Detail laporan'), findsOneWidget);
        expect(
          api.requests.any((p) => RegExp(r'/facility-reports/5$').hasMatch(p)),
          isTrue,
        );

        Navigator.of(tester.element(find.text('Detail laporan'))).pop();
        await tester.pumpAndSettle();
        expect(
          api.count('/facility-reports'),
          greaterThan(2),
        ); // list, detail, list again
      },
    );
  });

  group('in the app', () {
    testWidgets('the Laporan tab loads when it is opened, not before', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        InboxScreen(
          service: api.service,
          unread: ValueNotifier<int>(0),
          onUnauthorized: () {},
        ),
      );
      expect(api.count('/facility-reports'), 0);

      await tester.tap(find.byKey(const ValueKey('inbox-segment-2')));
      await tester.pumpAndSettle();

      expect(api.count('/facility-reports'), 1);
      expect(find.text('Bangunan · Sedang'), findsOneWidget);
      expect(find.text('Akan segera hadir'), findsNothing);
    });

    test('the "Laporan Saya" menu entry opens the Laporan tab', () {
      final entry = menuEntry('laporan_saya');
      expect(entry.inboxSegment, kInboxReports);
      expect(entry.soon, isFalse);
    });
  });
}
