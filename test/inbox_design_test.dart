import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/screens/inbox_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

Map<String, dynamic> _ann(int id, String title, {String? excerpt, String? category}) => {
      'id': id,
      'title': title,
      'excerpt': excerpt,
      'category': category,
      'image_url': null,
      'published_at': '2026-09-27T23:09:32+00:00',
    };

Future<List<String>> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>> announcements = const [],
  List<Map<String, dynamic>> notifications = const [],
  int unread = 0,
  ValueNotifier<int>? unreadNotifier,
  ValueNotifier<int>? segmentRequest,
}) async {
  // Wide enough for the test font (Ahem is far wider than the real font).
  tester.view.physicalSize = const Size(1440, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final calls = <String>[];
  final client = ApiClient(
    client: MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      final path = req.url.path;
      Object data = <String, dynamic>{};
      Object meta = {};
      if (path.endsWith('/announcements')) {
        data = announcements;
        meta = {'last_page': 1};
      } else if (path.endsWith('/notifications')) {
        data = notifications;
        meta = {'last_page': 1, 'unread_count': unread};
      }
      return http.Response(
          jsonEncode({'data': data, 'meta': meta, 'errors': null}), 200,
          headers: {'content-type': 'application/json'});
    }),
  );

  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: SafeArea(
        child: InboxScreen(
          service: TeacherService(client),
          unread: unreadNotifier ?? ValueNotifier<int>(unread),
          onUnauthorized: () {},
          segmentRequest: segmentRequest,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('title, three segments (no Agenda), and announcement cards',
      (tester) async {
    await _pump(tester, announcements: [
      _ann(1, 'Libur Maulid Nabi',
          excerpt: 'Kegiatan belajar diliburkan pada 3 November.', category: 'Berita'),
      _ann(2, 'Rapat Dewan Guru'),
    ]);

    expect(find.text('Kotak masuk'), findsOneWidget);
    for (final label in ['Pengumuman', 'Notifikasi', 'Laporan']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Agenda'), findsNothing);

    expect(find.text('Libur Maulid Nabi'), findsOneWidget);
    expect(find.text('Berita'), findsOneWidget);
    expect(find.text('Kegiatan belajar diliburkan pada 3 November.'), findsOneWidget);
    expect(find.text('Rapat Dewan Guru'), findsOneWidget);
  });

  testWidgets('empty announcements say so instead of showing a blank page',
      (tester) async {
    await _pump(tester);

    expect(find.text('Belum ada pengumuman'), findsOneWidget);
  });

  testWidgets('Notifikasi: unread badge, unread card, tap marks it read',
      (tester) async {
    final unread = ValueNotifier<int>(0);
    final calls = await _pump(
      tester,
      unread: 1,
      unreadNotifier: unread,
      notifications: [
        {
          'id': '3f1c9a52-0000-0000-0000-000000000000',
          'title': 'Izin disetujui',
          'body': 'Izin 3 Nov disetujui kepala sekolah.',
          'is_read': false,
          'created_at': '2026-10-31T09:00:00+00:00',
        },
      ],
    );

    await tester.tap(find.byKey(const ValueKey('inbox-segment-1')));
    await tester.pumpAndSettle();

    expect(find.text('Izin disetujui'), findsOneWidget);
    expect(find.text('Izin 3 Nov disetujui kepala sekolah.'), findsOneWidget);
    expect(unread.value, 1);
    expect(find.text('1'), findsOneWidget); // the badge on the Notifikasi pill

    await tester.tap(find.text('Izin disetujui'));
    await tester.pumpAndSettle();

    expect(unread.value, 0);
    expect(find.text('1'), findsNothing);
    expect(calls, contains('POST /api/v1/teacher/notifications/3f1c9a52-0000-0000-0000-000000000000/read'));
  });

  testWidgets('Notifikasi empty state uses the design wording', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('inbox-segment-1')));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada notifikasi baru'), findsOneWidget);
    expect(find.text('Persetujuan izin, tugas, dan undangan rapat akan muncul di sini.'),
        findsOneWidget);
  });

  testWidgets('Laporan is an honest empty state with a "coming soon" action',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('inbox-segment-2')));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada laporan'), findsOneWidget);
    expect(find.textContaining('beserta status dan balasan staf'), findsOneWidget);

    await tester.tap(find.text('Buat laporan'));
    await tester.pump();
    expect(find.text('Buat laporan akan segera hadir'), findsOneWidget);
  });

  testWidgets('a big unread count is shown as 9+ on the Notifikasi pill',
      (tester) async {
    await _pump(tester, unread: 12);

    await tester.tap(find.byKey(const ValueKey('inbox-segment-1')));
    await tester.pumpAndSettle();

    expect(find.text('9+'), findsOneWidget);
    expect(find.text('12'), findsNothing);
  });

  testWidgets('another screen can open a given segment, repeatedly', (tester) async {
    final request = ValueNotifier<int>(-1);
    await _pump(tester, segmentRequest: request);

    request.value = 2; // Laporan
    await tester.pumpAndSettle();
    expect(find.text('Belum ada laporan'), findsOneWidget);
    expect(request.value, -1, reason: 'the request is consumed');

    request.value = 0; // back to Pengumuman
    await tester.pumpAndSettle();
    expect(find.text('Belum ada pengumuman'), findsOneWidget);

    request.value = 2; // the same segment again still works
    await tester.pumpAndSettle();
    expect(find.text('Belum ada laporan'), findsOneWidget);
  });
}
