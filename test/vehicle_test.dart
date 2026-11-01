import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/models/vehicle_models.dart';
import 'package:mobile_sekolah_os/screens/notification_target.dart';
import 'package:mobile_sekolah_os/screens/vehicle_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/vehicle_form_screen.dart';
import 'package:mobile_sekolah_os/screens/vehicle_requests_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/push_messaging.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

const _labels = {
  'pending': 'Menunggu',
  'approved': 'Disetujui',
  'rejected': 'Ditolak',
  'cancelled': 'Dibatalkan',
  'completed': 'Selesai',
};

Map<String, dynamic> _request({
  int id = 7,
  String status = 'pending',
  bool canEdit = true,
  bool canCancel = true,
  bool approved = false,
  String? note,
}) => {
  'id': id,
  'purpose': 'Study tour kelas 9',
  'destination': 'Museum Geologi',
  'start_at': '2026-11-10 07:00',
  'end_at': '2026-11-10 15:00',
  'passenger_count': 25,
  'status': status,
  'status_label': _labels[status],
  'can_edit': canEdit,
  'can_cancel': canCancel,
  'vehicle': approved
      ? {'name': 'Bus Sekolah', 'plate_number': 'D 1234 AB'}
      : null,
  'driver_name': approved ? 'Pak Asep' : null,
  'public_note': note,
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
    _request(),
    _request(
      id: 8,
      status: 'rejected',
      canEdit: false,
      canCancel: false,
      note: 'Bus servis.',
    ),
  ];
  Map<String, dynamic>? detail;
  http.Response Function(http.Request)? save;
  List<Map<String, dynamic>> vehicles = [
    {
      'id': 1,
      'name': 'Bus Sekolah',
      'plate_number': 'D 1234 AB',
      'type': 'Bus',
      'capacity': 30,
      'available': true,
    },
    {
      'id': 2,
      'name': 'Avanza',
      'plate_number': 'D 5678 CD',
      'type': 'Mobil',
      'capacity': 6,
      'available': false,
    },
  ];

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
        if (path.endsWith('/vehicles/availability')) {
          return _json(vehicles, 200);
        }
        if (path.endsWith('/cancel')) {
          return _json(
            _request(status: 'cancelled', canEdit: false, canCancel: false),
            200,
          );
        }
        if (req.method == 'POST' || req.method == 'PUT') {
          return save?.call(req) ?? _json(_request(), 200);
        }
        if (RegExp(r'/vehicle-requests/\d+$').hasMatch(path)) {
          return _json(detail ?? _request(), 200);
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

/// "Now" is fixed so the default trip (tomorrow 07:00-15:00) and every limit are predictable.
final _now = DateTime(2026, 11, 1, 10, 0);

Widget _formHost(
  _Api api, {
  VehicleRequest? existing,
  void Function(VehicleRequest?)? onPop,
}) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          final r = await Navigator.of(context).push<VehicleRequest>(
            MaterialPageRoute(
              builder: (_) => VehicleFormScreen(
                service: api.service,
                onUnauthorized: () {},
                existing: existing,
                now: _now,
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

Future<void> _fillText(WidgetTester tester) async {
  await tester.enterText(_field('Keperluan'), 'Study tour kelas 9');
  await tester.enterText(_field('Tujuan'), 'Museum Geologi');
  await tester.pumpAndSettle();
}

void main() {
  group('list', () {
    testWidgets('shows destination, purpose, time and status', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        VehicleRequestsScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Museum Geologi'), findsNWidgets(2));
      expect(find.text('Menunggu'), findsWidgets);
      expect(find.text('Ditolak'), findsWidgets);
    });

    testWidgets('filters by status through the server', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        VehicleRequestsScreen(service: api.service, onUnauthorized: () {}),
      );

      // The filter row scrolls sideways and builds lazily: bring the chip into view first.
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
      expect(find.text('Museum Geologi'), findsOneWidget);
    });

    testWidgets('says so when there are no requests', (tester) async {
      final api = _Api()..list = [];
      await _pump(
        tester,
        VehicleRequestsScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Belum ada pengajuan'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('a waiting request can be changed or withdrawn', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        VehicleDetailScreen(service: api.service, onUnauthorized: () {}, id: 7),
      );

      expect(find.text('25 penumpang'), findsOneWidget);
      expect(find.text('Ubah'), findsOneWidget);

      await tester.tap(find.text('Batalkan pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Batalkan pengajuan'));
      await tester.pumpAndSettle();

      expect(api.last('POST', '/vehicle-requests/7/cancel'), isNotNull);
      expect(find.text('Pengajuan ini dibatalkan.'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
    });

    testWidgets(
      'an approved request shows the vehicle and driver, and can only be withdrawn',
      (tester) async {
        final api = _Api()
          ..detail = _request(
            status: 'approved',
            canEdit: false,
            approved: true,
            note: 'Bensin dari sekolah.',
          );
        await _pump(
          tester,
          VehicleDetailScreen(
            service: api.service,
            onUnauthorized: () {},
            id: 7,
          ),
        );

        expect(find.text('Bus Sekolah · D 1234 AB'), findsOneWidget);
        expect(find.text('Sopir: Pak Asep'), findsOneWidget);
        expect(find.text('Bensin dari sekolah.'), findsOneWidget);
        expect(find.text('Batalkan pengajuan'), findsOneWidget);
        expect(find.text('Ubah'), findsNothing);
      },
    );

    testWidgets('a rejected request shows the reason and no buttons', (
      tester,
    ) async {
      final api = _Api()
        ..detail = _request(
          status: 'rejected',
          canEdit: false,
          canCancel: false,
          note: 'Bus sedang servis.',
        );
      await _pump(
        tester,
        VehicleDetailScreen(service: api.service, onUnauthorized: () {}, id: 7),
      );

      expect(find.text('Alasan penolakan'), findsOneWidget);
      expect(find.text('Bus sedang servis.'), findsOneWidget);
      expect(find.text('Batalkan pengajuan'), findsNothing);
    });

    testWidgets('a finished trip has no buttons', (tester) async {
      final api = _Api()
        ..detail = _request(
          status: 'completed',
          canEdit: false,
          canCancel: false,
          approved: true,
        );
      await _pump(
        tester,
        VehicleDetailScreen(service: api.service, onUnauthorized: () {}, id: 7),
      );

      expect(find.text('Selesai'), findsWidgets);
      expect(find.text('Batalkan pengajuan'), findsNothing);
    });
  });

  group('form', () {
    testWidgets('lists which vehicles are free for the default trip', (
      tester,
    ) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);

      final call = api.last('GET', '/vehicles/availability')!;
      expect(call.url.queryParameters['from'], '2026-11-02 07:00');
      expect(call.url.queryParameters['to'], '2026-11-02 15:00');
      expect(find.text('Bus Sekolah'), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);
      expect(find.text('Terpakai'), findsOneWidget);
    });

    testWidgets('flags vehicles too small for the passengers', (tester) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);

      await tester.enterText(_field('Jumlah penumpang'), '10');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('kapasitas kurang'),
        findsOneWidget,
      ); // only the 6-seat car
    });

    testWidgets('validates before sending anything', (tester) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);
      await tester.enterText(_field('Jumlah penumpang'), '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kirim pengajuan'));
      await tester.pumpAndSettle();

      expect(find.text('Tuliskan keperluan peminjaman.'), findsOneWidget);
      expect(find.text('Tuliskan tujuan perjalanan.'), findsOneWidget);
      expect(find.text('Isi jumlah penumpang, minimal 1.'), findsOneWidget);
      expect(api.last('POST', '/vehicle-requests'), isNull);
    });

    testWidgets('sends the trip and returns the saved request', (tester) async {
      final api = _Api();
      VehicleRequest? popped;
      await _pump(tester, _formHost(api, onPop: (r) => popped = r));
      await _openForm(tester);
      await _fillText(tester);
      await tester.enterText(_field('Jumlah penumpang'), '25');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kirim pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/vehicle-requests'), {
        'purpose': 'Study tour kelas 9',
        'destination': 'Museum Geologi',
        'start_at': '2026-11-02 07:00',
        'end_at': '2026-11-02 15:00',
        'passenger_count': 25,
      });
      expect(popped?.id, 7);
    });

    testWidgets('editing prefills the form and saves with PUT', (tester) async {
      final api = _Api();
      final existing = VehicleRequest.fromJson(_request());
      await _pump(tester, _formHost(api, existing: existing));
      await _openForm(tester);

      expect(find.text('Study tour kelas 9'), findsOneWidget);
      expect(find.text('Ubah pengajuan'), findsOneWidget);

      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(
        api.sent('PUT', '/vehicle-requests/7')['start_at'],
        '2026-11-10 07:00',
      );
    });

    testWidgets('shows a server refusal and keeps the form', (tester) async {
      final api = _Api()
        ..save = (_) => _json(
          null,
          429,
          errors: {'message': 'Anda masih punya 5 pengajuan yang menunggu.'},
        );
      await _pump(tester, _formHost(api));
      await _openForm(tester);
      await _fillText(tester);

      await tester.tap(find.text('Kirim pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(find.text('Pinjam kendaraan'), findsOneWidget);
      expect(find.textContaining('5 pengajuan'), findsOneWidget);
    });
  });

  group('notification and push', () {
    test('a vehicle_request notification and push open the request', () {
      NotificationItem n(String type) => NotificationItem(
        id: 'x',
        title: 't',
        isRead: false,
        target: NotificationTarget(type: type, id: 7),
      );

      expect(hasNotificationTarget(n('vehicle_request')), isTrue);
      expect(hasNotificationTarget(n('something_else')), isFalse);

      final m = PushMessage.fromData({
        'type': 'vehicle_request',
        'vehicle_request_id': '7',
      });
      expect(m.vehicleRequestId, 7);
      expect(m.facilityReportId, isNull);
    });
  });
}
