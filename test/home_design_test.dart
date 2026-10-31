import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/app_shell.dart';
import 'package:mobile_sekolah_os/widgets/surface_cards.dart' show agendaColors;
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/state/session_controller.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _home({
  Map<String, dynamic>? next,
  int unread = 0,
  dynamic duty,
  List<Map<String, dynamic>> agenda = const [],
  List<Map<String, dynamic>> announcements = const [],
}) =>
    {
      'date': '2026-10-31',
      'day_name': 'Sabtu',
      'semester': {'id': 1, 'name': 'Semester 1', 'year': '2026/2027'},
      'week': {
        'number': 16,
        'total': 25,
        'start': '2026-10-26',
        'end': '2026-11-01',
        'sessions_per_week': 34,
      },
      'today': {
        'state': 'ok',
        'draft_count': 0,
        'lessons': next == null ? [] : [next],
      },
      'next_lesson': next,
      'agenda': agenda,
      'announcements': announcements,
      'unread_notifications': unread,
      'duties': {'attendance': duty},
    };

Future<ApiClient> _pumpShell(WidgetTester tester, Map<String, dynamic> home) async {
  tester.view.physicalSize = const Size(1080, 4800); // 360 x 1600 dp
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final client = ApiClient(
    client: MockClient((req) async {
      final path = req.url.path;
      Object body = <String, dynamic>{};
      Object meta = {};
      if (path.endsWith('/home')) {
        body = home;
      } else if (path.endsWith('/notifications') || path.endsWith('/announcements')) {
        body = <Object>[];
        // Beranda and the notification list read the same server-side count.
        meta = {'last_page': 1, 'unread_count': home['unread_notifications'] ?? 0};
      }
      return http.Response(
          jsonEncode({'data': body, 'meta': meta, 'errors': null}), 200,
          headers: {'content-type': 'application/json'});
    }),
  );
  final session = SessionController(AuthService(client: client))
    ..teacher = const AuthenticatedTeacher(
        id: 1, name: 'Farhahd S.Si., M.Pd.', isHomeroom: false);

  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: AppShell(session: session, service: TeacherService(client)),
  ));
  await tester.pumpAndSettle();
  return client;
}

