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

  test('AgendaItem parses the /agenda payload and builds a time range', () {
    final timed = AgendaItem.fromJson({
      'id': 7,
      'title': 'Rapat',
      'description': null,
      'type_label': 'Kegiatan Akademik',
      'start_date': '2026-11-08',
      'end_date': '2026-11-12',
      'start_time': '08:00',
      'end_time': '10:30',
      'is_all_day': false,
      'location': 'Aula',
    });
    expect(timed.timeRange, '08:00 – 10:30');
    expect(timed.endDate, '2026-11-12');

    final allDay = AgendaItem.fromJson({
      'title': 'Ujian',
      'type_label': 'Ujian',
      'is_all_day': true,
      'start_time': null,
    });
    expect(allDay.timeRange, isNull);
    expect(allDay.id, 0);
  });

  test('Announcement and detail parse list and show payloads', () {
    final detail = AnnouncementDetail.fromJson({
      'id': 21,
      'title': 'Du\'at Camp',
      'excerpt': null,
      'category': 'Kegiatan',
      'image_url': null,
      'published_at': '2026-09-27T23:09:32+00:00',
      'content_html': '<p>Isi</p>',
      'content_text': 'Isi',
    });
    expect(detail.summary.id, 21);
    expect(detail.summary.category, 'Kegiatan');
    expect(detail.summary.publishedAt, isNotNull);
    expect(detail.text, 'Isi');
  });

  test('NotificationItem parses and marks read without mutating', () {
    final n = NotificationItem.fromJson({
      'id': '3f1c9a52-0000-0000-0000-000000000000',
      'title': 'Izin disetujui',
      'body': 'Izin 3 Nov disetujui.',
      'is_read': false,
      'created_at': '2026-10-31T09:00:00+00:00',
    });
    expect(n.isRead, isFalse);
    expect(n.asRead().isRead, isTrue);
    expect(n.isRead, isFalse);
    expect(n.createdAt, isNotNull);
  });

  test('HomeData carries unread_notifications, defaulting to 0', () {
    final base = {
      'date': '2026-10-31',
      'today': {'state': 'none', 'draft_count': 0, 'lessons': []},
      'agenda': [],
      'announcements': [],
    };
    expect(HomeData.fromJson(base).unreadNotifications, 0);
    expect(HomeData.fromJson({...base, 'unread_notifications': 4}).unreadNotifications, 4);
  });
}
