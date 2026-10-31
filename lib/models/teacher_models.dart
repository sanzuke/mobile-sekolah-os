// Mirrors the `/api/v1/teacher/home` and `/schedule` payloads
// (`HomeController`, `ScheduleController` in admin-siakad).

class Lesson {
  const Lesson({
    required this.sessionNumber,
    required this.start,
    required this.end,
    required this.subject,
    required this.classes,
    this.room,
    required this.status,
  });

  final int sessionNumber;
  final String start;
  final String end;
  final String subject;
  final String classes;
  final String? room;

  /// done | current | next | upcoming
  final String status;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        sessionNumber: j['session_number'] as int? ?? 0,
        start: j['start'] as String? ?? '',
        end: j['end'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        classes: j['classes'] as String? ?? '',
        room: j['room'] as String?,
        status: j['status'] as String? ?? 'upcoming',
      );

  String get timeRange => '$start – $end';
}

class WeekInfo {
  const WeekInfo({
    this.number,
    required this.total,
    required this.start,
    required this.end,
    required this.sessionsPerWeek,
  });

  /// null when the date is outside the semester.
  final int? number;
  final int total;
  final String start;
  final String end;
  final int sessionsPerWeek;

  factory WeekInfo.fromJson(Map<String, dynamic> j) => WeekInfo(
        number: j['number'] as int?,
        total: j['total'] as int? ?? 0,
        start: j['start'] as String? ?? '',
        end: j['end'] as String? ?? '',
        sessionsPerWeek: j['sessions_per_week'] as int? ?? 0,
      );
}

class AgendaItem {
  const AgendaItem({
    required this.title,
    required this.typeLabel,
    this.startTime,
    this.location,
  });

  final String title;
  final String typeLabel;
  final String? startTime;
  final String? location;

  factory AgendaItem.fromJson(Map<String, dynamic> j) => AgendaItem(
        title: j['title'] as String? ?? '',
        typeLabel: j['type_label'] as String? ?? '',
        startTime: j['start_time'] as String?,
        location: j['location'] as String?,
      );
}

class Announcement {
  const Announcement({required this.title, this.excerpt, this.publishedAt});

  final String title;
  final String? excerpt;
  final DateTime? publishedAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        title: j['title'] as String? ?? '',
        excerpt: j['excerpt'] as String?,
        publishedAt: DateTime.tryParse(j['published_at'] as String? ?? ''),
      );
}

class HomeData {
  const HomeData({
    required this.date,
    required this.dayName,
    this.semesterName,
    this.week,
    required this.todayState,
    required this.draftCount,
    required this.lessons,
    this.nextLesson,
    required this.agenda,
    required this.announcements,
  });

  final String date;
  final String? dayName;
  final String? semesterName;
  final WeekInfo? week;

  /// ok | holiday | unpublished | none | no_lessons
  final String todayState;
  final int draftCount;
  final List<Lesson> lessons;
  final Lesson? nextLesson;
  final List<AgendaItem> agenda;
  final List<Announcement> announcements;

  factory HomeData.fromJson(Map<String, dynamic> j) {
    final today = j['today'] as Map<String, dynamic>? ?? {};
    final semester = j['semester'] as Map<String, dynamic>?;
    final week = j['week'] as Map<String, dynamic>?;
    final next = j['next_lesson'] as Map<String, dynamic>?;
    return HomeData(
      date: j['date'] as String? ?? '',
      dayName: j['day_name'] as String?,
      semesterName: semester == null
          ? null
          : '${semester['name'] ?? ''} ${semester['year'] ?? ''}'.trim(),
      week: week == null ? null : WeekInfo.fromJson(week),
      todayState: today['state'] as String? ?? 'none',
      draftCount: today['draft_count'] as int? ?? 0,
      lessons: _list(today['lessons'], Lesson.fromJson),
      nextLesson: next == null ? null : Lesson.fromJson(next),
      agenda: _list(j['agenda'], AgendaItem.fromJson),
      announcements: _list(j['announcements'], Announcement.fromJson),
    );
  }
}

class ScheduleDay {
  const ScheduleDay({
    required this.day,
    required this.name,
    required this.date,
    required this.isToday,
    required this.state,
    required this.lessons,
  });

  final int day;
  final String name;
  final String date;
  final bool isToday;
  final String state;
  final List<Lesson> lessons;

  factory ScheduleDay.fromJson(Map<String, dynamic> j) => ScheduleDay(
        day: j['day'] as int? ?? 0,
        name: j['name'] as String? ?? '',
        date: j['date'] as String? ?? '',
        isToday: j['is_today'] as bool? ?? false,
        state: j['state'] as String? ?? 'ok',
        lessons: _list(j['lessons'], Lesson.fromJson),
      );
}

class ScheduleData {
  const ScheduleData({this.week, required this.days});

  final WeekInfo? week;
  final List<ScheduleDay> days;

  factory ScheduleData.fromJson(Map<String, dynamic> j) {
    final week = j['week'] as Map<String, dynamic>?;
    return ScheduleData(
      week: week == null ? null : WeekInfo.fromJson(week),
      days: _list(j['days'], ScheduleDay.fromJson),
    );
  }
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) =>
    (raw as List<dynamic>? ?? const [])
        .map((e) => parse(e as Map<String, dynamic>))
        .toList();
