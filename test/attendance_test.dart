import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/screens/attendance_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/teacher_service.dart';
import 'package:mobile_sekolah_os/widgets/date_format.dart';

http.Response _json(Object data) => http.Response(
    jsonEncode({'data': data, 'meta': [], 'errors': null}), 200,
    headers: {'content-type': 'application/json'});

Map<String, dynamic> _month(String month, List<Map<String, dynamic>> days) => {
      'month': month,
      'summary': {
        'present': days.where((d) => d['status'] == 'present').length,
        'late': days.where((d) => d['status'] == 'late').length,
        'absent': 0,
        'excused': 0,
        'sick': 0,
        'permission': 0,
        'total': days.length,
      },
      'days': days,
    };

void main() {
  test('AttendanceMonth parses summary and days', () {
    final m = AttendanceMonth.fromJson(_month('2026-10', [
      {
        'date': '2026-10-05',
        'day_name': 'Senin',
        'status': 'present',
        'status_label': 'Hadir',
        'check_in': '06:55',
        'check_out': '15:00',
        'notes': null,
      },
    ]));
    expect(m.count('present'), 1);
    expect(m.count('absent'), 0);
    expect(m.summary['total'], 1);
    expect(m.days.single.checkIn, '06:55');
    expect(formatMonth('2026-10'), 'Oktober 2026');
  });

  testWidgets('shows summary and days, navigates months, caps at this month',
      (tester) async {
    final requested = <String?>[];
    final client = ApiClient(
      client: MockClient((req) async {
        final month = req.url.queryParameters['month'];
        requested.add(month);
        if (month == '2026-10') {
          return _json(_month('2026-10', [
            {
              'date': '2026-10-06',
              'day_name': 'Selasa',
              'status': 'late',
              'status_label': 'Terlambat',
              'check_in': '07:40',
              'check_out': null,
              'notes': null,
            },
            {
              'date': '2026-10-05',
              'day_name': 'Senin',
              'status': 'present',
              'status_label': 'Hadir',
              'check_in': '06:55',
              'check_out': '15:00',
              'notes': null,
            },
          ]));
        }
        return _json(_month(month!, []));
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: AttendanceScreen(
        service: TeacherService(client),
        onUnauthorized: () {},
        now: DateTime(2026, 10, 31),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text('Hadir 1'), findsOneWidget);
    expect(find.text('Terlambat 1'), findsOneWidget);
    expect(find.text('Masuk 06:55 · Keluar 15:00'), findsOneWidget);
    expect(find.text('Masuk 07:40'), findsOneWidget);

    // Next month is disabled while viewing the current month.
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right))
            .onPressed,
        isNull);

    // Previous month: empty state, and the right month is requested.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.textContaining('Belum ada data kehadiran'), findsOneWidget);
    expect(requested, ['2026-10', '2026-09']);
  });
}
