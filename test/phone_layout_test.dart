import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/screens/facility_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/incident_detail_screen.dart';
import 'package:mobile_sekolah_os/screens/vehicle_detail_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/theme/app_theme.dart';

/// Real handsets are about 360 dp wide, and people run the text a little larger.
/// Two buttons share a bottom bar on the detail screens: neither label may break.
TeacherService _service(Map<String, dynamic> detail) => TeacherService(
  ApiClient(
    client: MockClient(
      (req) async => http.Response(
        jsonEncode({'data': detail, 'meta': {}, 'errors': null}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  ),
);

Future<void> _phone(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.15)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// The bottom bar's two buttons: each label as tall as a single line of text.
void _expectOneLine(WidgetTester tester, List<String> labels) {
  final oneLine = tester.getSize(find.text(labels.last)).height;
  for (final label in labels) {
    expect(
      tester.getSize(find.text(label)).height,
      oneLine,
      reason: '"$label" wrapped',
    );
  }
}

void main() {
  testWidgets('Sarpras detail: Batalkan laporan / Ubah stay on one line', (
    tester,
  ) async {
    await _phone(
      tester,
      FacilityDetailScreen(
        service: _service({
          'id': 5,
          'category': 'listrik',
          'category_label': 'Listrik',
          'priority': 'sedang',
          'priority_label': 'Sedang',
          'location': 'Kelas 8A',
          'status': 'reported',
          'status_label': 'Dilaporkan',
          'can_edit': true,
          'created_at': '2026-11-01 08:30',
          'description': 'Lampu belakang kelas mati.',
        }),
        onUnauthorized: () {},
        id: 5,
      ),
    );

    _expectOneLine(tester, ['Batalkan laporan', 'Ubah']);
  });

  testWidgets('Kejadian detail: Batalkan laporan / Ubah stay on one line', (
    tester,
  ) async {
    await _phone(
      tester,
      IncidentDetailScreen(
        service: _service({
          'id': 3,
          'category': 'discipline',
          'category_label': 'Pelanggaran',
          'severity': 'sedang',
          'severity_label': 'Sedang',
          'occurred_at': '2026-11-01 08:30',
          'status': 'reported',
          'status_label': 'Dilaporkan',
          'can_edit': true,
          'students': [
            {'id': 1, 'name': 'Ahmad Fauzi', 'grade_name': '8A'},
          ],
          'location': 'Kantin',
          'description': 'Dua siswa berkelahi di kantin.',
        }),
        onUnauthorized: () {},
        id: 3,
      ),
    );

    _expectOneLine(tester, ['Batalkan laporan', 'Ubah']);
  });

  testWidgets('Kendaraan detail: Batalkan pengajuan / Ubah stay on one line', (
    tester,
  ) async {
    await _phone(
      tester,
      VehicleDetailScreen(
        service: _service({
          'id': 7,
          'purpose': 'Study tour',
          'destination': 'Museum Geologi',
          'start_at': '2026-11-10 07:00',
          'end_at': '2026-11-10 15:00',
          'passenger_count': 25,
          'status': 'pending',
          'status_label': 'Menunggu',
          'can_edit': true,
          'can_cancel': true,
          'vehicle': null,
          'driver_name': null,
          'public_note': null,
        }),
        onUnauthorized: () {},
        id: 7,
      ),
    );

    _expectOneLine(tester, ['Batalkan pengajuan', 'Ubah']);
  });
}
