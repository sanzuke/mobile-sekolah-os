import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/incident_models.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/incident_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/incident_form_screen.dart';
import 'package:mobile_sekolah_os/screens/incidents_screen.dart';
import 'package:mobile_sekolah_os/screens/notification_target.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/push_messaging.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _incident({
  int id = 3,
  String status = 'reported',
  bool canEdit = true,
  bool detail = false,
  String category = 'discipline',
  String? note,
}) => {
  'id': id,
  'category': category,
  'category_label': category == 'medical' ? 'Kesehatan' : 'Pelanggaran',
  'severity': 'sedang',
  'severity_label': 'Sedang',
  'occurred_at': '2026-11-01 08:30',
  'status': status,
  'status_label': {
    'reported': 'Dilaporkan',
    'handling': 'Sedang ditangani',
    'resolved': 'Selesai',
    'cancelled': 'Dibatalkan',
  }[status],
  'can_edit': canEdit,
  'students': [
    {'id': 1, 'name': 'Ahmad Fauzi', 'grade_name': '8A'},
    {'id': 2, 'name': 'Budi Santoso', 'grade_name': '8A'},
  ],
  'public_note': note,
  if (detail) ...{
    'location': 'Kantin',
    'description': 'Dua siswa berkelahi di kantin.',
    'action_taken': 'Dilerai.',
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
  List<Map<String, dynamic>> list = [
    _incident(),
    _incident(id: 4, status: 'resolved', canEdit: false, category: 'medical'),
  ];
  Map<String, dynamic>? detail;
  int extraStudents = 0;
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
        if (path.endsWith('/student-options')) {
          return _json([
            {
              'id': 1,
              'name': 'Ahmad Fauzi',
              'nis': '100001',
              'grade': {'id': 9, 'name': '8A'},
            },
            {
              'id': 2,
              'name': 'Budi Santoso',
              'nis': '100002',
              'grade': {'id': 9, 'name': '8A'},
            },
            for (var n = 0; n < extraStudents; n++)
              {
                'id': 100 + n,
                'name': 'Siswa Tambahan $n',
                'nis': '9${100 + n}',
                'grade': {'id': 9, 'name': '8B'},
              },
          ], 200);
        }
        if (path.endsWith('/cancel')) {
          return _json(
            _incident(status: 'cancelled', canEdit: false, detail: true),
            200,
          );
        }
        if (req.method == 'POST' || req.method == 'PUT') {
          return save?.call(req) ?? _json(_incident(detail: true), 200);
        }
        if (RegExp(r'/incidents/\d+$').hasMatch(path)) {
          return _json(detail ?? _incident(detail: true), 200);
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
  StudentIncident? existing,
  void Function(StudentIncident?)? onPop,
}) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          final r = await Navigator.of(context).push<StudentIncident>(
            MaterialPageRoute(
              builder: (_) => IncidentFormScreen(
                service: api.service,
                onUnauthorized: () {},
                existing: existing,
                now: DateTime(2026, 11, 1, 10, 0),
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

Future<void> _pickStudent(
  WidgetTester tester,
  String query,
  String name,
) async {
  await tester.tap(find.text('Tambah siswa'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Cari nama atau NIS siswa'),
    query,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  group('list', () {
    testWidgets('shows category, severity, students and status', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        IncidentsScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Pelanggaran · Sedang'), findsOneWidget);
      expect(find.text('Kesehatan · Sedang'), findsOneWidget);
      expect(find.text('Ahmad Fauzi, Budi Santoso'), findsWidgets);
      expect(find.text('1 Nov 2026, 08:30'), findsWidgets);
      expect(find.text('Dilaporkan'), findsWidgets);
    });

    testWidgets(
      'a status chip filters on the server and an empty result says so',
      (tester) async {
        final api = _Api();
        await _pump(
          tester,
          IncidentsScreen(service: api.service, onUnauthorized: () {}),
        );

        final cancelled = find.widgetWithText(ChoiceChip, 'Dibatalkan');
        await tester.drag(find.byType(ListView).first, const Offset(-600, 0));
        await tester.pumpAndSettle();
        await tester.tap(cancelled);
        await tester.pumpAndSettle();

        expect(api.requests.last.url.queryParameters['status'], 'cancelled');
        expect(
          find.text('Tidak ada laporan dengan status ini'),
          findsOneWidget,
        );
      },
    );

    testWidgets('an empty list invites the first report', (tester) async {
      final api = _Api()..list = [];
      await _pump(
        tester,
        IncidentsScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Belum ada laporan'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets(
      'an untaken report can be edited or withdrawn, after a confirmation',
      (tester) async {
        final api = _Api();
        await _pump(
          tester,
          IncidentDetailScreen(
            service: api.service,
            onUnauthorized: () {},
            id: 3,
          ),
        );

        expect(find.text('Dua siswa berkelahi di kantin.'), findsOneWidget);
        expect(find.text('Ahmad Fauzi'), findsOneWidget);
        expect(find.textContaining('masih bisa mengubah'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Batalkan laporan'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tidak'));
        await tester.pumpAndSettle();
        expect(api.last('POST', '/cancel'), isNull);

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Batalkan laporan'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Batalkan laporan'),
          ),
        );
        await tester.pumpAndSettle();

        expect(api.last('POST', '/cancel'), isNotNull);
        expect(find.text('Dibatalkan'), findsOneWidget);
        expect(find.text('Ubah'), findsNothing); // locked again
      },
    );

    testWidgets('a handled report is read-only and shows the public note', (
      tester,
    ) async {
      final api = _Api()
        ..detail = _incident(
          status: 'resolved',
          canEdit: false,
          detail: true,
          note: 'Siswa sudah dibina.',
        );
      await _pump(
        tester,
        IncidentDetailScreen(
          service: api.service,
          onUnauthorized: () {},
          id: 3,
        ),
      );

      expect(find.text('Siswa sudah dibina.'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
      expect(find.text('Batalkan laporan'), findsNothing);
    });
  });

  group('form', () {
    testWidgets(
      'students and a real chronology are required before anything is sent',
      (tester) async {
        final api = _Api();
        await _pump(tester, _formHost(api));
        await _openForm(tester);

        await tester.tap(find.text('Kirim laporan'));
        await tester.pumpAndSettle();

        expect(find.text('Pilih minimal satu siswa.'), findsOneWidget);
        expect(find.textContaining('minimal 10 karakter'), findsOneWidget);
        expect(api.requests, isEmpty);
      },
    );

    testWidgets('student search waits for two characters', (tester) async {
      final api = _Api();
      await _pump(tester, _formHost(api));
      await _openForm(tester);

      await tester.tap(find.text('Tambah siswa'));
      await tester.pumpAndSettle();
      expect(find.text('Cari siswa'), findsOneWidget);
      expect(find.textContaining('minimal 2 huruf'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cari nama atau NIS siswa'),
        'a',
      );
      await tester.pumpAndSettle();
      expect(api.requests, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, 'Cari nama atau NIS siswa'),
        'ah',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ahmad Fauzi'), findsOneWidget);
      expect(find.text('Kelas 8A'), findsNWidgets(2)); // both results are in 8A
      expect(find.text('NIS 100001'), findsOneWidget);
      expect(find.text('2 siswa ditemukan'), findsOneWidget);
    });

    testWidgets(
      'a full page of results says it is only the first ones, and added students are not offered twice',
      (tester) async {
        final api = _Api()
          ..extraStudents = 18; // 2 + 18 = the server's cap of 20
        await _pump(tester, _formHost(api));
        await _openForm(tester);

        await _pickStudent(tester, 'ah', 'Ahmad Fauzi');
        await tester.tap(find.text('Tambah siswa'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Cari nama atau NIS siswa'),
          'sis',
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Menampilkan 20 hasil pertama'),
          findsOneWidget,
        );
        expect(find.text('20 siswa ditemukan'), findsNothing);
        // Ahmad is already on the report: shown with a check, not offered again.
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      },
    );

    testWidgets(
      'confirms the route, then sends the report with the chosen students',
      (tester) async {
        final api = _Api();
        StudentIncident? popped;
        await _pump(tester, _formHost(api, onPop: (r) => popped = r));
        await _openForm(tester);

        await _pickStudent(tester, 'ah', 'Ahmad Fauzi');
        await _pickStudent(tester, 'bu', 'Budi Santoso');
        await tester.enterText(
          _field('Kronologi: apa yang terjadi'),
          'Berkelahi di kantin saat istirahat.',
        );
        await tester.tap(find.widgetWithText(ChoiceChip, 'Berat'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kirim laporan'));
        await tester.pumpAndSettle();
        expect(find.text('Kirim laporan?'), findsOneWidget);
        expect(find.text('Laporan akan diteruskan ke BK.'), findsOneWidget);
        expect(api.last('POST', '/incidents'), isNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
        await tester.pumpAndSettle();

        final body = api.sent('POST', '/incidents');
        expect(body['category'], 'discipline');
        expect(body['severity'], 'berat');
        expect(body['students'], [1, 2]);
        expect(body['description'], 'Berkelahi di kantin saat istirahat.');
        expect(
          body['occurred_at'],
          '2026-11-01 09:59',
        ); // a minute before "now", WIB wall clock
        expect(popped?.id, 3);
      },
    );

    testWidgets(
      'a medical report goes to UKS, and a serious one warns to call them',
      (tester) async {
        final api = _Api();
        await _pump(tester, _formHost(api));
        await _openForm(tester);

        await tester.tap(
          find.widgetWithText(ChoiceChip, 'Kesehatan · Diteruskan ke UKS'),
        );
        await tester.tap(find.widgetWithText(ChoiceChip, 'Berat'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('hubungi petugas UKS langsung'),
          findsOneWidget,
        );

        await _pickStudent(tester, 'ah', 'Ahmad Fauzi');
        await tester.enterText(
          _field('Kronologi: apa yang terjadi'),
          'Pingsan di lapangan upacara.',
        );
        await tester.tap(find.text('Kirim laporan'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('diteruskan ke UKS. Untuk keadaan darurat'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
        await tester.pumpAndSettle();
        expect(api.sent('POST', '/incidents')['category'], 'medical');
      },
    );

    testWidgets('editing pre-fills the report and saves with PUT', (
      tester,
    ) async {
      final api = _Api();
      final existing = StudentIncident.fromJson(_incident(detail: true));
      await _pump(tester, _formHost(api, existing: existing));
      await _openForm(tester);

      expect(find.text('Ubah laporan'), findsOneWidget);
      expect(find.text('Dua siswa berkelahi di kantin.'), findsOneWidget);
      expect(find.text('Ahmad Fauzi (8A)'), findsOneWidget);

      await tester.enterText(_field('Tempat (opsional)'), 'Aula');
      await tester.tap(find.text('Simpan perubahan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(api.sent('PUT', '/incidents/3')['location'], 'Aula');
    });

    testWidgets(
      'leaving with unsaved text asks first; an untouched form does not',
      (tester) async {
        final api = _Api();
        await _pump(tester, _formHost(api));
        await _openForm(tester);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Keluar tanpa menyimpan?'), findsNothing);

        await _openForm(tester);
        await tester.enterText(_field('Tempat (opsional)'), 'Kantin');
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Keluar tanpa menyimpan?'), findsOneWidget);
        await tester.tap(find.text('Lanjut menulis'));
        await tester.pumpAndSettle();
        expect(find.text('Lapor kejadian siswa'), findsOneWidget);
      },
    );

    testWidgets("a server refusal is shown and the form stays open", (
      tester,
    ) async {
      final api = _Api()
        ..save = (_) => _json(
          null,
          429,
          errors: {
            'message': 'Batas 10 laporan per hari sudah tercapai.',
            'details': {},
          },
        );
      await _pump(tester, _formHost(api));
      await _openForm(tester);
      await _pickStudent(tester, 'ah', 'Ahmad Fauzi');
      await tester.enterText(
        _field('Kronologi: apa yang terjadi'),
        'Berkelahi di kantin saat istirahat.',
      );

      await tester.tap(find.text('Kirim laporan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
      await tester.pumpAndSettle();

      expect(
        find.text('Batas 10 laporan per hari sudah tercapai.'),
        findsOneWidget,
      );
      expect(find.text('Lapor kejadian siswa'), findsOneWidget);
    });
  });

  group('notification and push', () {
    test('a student_incident notification and push open the report', () {
      NotificationItem n(String type) => NotificationItem(
        id: 'x',
        title: 't',
        isRead: false,
        target: NotificationTarget(type: type, id: 3),
      );

      expect(hasNotificationTarget(n('student_incident')), isTrue);
      expect(hasNotificationTarget(n('something_else')), isFalse);

      final m = PushMessage.fromData({
        'type': 'student_incident',
        'student_incident_id': '3',
      });
      expect(m.studentIncidentId, 3);
      expect(m.meetingMinuteId, isNull);
    });
  });
}
