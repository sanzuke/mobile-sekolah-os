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
    this.id = 0,
    required this.title,
    this.description,
    this.type = '',
    required this.typeLabel,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.isAllDay = true,
    this.location,
  });

  final int id;
  final String title;
  final String? description;

  /// Machine value of the event type (academic, exam, holiday, ...), for colouring.
  final String type;
  final String typeLabel;

  /// `YYYY-MM-DD`; null in older payloads (`/home` before agenda endpoint).
  final String? startDate;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final bool isAllDay;
  final String? location;

  factory AgendaItem.fromJson(Map<String, dynamic> j) => AgendaItem(
        id: j['id'] as int? ?? 0,
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        type: j['type'] as String? ?? '',
        typeLabel: j['type_label'] as String? ?? '',
        startDate: j['start_date'] as String?,
        endDate: j['end_date'] as String?,
        startTime: j['start_time'] as String?,
        endTime: j['end_time'] as String?,
        isAllDay: j['is_all_day'] as bool? ?? true,
        location: j['location'] as String?,
      );

  /// `08:00 – 10:30`, `08:00`, or null for all-day events.
  String? get timeRange {
    if (isAllDay || startTime == null) return null;
    return endTime == null ? startTime : '$startTime – $endTime';
  }
}

class Announcement {
  const Announcement({
    this.id = 0,
    required this.title,
    this.excerpt,
    this.category,
    this.imageUrl,
    this.publishedAt,
  });

  final int id;
  final String title;
  final String? excerpt;
  final String? category;
  final String? imageUrl;
  final DateTime? publishedAt;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as int? ?? 0,
        title: j['title'] as String? ?? '',
        excerpt: j['excerpt'] as String?,
        category: j['category'] as String?,
        imageUrl: j['image_url'] as String?,
        publishedAt: DateTime.tryParse(j['published_at'] as String? ?? ''),
      );
}

class AnnouncementDetail {
  const AnnouncementDetail({required this.summary, required this.text});

  final Announcement summary;

  /// Plain text of the post body (`content_text`); HTML is not rendered yet.
  final String text;

  factory AnnouncementDetail.fromJson(Map<String, dynamic> j) =>
      AnnouncementDetail(
        summary: Announcement.fromJson(j),
        text: j['content_text'] as String? ?? '',
      );
}

class AnnouncementPage {
  const AnnouncementPage({required this.items, required this.lastPage});

  final List<Announcement> items;
  final int lastPage;
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    this.body,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime? createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );

  NotificationItem asRead() => NotificationItem(
        id: id,
        title: title,
        body: body,
        isRead: true,
        createdAt: createdAt,
      );
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.lastPage,
    required this.unreadCount,
  });

  final List<NotificationItem> items;
  final int lastPage;
  final int unreadCount;
}

/// Attendance part of "Kewajiban pekan ini": lessons already held this week vs recorded.
class WeekDuty {
  const WeekDuty({required this.done, required this.total, this.percent});

  final int done;
  final int total;

  /// null when no lesson has fallen due yet this week.
  final int? percent;

