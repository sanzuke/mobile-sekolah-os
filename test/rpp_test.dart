import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/rpp_models.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/rpp_form_screen.dart';
import 'package:mobile_sekolah_os/screens/rpp_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/attachment_picker.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _week(
  String start,
  String end, {
  String state = 'none',
  int? id,
  String? title,
  String? notes,
  bool canSubmit = true,
  bool current = false,
  bool overdue = false,
}) => {
  'id': id,
  'week_start': start,
  'week_end': end,
  'is_current': current,
  'state': state,
  'title': title,
  'description': null,
  'file_extension': id == null ? null : 'pdf',
  'review_notes': notes,
  'can_submit': canSubmit,
  'due': end,
  'overdue': overdue,
};

http.Response _json(Object? body, int status, {Object? errors}) =>
    http.Response(
      jsonEncode({
        'data': body,
        'meta': {'max_size_mb': 10},
        'errors': errors,
      }),
      status,
      headers: {'content-type': 'application/json'},
    );

class _Picker implements AttachmentPicker {
  _Picker(this.file);
  final PickedAttachment? file;
  @override
  Future<PickedAttachment?> pick() async => file;
}

class _Api {
  final requests = <http.BaseRequest>[];
  List<Map<String, dynamic>> weeks = [];
  http.Response Function()? onPost;

