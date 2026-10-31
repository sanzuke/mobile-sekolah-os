import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/leave_models.dart';
import 'package:mobile_sekolah_os/screens/leave_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/leave_form_screen.dart';
import 'package:mobile_sekolah_os/screens/leave_requests_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/attachment_picker.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

class _Picker implements AttachmentPicker {
  _Picker(this.file);

  final PickedAttachment? file;

  @override
  Future<PickedAttachment?> pick() async => file;
}

Map<String, dynamic> _leave({
  int id = 7,
  String status = 'pending',
  String statusLabel = 'Menunggu persetujuan',
  bool detail = false,
  bool canCancel = true,
  String? note,
}) =>
    {
      'id': id,
      'type': 'sick',
      'type_label': 'Sakit',
      'start_date': '2026-11-02',
      'end_date': '2026-11-03',
      'reason': 'Demam dan perlu istirahat',
      'status': status,
      'status_label': statusLabel,
      'submitted_at': '2026-11-01T03:00:00+00:00',
      'decided_at': null,
      'decision_note': note,
      'has_attachment': false,
      'attachment_name': null,
      if (detail) ...{
        'can_cancel': canCancel,
        'lessons': [
          {
            'date': '2026-11-02',
            'day_name': 'Senin',
            'lessons': [
              {
                'session_number': 1,
                'start': '07:00',
                'end': '07:40',
                'subject': 'Fiqih',
                'grade': '8D'
              },
            ],
          },
        ],
        'approvals': [
          {
            'jenjang': 'mts',
            'label': 'MTs (kelas 7–9)',
            'status': 'approved',
            'decided_by': 'Kepala MTs',
            'decided_at': null,
            'note': null
          },
          {
            'jenjang': 'ma',
            'label': 'MA (kelas 10–12)',
            'status': 'pending',
            'decided_by': null,
            'decided_at': null,
            'note': null
          },
        ],
      },
    };

Map<String, dynamic> _preview({bool overlap = false, int count = 14}) => {
      'lessons': count == 0
          ? []
          : [
              {
                'date': '2026-11-02',
                'day_name': 'Senin',
                'lessons': [
                  {
                    'session_number': 1,
                    'start': '07:00',
                    'end': '07:40',
                    'subject': 'Fiqih',
                    'grade': '8D'
                  },
                  {
                    'session_number': 2,
                    'start': '07:40',
                    'end': '08:20',
                    'subject': 'Fiqih',
                    'grade': '8D'
                  },
                  {
                    'session_number': 4,
                    'start': '09:00',
                    'end': '09:40',
                    'subject': 'Fiqih',
                    'grade': '8D'
                  },
                  {
                    'session_number': 5,
                    'start': '09:40',
                    'end': '10:20',
                    'subject': 'Hadits',
                    'grade': '8D'
                  },
                ],
              },
            ],
      'lesson_count': count,
      'approvals_needed': [
        {'jenjang': 'mts', 'label': 'MTs (kelas 7–9)'},
        {'jenjang': 'ma', 'label': 'MA (kelas 10–12)'},
      ],
      'overlaps_existing': overlap,
    };

class _Api {
  _Api({this.preview, this.submit, this.list, this.detail});

  Map<String, dynamic>? preview;
  http.Response Function(http.Request)? submit;
  List<Map<String, dynamic>>? list;
  Map<String, dynamic>? detail;
  final requests = <http.Request>[];

  TeacherService get service => TeacherService(ApiClient(
        client: MockClient((req) async {
          requests.add(req);
          final path = req.url.path;
          Object body = <String, dynamic>{};
          Object meta = {};
          if (path.endsWith('/leave-requests/preview')) {
            body = preview ?? _preview();
          } else if (path.endsWith('/leave-requests') && req.method == 'POST') {
            return submit?.call(req) ?? _json(_leave(detail: true), 200);
          } else if (path.endsWith('/leave-requests')) {
            body = list ?? [_leave()];
            meta = {'last_page': 1, 'pending_count': 1};
          } else if (path.endsWith('/cancel')) {
            detail = _leave(
                status: 'cancelled',
                statusLabel: 'Dibatalkan',
                detail: true,
                canCancel: false);
            body = detail!;
          } else if (RegExp(r'/leave-requests/\d+$').hasMatch(path)) {
            body = detail ?? _leave(detail: true);
          }
          return _json(body, 200, meta: meta);
        }),
      ));
}

http.Response _json(Object body, int status, {Object meta = const {}}) =>
    http.Response(jsonEncode({'data': body, 'meta': meta, 'errors': null}), status,
        headers: {'content-type': 'application/json'});

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: home));
  await tester.pumpAndSettle();
}

Widget _form(_Api api,
        {PickedAttachment? file, DateTimeRange? range, void Function(LeaveRequest?)? onPop}) =>
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              final r = await Navigator.of(context).push<LeaveRequest>(
                  MaterialPageRoute(
                      builder: (_) => LeaveFormScreen(
                            service: api.service,
                            onUnauthorized: () {},
                            picker: _Picker(file),
                            initialRange: range,
                            now: DateTime(2026, 11, 1),
                          )));
              onPop?.call(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

final _range = DateTimeRange(
    start: DateTime(2026, 11, 2), end: DateTime(2026, 11, 3));

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder get _submit => find.widgetWithText(FilledButton, 'Kirim pengajuan');

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_submit).onPressed != null;

