import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/screens/account_screen.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

import 'support/fake_updater.dart';

AuthenticatedTeacher _t(String name, {String? nip, bool homeroom = false}) =>
    AuthenticatedTeacher(id: 1, name: name, nip: nip, isHomeroom: homeroom);

void main() {
  group('initials', () {
    test('skip degrees and use the first two name words', () {
      expect(_t('Anggi Gusela S.Pd. M.Ag.').initials, 'AG');
      expect(_t('Ahmad Fulan, S.Pd.').initials, 'AF');
    });

    test('a single name word gives its first two letters', () {
      expect(_t('Farhahd S.Si., M.Pd.').initials, 'FA'); // as in the design
      expect(_t('Ali').initials, 'AL');
    });

    test('empty name gives a placeholder', () {
      expect(_t('').initials, '?');
    });
  });

  Future<List<String>> pump(
    WidgetTester tester, {
    AuthenticatedTeacher? teacher,
    String? year = '2026/2027',
    Future<void> Function()? onLogout,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final log = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: AccountScreen(
          teacher: teacher ?? _t('Farhahd S.Si., M.Pd.', nip: 'T14052'),
          academicYear: ValueNotifier<String?>(year),
          onLogout: onLogout ?? () async => log.add('logout'),
          updater: FakeUpdater(),
          now: DateTime(2026, 10, 31),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return log;
  }

  testWidgets('profile card and rows follow the design', (tester) async {
    await pump(tester);

    expect(find.text('Akun'), findsOneWidget);
    expect(find.text('FA'), findsOneWidget);
    expect(find.text('Farhahd S.Si., M.Pd.'), findsOneWidget);
    expect(find.text('Guru Mapel · T14052'), findsOneWidget);
    expect(find.text('TA 2026/2027 · Periode Oktober 2026'), findsOneWidget);

    for (final (label, sub) in [
      ('Pengaturan profil', 'Data diri, foto, kata sandi'),
      ('Data kepegawaian', 'Data & dokumen pegawai'),
      ('Ganti mode workspace', 'Saat ini: Guru Mapel'),
      ('Log perubahan', 'Versi aplikasi & pembaruan'),
      ('Keluar', 'Akhiri sesi di perangkat ini'),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(find.text(sub), findsOneWidget, reason: sub);
    }
    // Rekap kehadiran lives under Semua menu, not here.
    expect(find.text('Rekap kehadiran'), findsNothing);
  });

  testWidgets('a homeroom teacher is shown as Wali Kelas; the TA line waits for data',
      (tester) async {
    await pump(tester,
        teacher: _t('Anggi Gusela S.Pd. M.Ag.', nip: '198500000005', homeroom: true),
        year: null);

    expect(find.text('Wali Kelas · 198500000005'), findsOneWidget);
    expect(find.text('Saat ini: Wali Kelas'), findsOneWidget);
    expect(find.textContaining('TA '), findsNothing);
  });

  testWidgets('settings rows that are not built say so', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pengaturan profil'));
    await tester.pump();
    expect(find.text('Pengaturan profil akan segera hadir'), findsOneWidget);
  });

  testWidgets('Keluar asks first: Batal keeps the session, Keluar ends it',
      (tester) async {
    final log = await pump(tester);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(log, isEmpty);

    await tester.tap(find.text('Keluar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();
    expect(log, ['logout']);
  });

  testWidgets('Log perubahan opens the version screen', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Log perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('Asatidz PPI 50'), findsOneWidget);
    expect(find.text('Versi 1.0.0 (build 1)'), findsOneWidget);
  });
}