void main() {
  testWidgets('Beranda follows the design: header, menu grid, weekly duties',
      (tester) async {
    await _pumpShell(
        tester, _home(duty: {'done': 5, 'total': 6, 'percent': 83}));

    expect(find.text('Farhahd S.Si., M.Pd.'), findsOneWidget);
    expect(find.textContaining('Guru Mapel'), findsOneWidget);
    expect(find.text('Cari menu, misal: presensi, RPP'), findsOneWidget);
    expect(find.text('Tidak ada jadwal mengajar hari ini'), findsOneWidget);
    expect(find.textContaining('Pekan ke-16 dari 25'), findsOneWidget);

    expect(find.text('Menu utama'), findsOneWidget);
    for (final label in [
      'Presensi',
      'Jadwal',
      'RPP',
      'Jurnal',
      'Tahfidz',
      'Agenda',
      'Rapat',
      'Semua',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'tile "$label"');
    }

    expect(find.text('Kewajiban pekan ini'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.text('5 dari 6 JP kelas sudah dicatat'), findsOneWidget);
    // RPP and Jurnal have no backend: "Segera", never an invented 0%.
    expect(find.text('Segera'), findsNWidgets(2));
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('bottom bar has four tabs and a center "+" (no Nilai tab)',
      (tester) async {
    await _pumpShell(tester, _home());

    for (final label in ['Beranda', 'Jadwal', 'Kotak masuk', 'Akun']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Nilai'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Aksi cepat'), findsOneWidget);
    expect(find.text('Ajukan izin / cuti'), findsOneWidget);
    expect(find.text('Input notulen'), findsOneWidget);

    await tester.tap(find.text('Pinjam kendaraan'));
    await tester.pumpAndSettle();
    expect(find.text('Pinjam kendaraan akan segera hadir'), findsOneWidget);
  });

  testWidgets('Semua menu lists groups, filters by search, opens Akademik',
      (tester) async {
    await _pumpShell(tester, _home());

    await tester.tap(find.text('Semua menu'));
    await tester.pumpAndSettle();
    for (final g in ['Mengajar', 'Kegiatan', 'Kepegawaian', 'Laporan']) {
      expect(find.text(g), findsOneWidget, reason: g);
    }
    expect(find.text('Akademik'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'jurnal');
    await tester.pumpAndSettle();
    expect(find.text('Jurnal Mengajar'), findsOneWidget);
    expect(find.text('Jadwal Pelajaran'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Menu tidak ditemukan. Coba kata lain.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'akademik');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akademik'));
    await tester.pumpAndSettle();
    expect(find.text('Akademik'), findsWidgets); // the Akademik page is open
    expect(find.text('Semua menu'), findsNothing);
  });

  testWidgets('a menu that is not built says so instead of doing nothing',
      (tester) async {
    await _pumpShell(tester, _home());

    await tester.tap(find.text('RPP').first);
    await tester.pump();
    expect(find.text('Kurikulum & RPP akan segera hadir'), findsOneWidget);
  });

  testWidgets('the bell opens Kotak masuk on Notifikasi and shows the unread dot',
      (tester) async {
    await _pumpShell(tester, _home(unread: 3));

    expect(find.byType(CircleAvatar), findsWidgets); // red dot on the bell
    await tester.tap(find.byIcon(Icons.notifications_none).first);
    await tester.pumpAndSettle();

    // Kotak masuk is open on Notifikasi (its empty state is on screen).
    expect(find.text('Belum ada notifikasi baru'), findsOneWidget);
  });

  testWidgets('with a lesson running, the card offers Input Presensi Siswa',
      (tester) async {
    await _pumpShell(
      tester,
      _home(next: {
        'session_number': 3,
        'start': '09:00',
        'end': '09:35',
        'subject': 'Musthalah Hadits',
        'classes': '8C',
        'room': null,
        'status': 'current',
      }),
    );

    expect(find.textContaining('Sedang berlangsung'), findsOneWidget);
    expect(find.textContaining('JP 3 · Musthalah Hadits'), findsOneWidget);
    expect(find.text('Input Presensi Siswa'), findsOneWidget);
  });

  testWidgets('agenda and announcements are cards with a type chip and a preview',
      (tester) async {
    await _pumpShell(
      tester,
      _home(
        agenda: [
          {
            'id': 1,
            'title': 'Ujian - NH — Nilai Harian 2 (Ganjil 2026/2027)',
            'type': 'exam',
            'type_label': 'Ujian',
            'start_time': null,
            'end_time': null,
            'is_all_day': true,
            'location': null,
          },
          {
            'id': 2,
            'title': 'Rapat Dewan Guru',
            'type': 'academic',
            'type_label': 'Kegiatan Akademik',
            'start_time': '08:00',
            'end_time': '10:30',
            'is_all_day': false,
            'location': 'Aula',
          },
        ],
        announcements: [
          {
            'id': 9,
            'title': 'Pendaftaran Santri Baru Gelombang 2',
            'excerpt': 'Pendaftaran gelombang kedua dibuka sampai Januari.',
            'category': 'Berita',
            'published_at': '2026-09-27T23:09:32+00:00',
          },
        ],
      ),
    );

    // Same heading style and a "Lihat semua" link for each section.
    expect(find.text('Agenda hari ini'), findsOneWidget);
    expect(find.text('Pengumuman'), findsOneWidget);
    expect(find.text('Lihat semua'), findsNWidgets(2));

    // Agenda: title, the type chip, and time + place when it has them.
    expect(find.text('Ujian - NH — Nilai Harian 2 (Ganjil 2026/2027)'), findsOneWidget);
    expect(find.text('Ujian'), findsOneWidget);
    expect(find.text('Kegiatan Akademik'), findsOneWidget);
    expect(find.text('08:00 – 10:30 · Aula'), findsOneWidget);

    // Announcement: category chip, title and the text preview.
    expect(find.text('Berita'), findsOneWidget);
    expect(find.text('Pendaftaran Santri Baru Gelombang 2'), findsOneWidget);
    expect(find.text('Pendaftaran gelombang kedua dibuka sampai Januari.'), findsOneWidget);
  });

  testWidgets('empty agenda and announcements show a friendly note, not nothing',
      (tester) async {
    await _pumpShell(tester, _home());

    expect(find.text('Tidak ada agenda hari ini.'), findsOneWidget);
    expect(find.text('Belum ada pengumuman.'), findsOneWidget);
  });

  testWidgets('the center "+" is solid accent with a white glyph', (tester) async {
    await _pumpShell(tester, _home());

    final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    final scheme = buildTheme().colorScheme;
    expect(fab.backgroundColor, scheme.primary);
    expect(fab.foregroundColor, scheme.onPrimary);
  });

  testWidgets('an excerpt that just repeats the title is not shown twice',
      (tester) async {
    await _pumpShell(
      tester,
      _home(announcements: [
        {
          'id': 3,
          'title': 'Pendaftaran Santri Baru Gelombang 2',
          'excerpt': 'pendaftaran santri baru gelombang 2',
          'category': null,
          'published_at': '2025-11-13T01:00:00+00:00',
        },
      ]),
    );

    expect(find.text('Pendaftaran Santri Baru Gelombang 2'), findsOneWidget);
    expect(find.text('pendaftaran santri baru gelombang 2'), findsNothing);
  });

  test('agenda colours: exam amber, holiday red, academic teal, others slate', () {
    expect(agendaColors('exam').bar, const Color(0xFFD97706));
    expect(agendaColors('holiday').bar, const Color(0xFFDC2626));
    expect(agendaColors('academic').bar, const Color(0xFF0F766E));
    expect(agendaColors('whatever').bar, const Color(0xFF64748B));
  });

  test('HomeData reads duties.attendance, tolerating its absence', () {
    final base = _home();
    expect(HomeData.fromJson(base).attendanceDuty, isNull);
    final d = HomeData.fromJson(_home(duty: {'done': 1, 'total': 2, 'percent': 50}));
    expect(d.attendanceDuty!.percent, 50);
    expect(d.attendanceDuty!.total, 2);
  });
}