  TeacherService get service => TeacherService(
    ApiClient(
      client: MockClient.streaming((req, body) async {
        requests.add(req);
        final res = req.method == 'POST'
            ? (onPost?.call() ??
                  _json({
                    'rpp': _week(
                      '2026-10-26',
                      '2026-11-01',
                      state: 'submitted',
                      id: 5,
                      title: 'RPP',
                    ),
                    'message': 'ok',
                  }, 200))
            : _json(weeks, 200);
        return http.StreamedResponse(
          Stream.value(res.bodyBytes),
          res.statusCode,
          headers: res.headers,
        );
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

RppWeek _open() =>
    RppWeek.fromJson(_week('2026-10-26', '2026-11-01', current: true));

void main() {
  group('models', () {
    test('a week reads its state, deadline and whether it can be filled', () {
      final w = RppWeek.fromJson(
        _week(
          '2026-10-26',
          '2026-11-01',
          state: 'rejected',
          id: 3,
          title: 'RPP 1',
          notes: 'Lengkapi KD',
        ),
      );
      expect(w.hasFile, isTrue);
      expect(w.reviewNotes, 'Lengkapi KD');
      expect(w.due, '2026-11-01');
      expect(
        RppWeek.fromJson(_week('2026-10-26', '2026-11-01')).hasFile,
        isFalse,
      );
    });

    test('status labels', () {
      expect(rppStatus('approved').label, 'Disetujui');
      expect(rppStatus('submitted').label, 'Menunggu review');
      expect(rppStatus('rejected').tone, 'bad');
      expect(rppStatus('none').label, 'Belum diunggah');
      expect(rppStatus('none', overdue: true).label, 'Terlambat');
    });

    test('the home duty is absent on an older server', () {
      final base = {
        'date': '2026-10-31',
        'today': {'state': 'none', 'lessons': []},
      };
      expect(HomeData.fromJson(base).rppDuty, isNull);
      final withDuty = HomeData.fromJson({
        ...base,
        'duties': {
          'rpp': {
            'week_start': '2026-10-26',
            'state': 'submitted',
            'due': '2026-11-01',
            'overdue': false,
          },
        },
      });
      expect(withDuty.rppDuty?.state, 'submitted');
    });
  });

  group('list', () {
    testWidgets(
      'shows each week with its status and the head\'s note after a rejection',
      (tester) async {
        final api = _Api()
          ..weeks = [
            _week(
              '2026-10-26',
              '2026-11-01',
              state: 'rejected',
              id: 3,
              title: 'RPP Fiqih',
              notes: 'Lengkapi KD',
              current: true,
            ),
            _week('2026-11-02', '2026-11-08'),
          ];
        await _pump(
          tester,
          RppScreen(service: api.service, onUnauthorized: () {}),
        );

        expect(find.text('Ditolak'), findsOneWidget);
        expect(find.text('Belum diunggah'), findsOneWidget);
        expect(find.text('RPP Fiqih'), findsOneWidget);
        expect(find.textContaining('Lengkapi KD'), findsOneWidget);
        expect(find.text('Pekan ini'), findsOneWidget);
      },
    );

    testWidgets('an approved week is view-only', (tester) async {
      final api = _Api()
        ..weeks = [
          _week(
            '2026-10-26',
            '2026-11-01',
            state: 'approved',
            id: 3,
            title: 'RPP',
            canSubmit: false,
          ),
        ];
      await _pump(
        tester,
        RppScreen(service: api.service, onUnauthorized: () {}),
      );

      expect(find.text('Lihat'), findsOneWidget);
      expect(find.text('Disetujui'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('sends the week, title and file, then pops true', (
      tester,
    ) async {
      final api = _Api();
      bool? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => RppFormScreen(
                          service: api.service,
                          onUnauthorized: () {},
                          week: _open(),
                          maxBytes: 10 * 1024 * 1024,
                          picker: _Picker(
                            const PickedAttachment(
                              name: 'rpp-fiqih.pdf',
                              bytes: [1, 2, 3],
                            ),
                          ),
                        ),
                      ),
                    ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.text('Pilih berkas'));
      await tester.pumpAndSettle();
      // The title is suggested from the file name.
      expect(find.text('rpp-fiqih'), findsOneWidget);

      await tester.tap(find.text('Kirim RPP'));
      await tester.pumpAndSettle();

      final post = api.requests.whereType<http.MultipartRequest>().single;
      expect(post.url.path, endsWith('/teacher/rpp'));
      expect(post.fields['week_start'], '2026-10-26');
      expect(post.fields['title'], 'rpp-fiqih');
      expect(post.files.single.field, 'file');
      expect(result, isTrue);
    });

    testWidgets('a file over the limit is refused before the upload', (
      tester,
    ) async {
      final api = _Api();
      await _pump(
        tester,
        RppFormScreen(
          service: api.service,
          onUnauthorized: () {},
          week: _open(),
          maxBytes: 10,
          picker: _Picker(
            const PickedAttachment(
              name: 'besar.pdf',
              bytes: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pilih berkas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ukuran berkas maksimal'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a wrong format is refused', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        RppFormScreen(
          service: api.service,
          onUnauthorized: () {},
          week: _open(),
          maxBytes: 1024,
          picker: _Picker(const PickedAttachment(name: 'foto.png', bytes: [1])),
        ),
      );
      await tester.tap(find.text('Pilih berkas'));
      await tester.pumpAndSettle();

      expect(
        find.text('Berkas harus berformat PDF, DOC, atau DOCX.'),
        findsOneWidget,
      );
    });

    testWidgets('the server\'s message is shown and nothing pops', (
      tester,
    ) async {
      final api = _Api()
        ..onPost = () => _json(
          null,
          422,
          errors: {
            'message': 'Data tidak valid.',
            'details': {
              'file': ['Berkas gagal diunggah. Ukuran maksimal 10 MB.'],
            },
          },
        );
      await _pump(
        tester,
        RppFormScreen(
          service: api.service,
          onUnauthorized: () {},
          week: _open(),
          maxBytes: 1024,
          picker: _Picker(const PickedAttachment(name: 'rpp-a.pdf', bytes: [1])),
        ),
      );
      await tester.tap(find.text('Pilih berkas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim RPP'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Berkas gagal diunggah'), findsOneWidget);
      expect(find.byType(RppFormScreen), findsOneWidget);
    });

    testWidgets('an approved week cannot be edited', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        RppFormScreen(
          service: api.service,
          onUnauthorized: () {},
          week: RppWeek.fromJson(
            _week(
              '2026-10-26',
              '2026-11-01',
              state: 'approved',
              id: 3,
              title: 'RPP',
              canSubmit: false,
            ),
          ),
          maxBytes: 1024,
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('sudah disetujui'), findsOneWidget);
    });
  });
}