  factory WeekDuty.fromJson(Map<String, dynamic> j) => WeekDuty(
        done: (j['done'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        percent: (j['percent'] as num?)?.toInt(),
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
    this.unreadNotifications = 0,
    this.attendanceDuty,
  });

  final int unreadNotifications;
  final WeekDuty? attendanceDuty;
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
      unreadNotifications: j['unread_notifications'] as int? ?? 0,
      attendanceDuty: switch ((j['duties'] as Map<String, dynamic>?)?['attendance']) {
        final Map<String, dynamic> a => WeekDuty.fromJson(a),
        _ => null,
      },
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

// ---- Classes and grade entry (/classes, /classes/{g}/students, .../grades) ----

class SubjectInfo {
  const SubjectInfo({
    required this.id,
    required this.name,
    required this.path,
    this.kkm,
  });

  final int id;
  final String name;

  /// Parent chain, e.g. `Rumpun → Fiqih`.
  final String path;
  final double? kkm;

  factory SubjectInfo.fromJson(Map<String, dynamic> j) => SubjectInfo(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        path: j['path'] as String? ?? j['name'] as String? ?? '',
        kkm: (j['kkm'] as num?)?.toDouble(),
      );
}

class ClassInfo {
  const ClassInfo({
    required this.id,
    required this.name,
    required this.isHomeroom,
    required this.studentCount,
    required this.subjects,
  });

  final int id;
  final String name;
  final bool isHomeroom;
  final int studentCount;
  final List<SubjectInfo> subjects;

  factory ClassInfo.fromJson(Map<String, dynamic> j) => ClassInfo(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        isHomeroom: j['is_homeroom'] as bool? ?? false,
        studentCount: j['student_count'] as int? ?? 0,
        subjects: _list(j['subjects'], SubjectInfo.fromJson),
      );
}

class ExamPeriodInfo {
  const ExamPeriodInfo({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;

  factory ExamPeriodInfo.fromJson(Map<String, dynamic> j) => ExamPeriodInfo(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        startDate: DateTime.tryParse(j['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(j['end_date'] as String? ?? ''),
      );

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return startDate != null &&
        endDate != null &&
        !d.isBefore(startDate!) &&
        !d.isAfter(endDate!);
  }
}

class ClassesData {
  const ClassesData({
    this.semesterName,
    required this.classes,
    required this.examPeriods,
  });

  final String? semesterName;
  final List<ClassInfo> classes;
  final List<ExamPeriodInfo> examPeriods;

  factory ClassesData.fromJson(Map<String, dynamic> j) {
    final semester = j['semester'] as Map<String, dynamic>?;
    return ClassesData(
      semesterName: semester == null
          ? null
          : '${semester['name'] ?? ''} ${semester['year'] ?? ''}'.trim(),
      classes: _list(j['classes'], ClassInfo.fromJson),
      examPeriods: _list(j['exam_periods'], ExamPeriodInfo.fromJson),
    );
  }

  /// The period running today, else the latest one already started, else the first.
  ExamPeriodInfo? defaultPeriod(DateTime today) {
    if (examPeriods.isEmpty) return null;
    for (final p in examPeriods) {
      if (p.contains(today)) return p;
    }
    final started = examPeriods
        .where((p) => p.startDate != null && !p.startDate!.isAfter(today))
        .toList();
    return started.isNotEmpty ? started.last : examPeriods.first;
  }
}

class StudentInfo {
  const StudentInfo({required this.id, required this.name, this.nis});

  final int id;
  final String name;
  final String? nis;

  factory StudentInfo.fromJson(Map<String, dynamic> j) => StudentInfo(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        nis: j['nis'] as String?,
      );
}

class GradeRow {
  const GradeRow({
    required this.studentId,
    required this.name,
    this.nis,
    this.value,
    this.letter,
    this.predicate,
  });

  final int studentId;
  final String name;
  final String? nis;
  final double? value;
  final String? letter;
  final String? predicate;

  factory GradeRow.fromJson(Map<String, dynamic> j) => GradeRow(
        studentId: j['student_id'] as int,
        name: j['name'] as String? ?? '',
        nis: j['nis'] as String?,
        value: (j['grade_value'] as num?)?.toDouble(),
        letter: j['grade_letter'] as String?,
        predicate: j['predicate'] as String?,
      );
}

class GradeSheet {
  const GradeSheet({required this.rows, this.kkm});

  final List<GradeRow> rows;

  /// 0 or null = no KKM configured.
  final double? kkm;
}

class SaveResult {
  const SaveResult({required this.saved, required this.skipped});

  final int saved;
  final int skipped;

  factory SaveResult.fromJson(Map<String, dynamic> j) => SaveResult(
        saved: j['saved'] as int? ?? 0,
        skipped: j['skipped'] as int? ?? 0,
      );
}

// ---- Own attendance (/attendance/me) ----

class AttendanceDay {
  const AttendanceDay({
    required this.date,
    this.dayName,
    required this.status,
    required this.statusLabel,
    this.checkIn,
    this.checkOut,
    this.notes,
  });

  final String date;
  final String? dayName;

  /// present | late | absent | excused | sick | permission
  final String status;
  final String statusLabel;
  final String? checkIn;
  final String? checkOut;
  final String? notes;

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date: j['date'] as String? ?? '',
        dayName: j['day_name'] as String?,
        status: j['status'] as String? ?? '',
        statusLabel: j['status_label'] as String? ?? '',
        checkIn: j['check_in'] as String?,
        checkOut: j['check_out'] as String?,
        notes: j['notes'] as String?,
      );
}

class AttendanceMonth {
  const AttendanceMonth({
    required this.month,
    required this.summary,
    required this.days,
  });

  /// `YYYY-MM`.
  final String month;

  /// status -> count, plus `total`.
  final Map<String, int> summary;
  final List<AttendanceDay> days;

  int count(String status) => summary[status] ?? 0;

  factory AttendanceMonth.fromJson(Map<String, dynamic> j) {
    final raw = j['summary'] as Map<String, dynamic>? ?? const {};
    return AttendanceMonth(
      month: j['month'] as String? ?? '',
      summary: {for (final e in raw.entries) e.key: (e.value as num).toInt()},
      days: _list(j['days'], AttendanceDay.fromJson),
    );
  }
}

// ---- Per-lesson student attendance (/lessons, /schedules/{id}/attendance) ----

class LessonClass {
  const LessonClass({
    required this.scheduleId,
    required this.gradeId,
    required this.name,
    required this.submitted,
    this.present = 0,
    this.total = 0,
  });

  final int scheduleId;
  final int gradeId;
  final String name;
  final bool submitted;
  final int present;
  final int total;

  factory LessonClass.fromJson(Map<String, dynamic> j) {
    final a = j['attendance'] as Map<String, dynamic>? ?? const {};
    return LessonClass(
      scheduleId: j['schedule_id'] as int,
      gradeId: j['grade_id'] as int,
      name: j['name'] as String? ?? '',
      submitted: a['state'] == 'submitted',
      // "Hadir" counts late students too: they were in the room.
      present: ((a['present'] as num?) ?? 0).toInt() +
          ((a['late'] as num?) ?? 0).toInt(),
      total: ((a['total'] as num?) ?? 0).toInt(),
    );
  }
}

class LessonItem {
  const LessonItem({
    required this.sessionNumber,
    required this.start,
    required this.end,
    required this.subject,
    required this.classes,
  });

  final int sessionNumber;
  final String start;
  final String end;
  final String subject;
  final List<LessonClass> classes;

  factory LessonItem.fromJson(Map<String, dynamic> j) => LessonItem(
        sessionNumber: j['session_number'] as int? ?? 0,
        start: j['start'] as String? ?? '',
        end: j['end'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        classes: _list(j['classes'], LessonClass.fromJson),
      );
}

/// Consecutive JP of the same subject in the same class, recorded together.
class LessonBlock {
  const LessonBlock({
    required this.subject,
    required this.gradeId,
    required this.className,
    required this.sessions,
  });

  final String subject;
  final int gradeId;
  final String className;

  /// One entry per JP, ordered. `scheduleId` is what the API saves against.
  final List<BlockSession> sessions;

  int get firstJp => sessions.first.sessionNumber;
  int get lastJp => sessions.last.sessionNumber;
  String get start => sessions.first.start;
  String get end => sessions.last.end;
  String get jpLabel => firstJp == lastJp ? 'JP $firstJp' : 'JP $firstJp–$lastJp';
  List<int> get scheduleIds => [for (final s in sessions) s.scheduleId];

  /// pending | partial | submitted
  String get state {
    final done = sessions.where((s) => s.submitted).length;
    if (done == 0) return 'pending';
    return done == sessions.length ? 'submitted' : 'partial';
  }

  /// "28/30 hadir" from the first recorded JP, or null when nothing is recorded.
  String? get summary {
    final s = sessions.where((s) => s.submitted && s.total > 0).firstOrNull;
    return s == null ? null : '${s.present}/${s.total} hadir';
  }
}

class BlockSession {
  const BlockSession({
    required this.scheduleId,
    required this.sessionNumber,
    required this.start,
    required this.end,
    required this.submitted,
    required this.present,
    required this.total,
  });

  final int scheduleId;
  final int sessionNumber;
  final String start;
  final String end;
  final bool submitted;
  final int present;
  final int total;
}

/// Flattens `/lessons` to per-class entries and merges back-to-back JP of the
/// same subject+class into one block ("JP 1–2"). A gap (e.g. a break between
/// JP 4 and 5 that skips a number) or a different subject starts a new block.
List<LessonBlock> buildLessonBlocks(List<LessonItem> lessons) {
  final byClass = <String, List<(LessonItem, LessonClass)>>{};
  for (final l in lessons) {
    for (final c in l.classes) {
      byClass.putIfAbsent('${c.gradeId}|${l.subject}', () => []).add((l, c));
    }
  }

  final blocks = <LessonBlock>[];
  for (final entries in byClass.values) {
    entries.sort((a, b) => a.$1.sessionNumber.compareTo(b.$1.sessionNumber));
    var current = <(LessonItem, LessonClass)>[];
    void flush() {
      if (current.isEmpty) return;
      final first = current.first;
      blocks.add(LessonBlock(
        subject: first.$1.subject,
        gradeId: first.$2.gradeId,
        className: first.$2.name,
        sessions: [
          for (final (l, c) in current)
            BlockSession(
              scheduleId: c.scheduleId,
              sessionNumber: l.sessionNumber,
              start: l.start,
              end: l.end,
              submitted: c.submitted,
              present: c.present,
              total: c.total,
            ),
        ],
      ));
      current = [];
    }

    for (final e in entries) {
      if (current.isNotEmpty &&
          e.$1.sessionNumber != current.last.$1.sessionNumber + 1) {
        flush();
      }
      current.add(e);
    }
    flush();
  }

  blocks.sort((a, b) {
    final byJp = a.firstJp.compareTo(b.firstJp);
    return byJp != 0 ? byJp : a.className.compareTo(b.className);
  });
  return blocks;
}

const attendanceStatuses = ['present', 'late', 'sick', 'permission', 'absent'];

class AttendanceStudent {
  const AttendanceStudent({
    required this.studentId,
    required this.name,
    this.nis,
    this.status,
    this.note,
  });

  final int studentId;
  final String name;
  final String? nis;

  /// null = nothing recorded yet for this JP.
  final String? status;
  final String? note;

  factory AttendanceStudent.fromJson(Map<String, dynamic> j) =>
      AttendanceStudent(
        studentId: j['student_id'] as int,
        name: j['name'] as String? ?? '',
        nis: j['nis'] as String?,
        status: j['status'] as String?,
        note: j['note'] as String?,
      );
}

class AttendanceRoster {
  const AttendanceRoster({
    required this.submitted,
    required this.editable,
    this.lockedMessage,
    required this.warnings,
    required this.students,
  });

  final bool submitted;
  final bool editable;
  final String? lockedMessage;
  final List<String> warnings;
  final List<AttendanceStudent> students;

  factory AttendanceRoster.fromJson(Map<String, dynamic> j) {
    final s = j['session'] as Map<String, dynamic>? ?? const {};
    return AttendanceRoster(
      submitted: s['state'] == 'submitted',
      editable: s['editable'] as bool? ?? false,
      lockedMessage: s['locked_message'] as String?,
      warnings: [
        for (final w in (j['warnings'] as List<dynamic>? ?? const [])) '$w',
      ],
      students: _list(j['students'], AttendanceStudent.fromJson),
    );
  }
}

// ---- Schedule display: back-to-back JP shown as one card ("JP 1–2") ----

/// Consecutive JP of the same subject and class(es) on one day.
class LessonGroup {
  const LessonGroup({
    required this.subject,
    required this.classes,
    required this.sessions,
    this.room,
  });

  final String subject;

  /// "8D" or, for a kelas gabungan, "9A + 9B".
  final String classes;
  final String? room;
  final List<Lesson> sessions;

  int get firstJp => sessions.first.sessionNumber;
  int get lastJp => sessions.last.sessionNumber;
  String get start => sessions.first.start;
  String get end => sessions.last.end;
  String get jpLabel => firstJp == lastJp ? 'JP $firstJp' : 'JP $firstJp–$lastJp';
  String get timeRange => '$start – $end';

  /// current | next | done | upcoming (today only; other days are all `upcoming`).
  String get status {
    if (sessions.any((s) => s.status == 'current')) return 'current';
    if (sessions.any((s) => s.status == 'next')) return 'next';
    if (sessions.every((s) => s.status == 'done')) return 'done';
    return 'upcoming';
  }
}

/// Merges back-to-back JP (n, n+1, ...) with the same subject and classes.
/// A gap in numbering or a different subject/class starts a new group.
List<LessonGroup> groupLessons(List<Lesson> lessons) {
  final sorted = [...lessons]
    ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
  final groups = <LessonGroup>[];
  var current = <Lesson>[];

  void flush() {
    if (current.isEmpty) return;
    groups.add(LessonGroup(
      subject: current.first.subject,
      classes: current.first.classes,
      room: current.first.room,
      sessions: current,
    ));
    current = [];
  }

  for (final l in sorted) {
    if (current.isNotEmpty) {
      final last = current.last;
      final continues = l.sessionNumber == last.sessionNumber + 1 &&
          l.subject == last.subject &&
          l.classes == last.classes;
      if (!continues) flush();
    }
    current.add(l);
  }
  flush();
  return groups;
}

/// How far attendance is for a schedule group, from the day's [LessonBlock]s.
/// null = no information (nothing to match); otherwise pending | partial | submitted.
({String state, String? summary})? attendanceForGroup(
    LessonGroup group, List<LessonBlock> blocks) {
  final matching = blocks.where((b) =>
      b.subject == group.subject &&
      b.firstJp >= group.firstJp &&
      b.lastJp <= group.lastJp);
  if (matching.isEmpty) return null;

  final states = matching.map((b) => b.state).toSet();
  final summary = matching.map((b) => b.summary).nonNulls.firstOrNull;
  if (states.length == 1 && states.first == 'submitted') {
    return (state: 'submitted', summary: summary);
  }
  if (states.length == 1 && states.first == 'pending') {
    return (state: 'pending', summary: null);
  }
  return (state: 'partial', summary: summary);
}
