import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/screens/changelog_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/update_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

import 'support/fake_updater.dart';

const _newer = UpdateInfo(
  updateAvailable: true,
  isMandatory: false,
  latestVersionCode: 3,
  latestVersionName: '1.2.0',
  releaseNotes: 'Presensi per sesi dan perbaikan nilai.',
  downloadUrl: 'https://example.test/api/v1/app/download/9',
);

Future<void> _pump(WidgetTester tester, FakeUpdater updater) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: ChangelogScreen(updater: updater),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the installed version and that the app is up to date',
      (tester) async {
    final updater = FakeUpdater(
      installed: const InstalledVersion(name: '1.2.0', code: 3),
      info: const UpdateInfo(
          updateAvailable: false,
          isMandatory: false,
          latestVersionCode: 3,
          latestVersionName: '1.2.0'),
    );
    await _pump(tester, updater);

    expect(find.text('SekolahOS Guru'), findsOneWidget);
    expect(find.text('Versi 1.2.0 (build 3)'), findsOneWidget);
    expect(find.text('Aplikasi sudah versi terbaru'), findsOneWidget);
    expect(find.text('Unduh & pasang'), findsNothing);
  });

  testWidgets('before any release exists it says so instead of looking broken',
      (tester) async {
    await _pump(tester, FakeUpdater()); // latest_version_name == null

    expect(find.text('Belum ada catatan rilis'), findsOneWidget);
  });

  testWidgets('a newer release shows its version, notes and an install button',
      (tester) async {
    final updater = FakeUpdater(info: _newer);
    await _pump(tester, updater);

    expect(find.text('Pembaruan tersedia'), findsOneWidget);
    expect(find.text('Versi 1.2.0 (build 3)'), findsOneWidget);
    expect(find.text('Yang baru'), findsOneWidget);
    expect(find.text('Presensi per sesi dan perbaikan nilai.'), findsOneWidget);
    expect(find.text('Pembaruan wajib. Versi lama tidak lagi didukung.'), findsNothing);
  });

  testWidgets('a mandatory release is flagged as such', (tester) async {
    await _pump(
      tester,
      FakeUpdater(
        info: const UpdateInfo(
          updateAvailable: true,
          isMandatory: true,
          latestVersionCode: 4,
          latestVersionName: '2.0.0',
          downloadUrl: 'https://example.test/d',
        ),
      ),
    );

    expect(find.text('Pembaruan wajib. Versi lama tidak lagi didukung.'), findsOneWidget);
  });

  testWidgets('install shows download progress, then hands the release to the installer',
      (tester) async {
    final updater = FakeUpdater(info: _newer)..holdDownload = Completer<void>();
    await _pump(tester, updater);

    await tester.tap(find.text('Unduh & pasang'));
    await tester.pump();

    expect(updater.installs.single.latestVersionName, '1.2.0');
    expect(find.text('Mengunduh… 40%'), findsOneWidget);
    expect(find.text('Unduh & pasang'), findsNothing, reason: 'no second tap while downloading');

    updater.holdDownload!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Unduh & pasang'), findsOneWidget);
  });

  testWidgets('a failed download shows the reason and allows another try', (tester) async {
    final updater = FakeUpdater(info: _newer)
      ..installError = ApiException('Gagal mengunduh pembaruan (status 404).');
    await _pump(tester, updater);

    await tester.tap(find.text('Unduh & pasang'));
    await tester.pumpAndSettle();

    expect(find.text('Gagal mengunduh pembaruan (status 404).'), findsOneWidget);
    expect(find.text('Unduh & pasang'), findsOneWidget);
  });

  testWidgets('an offline check can be retried', (tester) async {
    final updater = FakeUpdater(info: _newer)..error = StateError('offline');
    await _pump(tester, updater);

    expect(find.text('Gagal memeriksa pembaruan'), findsOneWidget);
    expect(find.textContaining('Periksa koneksi'), findsOneWidget);

    updater.error = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(updater.checks, 2);
    expect(find.text('Pembaruan tersedia'), findsOneWidget);
  });

  group('HttpAppUpdater', () {
    test('asks the teacher channel with the installed build number', () async {
      Uri? seen;
      final client = ApiClient(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(
              jsonEncode({
                'data': {
                  'app': 'teacher',
                  'update_available': true,
                  'is_mandatory': false,
                  'latest_version_code': 5,
                  'latest_version_name': '1.4.0',
                  'release_notes': 'Catatan',
                  'download_url': 'https://example.test/d/1',
                },
                'meta': {},
                'errors': null,
              }),
              200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final updater = HttpAppUpdater(
        client: client,
        installed: () async => const InstalledVersion(name: '1.3.0', code: 4),
      );

      final info = await updater.check();

      expect(seen!.path, endsWith('/v1/app/version'));
      expect(seen!.queryParameters, {
        'app': 'teacher',
        'platform': 'android',
        'current_version_code': '4',
      });
      expect(info.updateAvailable, isTrue);
      expect(info.latestVersionName, '1.4.0');
      expect(info.downloadUrl, 'https://example.test/d/1');
    });

    test('a server error surfaces as an ApiException with its message', () async {
      final client = ApiClient(
        client: MockClient((_) async => http.Response(
            jsonEncode({'data': null, 'meta': {}, 'errors': {'message': 'Aplikasi tidak dikenal.'}}),
            422,
            headers: {'content-type': 'application/json'})),
      );
      final updater = HttpAppUpdater(
        client: client,
        installed: () async => const InstalledVersion(name: '1.0.0', code: 1),
      );

      await expectLater(
          updater.check(), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Aplikasi tidak dikenal.')));
    });
  });
}