void main() {
  group('list', () {
    testWidgets('shows the requests with their status and opens one',
        (tester) async {
      final api = _Api();
      await _pump(
          tester,
          LeaveRequestsScreen(
              service: api.service, onUnauthorized: () {}));

      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Menunggu persetujuan'), findsOneWidget);
      expect(find.text('Demam dan perlu istirahat'), findsOneWidget);
      expect(find.text('2 Nov – 3 Nov 2026'), findsOneWidget);

      await tester.tap(find.text('Sakit'));
      await tester.pumpAndSettle();
      expect(find.text('Detail pengajuan'), findsOneWidget);
    });

    testWidgets('a status chip filters on the server', (tester) async {
      final api = _Api();
      await _pump(tester,
          LeaveRequestsScreen(service: api.service, onUnauthorized: () {}));

      // The chip row scrolls sideways; Ditolak is past the edge on a narrow screen.
      await tester.scrollUntilVisible(find.text('Ditolak'), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Ditolak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ditolak'));
      await tester.pumpAndSettle();

      expect(
          api.requests.any((r) =>
              r.url.path.endsWith('/leave-requests') &&
              r.url.queryParameters['status'] == 'rejected'),
          isTrue);
    });

    testWidgets('empty list invites the first request', (tester) async {
      final api = _Api(list: []);
      await _pump(tester,
          LeaveRequestsScreen(service: api.service, onUnauthorized: () {}));

      expect(find.text('Belum ada pengajuan'), findsOneWidget);
      expect(find.text('Ajukan'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('previews the affected lessons and who must approve',
        (tester) async {
      final api = _Api();
      await _pump(tester, _form(api, range: _range));
      await _openForm(tester);

      expect(find.text('14 jam pelajaran terdampak'), findsOneWidget);
      // JP 1 and 2 are one block; JP 4 is separate (a gap), JP 5 is another subject.
      expect(find.text('JP 1–2'), findsOneWidget);
      expect(find.text('07:00–08:20'), findsOneWidget);
      expect(find.text('JP 4'), findsOneWidget);
      expect(find.text('JP 5'), findsOneWidget);
      expect(find.text('Fiqih — 8D'), findsNWidgets(2));
      expect(find.text('Hadits — 8D'), findsOneWidget);
      expect(find.text('Perlu persetujuan: MTs (kelas 7–9) dan MA (kelas 10–12)'),
          findsOneWidget);
    });

    testWidgets('Kirim stays off until type, dates and a real reason are given',
        (tester) async {
      final api = _Api();
      await _pump(tester, _form(api, range: _range));
      await _openForm(tester);
      expect(_enabled(tester), isFalse);

      await tester.tap(find.text('Sakit'));
      await tester.pump();
      expect(_enabled(tester), isFalse); // no reason yet

      await tester.enterText(find.byType(TextField), 'sdh');
      await tester.pump();
      expect(_enabled(tester), isFalse); // under 5 characters

      await tester.enterText(find.byType(TextField), 'Demam tinggi');
      await tester.pump();
      expect(_enabled(tester), isTrue);
    });

    testWidgets('submits the fields and the attachment as multipart',
        (tester) async {
      final api = _Api();
      LeaveRequest? result;
      await _pump(
          tester,
          _form(api,
              range: _range,
              file: PickedAttachment(name: 'surat.pdf', bytes: [1, 2, 3, 4]),
              onPop: (r) => result = r));
      await _openForm(tester);

      await tester.tap(find.text('Sakit'));
      await tester.enterText(find.byType(TextField), 'Demam tinggi');
      await tester.tap(find.text('Tambah lampiran'));
      await tester.pumpAndSettle();
      expect(find.text('surat.pdf'), findsOneWidget);

      await tester.ensureVisible(_submit);
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      final post = api.requests.singleWhere(
          (r) => r.method == 'POST' && r.url.path.endsWith('/leave-requests'));
      expect(post.headers['content-type'], startsWith('multipart/form-data'));
      for (final part in [
        'name="type"',
        'sick',
        'name="start_date"',
        '2026-11-02',
        'name="end_date"',
        '2026-11-03',
        'name="reason"',
        'Demam tinggi',
        'name="attachment"',
        'filename="surat.pdf"',
      ]) {
        expect(post.body, contains(part), reason: part);
      }
      expect(result?.id, 7, reason: 'the form hands the created request back');
    });

    testWidgets('an overlapping request is flagged and cannot be sent',
        (tester) async {
      final api = _Api(preview: _preview(overlap: true));
      await _pump(tester, _form(api, range: _range));
      await _openForm(tester);
      await tester.tap(find.text('Sakit'));
      await tester.enterText(find.byType(TextField), 'Demam tinggi');
      await tester.pump();

      expect(find.textContaining('bertumpuk dengan pengajuan lain'),
          findsOneWidget);
      expect(_enabled(tester), isFalse);
    });

    testWidgets('a day without lessons says so and can still be sent',
        (tester) async {
      final api = _Api(preview: _preview(count: 0));
      await _pump(tester, _form(api, range: _range));
      await _openForm(tester);
      await tester.tap(find.text('Sakit'));
      await tester.enterText(find.byType(TextField), 'Demam tinggi');
      await tester.pump();

      expect(find.text('Tidak ada jam mengajar pada tanggal ini.'),
          findsOneWidget);
      expect(_enabled(tester), isTrue);
    });

    testWidgets('more than 90 days is refused before asking the server',
        (tester) async {
      final api = _Api();
      await _pump(
          tester,
          _form(api,
              range: DateTimeRange(
                  start: DateTime(2026, 11, 2), end: DateTime(2027, 3, 1))));
      await _openForm(tester);
      await tester.tap(find.text('Sakit'));
      await tester.enterText(find.byType(TextField), 'Cuti panjang');
      await tester.pump();

      expect(find.text('Rentang tanggal maksimal 90 hari.'), findsOneWidget);
      expect(_enabled(tester), isFalse);
      expect(api.requests.any((r) => r.url.path.endsWith('/preview')), isFalse);
    });

    testWidgets('an attachment over 5 MB is rejected', (tester) async {
      final api = _Api();
      await _pump(
          tester,
          _form(api,
              range: _range,
              file: PickedAttachment(
                  name: 'besar.pdf',
                  bytes: List.filled(kLeaveMaxAttachmentBytes + 1, 0))));
      await _openForm(tester);
      await tester.tap(find.text('Sakit'));
      await tester.enterText(find.byType(TextField), 'Demam tinggi');
      await tester.tap(find.text('Tambah lampiran'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lampiran maksimal 5 MB'), findsOneWidget);
      expect(_enabled(tester), isFalse);

      await tester.tap(find.byTooltip('Hapus lampiran'));
      await tester.pump();
      expect(_enabled(tester), isTrue);
    });

    testWidgets('a server refusal is shown and the form stays open',
        (tester) async {
      final api = _Api(
          submit: (_) => http.Response(
              jsonEncode({
                'data': null,
                'meta': {},
                'errors': {'message': 'Tanggal ini bertumpuk dengan pengajuan lain.'}
              }),
              422,
              headers: {'content-type': 'application/json'}));
      await _pump(tester, _form(api, range: _range));
      await _openForm(tester);
      await tester.tap(find.text('Sakit'));
      await tester.enterText(find.byType(TextField), 'Demam tinggi');
      await tester.pump();
      await tester.ensureVisible(_submit);
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text('Tanggal ini bertumpuk dengan pengajuan lain.'),
          findsOneWidget);
      expect(find.text('Ajukan izin / cuti'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('shows who approved, who is pending, and the lessons',
        (tester) async {
      final api = _Api();
      await _pump(
          tester,
          LeaveDetailScreen(
              service: api.service, onUnauthorized: () {}, id: 7));

      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('MTs (kelas 7–9)'), findsOneWidget);
      expect(find.text('Disetujui oleh Kepala MTs'), findsOneWidget);
      expect(find.text('MA (kelas 10–12)'), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);
      expect(find.text('1 jam pelajaran terdampak'), findsOneWidget);
    });

    testWidgets('a rejection shows the reason it was given', (tester) async {
      final api = _Api(
          detail: _leave(
              status: 'rejected',
              statusLabel: 'Ditolak',
              detail: true,
              canCancel: false,
              note: 'Bertabrakan dengan ujian'));
      await _pump(
          tester,
          LeaveDetailScreen(
              service: api.service, onUnauthorized: () {}, id: 7));

      expect(find.text('Ditolak'), findsWidgets);
      expect(find.text('Bertabrakan dengan ujian'), findsOneWidget);
      expect(find.text('Batalkan pengajuan'), findsNothing);
    });

    testWidgets('a pending request can be cancelled after a confirmation',
        (tester) async {
      final api = _Api();
      await _pump(
          tester,
          LeaveDetailScreen(
              service: api.service, onUnauthorized: () {}, id: 7));

      await tester.ensureVisible(find.text('Batalkan pengajuan'));
      await tester.tap(find.text('Batalkan pengajuan'));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan pengajuan?'), findsOneWidget);

      // "Tidak" does nothing
      await tester.tap(find.text('Tidak'));
      await tester.pumpAndSettle();
      expect(api.requests.any((r) => r.url.path.endsWith('/cancel')), isFalse);

      await tester.tap(find.text('Batalkan pengajuan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Batalkan'));
      await tester.pumpAndSettle();

      expect(api.requests.where((r) => r.url.path.endsWith('/cancel')), hasLength(1));
      expect(find.text('Dibatalkan'), findsWidgets);
      expect(find.text('Batalkan pengajuan'), findsNothing);
    });
  });
}
