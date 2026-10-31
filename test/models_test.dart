import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/models/teacher_models.dart';
import 'package:mobile_sekolah_os/widgets/date_format.dart';

void main() {
  test('HomeData parses the /home payload', () {
    final data = HomeData.fromJson({
      'date': '2026-10-31',
      'day_name': 'Sabtu',
      'semester': {'id': 1, 'name': 'Semester 1', 'year': '2026/2027'},
      'week': {
        'number': 16,
        'total': 23,
        'start': '2026-10-26',
        'end': '2026-11-01',
        'sessions_per_week': 12,
      },
      'today': {
        'state': 'ok',
        'draft_count': 0,
        'lessons': [
          {
            'session_number': 1,
            'start': '07:00',
            'end': '08:20',
            'subject': 'Fiqih',
            'classes': '8A + 8B',
            'room': null,
            'status': 'current',
          }
        ],
      },
      'next_lesson': {
        'session_number': 1,
        'start': '07:00',
        'end': '08:20',
        'subject': 'Fiqih',
        'classes': '8A + 8B',
        'status': 'current',
      },
      'agenda': [
        {'title': 'Rapat', 'type_label': 'Kegiatan Akademik', 'start_time': null}
      ],
      'announcements': [
        {'title': 'Libur', 'excerpt': null, 'published_at': '2026-10-30T01:00:00+00:00'}
      ],
    });

    expect(data.week!.number, 16);
    expect(data.lessons.single.timeRange, '07:00 – 08:20');
    expect(data.nextLesson!.status, 'current');
    expect(data.semesterName, 'Semester 1 2026/2027');
    expect(data.announcements.single.publishedAt, isNotNull);
  });

  test('HomeData tolerates no active semester', () {
    final data = HomeData.fromJson({
      'date': '2026-10-31',
      'semester': null,
      'week': null,
      'today': {'state': 'none', 'draft_count': 0, 'lessons': []},
      'next_lesson': null,
      'agenda': [],
      'announcements': [],
    });

    expect(data.week, isNull);
    expect(data.lessons, isEmpty);
    expect(data.todayState, 'none');
  });

  test('date formatting is Indonesian', () {
    expect(formatDate('2026-10-31'), '31 Okt 2026');
    expect(formatRange('2026-10-26', '2026-11-01'), '26 Okt – 1 Nov 2026');
  });
}
