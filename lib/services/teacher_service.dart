import 'package:http/http.dart' as http;

import '../models/leave_models.dart';
import '../models/teacher_models.dart';
import 'api_client.dart';

class TeacherService {
  TeacherService(this._client);

  final ApiClient _client;

  Future<HomeData> home() async =>
      HomeData.fromJson(await _client.get('/v1/teacher/home') as Map<String, dynamic>);

  /// [date] is `YYYY-MM-DD`; any day of the wanted week. Null = this week.
  Future<ScheduleData> schedule({String? date}) async => ScheduleData.fromJson(
        await _client.get('/v1/teacher/schedule',
            query: date == null ? null : {'date': date}) as Map<String, dynamic>,
      );

  /// Agenda between [from] and [to] (`YYYY-MM-DD`); server default is today +30 days.
  Future<List<AgendaItem>> agenda({String? from, String? to}) async {
    final data = await _client.get('/v1/teacher/agenda', query: {
      'from': ?from,
      'to': ?to,
    }) as List<dynamic>;
    return data
        .map((e) => AgendaItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AnnouncementPage> announcements({int page = 1}) async {
    final res = await _client.getEnvelope('/v1/teacher/announcements',
        query: {'page': '$page', 'per_page': '15'});
    final meta = res['meta'] as Map<String, dynamic>;
    return AnnouncementPage(
      items: (res['data'] as List<dynamic>)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastPage: meta['last_page'] as int? ?? 1,
    );
  }

  Future<AnnouncementDetail> announcement(int id) async =>
      AnnouncementDetail.fromJson(
          await _client.get('/v1/teacher/announcements/$id')
              as Map<String, dynamic>);

  Future<NotificationPage> notifications({int page = 1}) async {
    final res = await _client.getEnvelope('/v1/teacher/notifications',
        query: {'page': '$page', 'per_page': '20'});
    final meta = res['meta'] as Map<String, dynamic>;
    return NotificationPage(
      items: (res['data'] as List<dynamic>)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastPage: meta['last_page'] as int? ?? 1,
      unreadCount: meta['unread_count'] as int? ?? 0,
    );
  }

  Future<void> markNotificationRead(String id) async {
    await _client.post('/v1/teacher/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _client.post('/v1/teacher/notifications/read-all');
  }

  Future<ClassesData> classes() async => ClassesData.fromJson(
      await _client.get('/v1/teacher/classes') as Map<String, dynamic>);

  Future<List<StudentInfo>> students(int gradeId) async {
    final data =
        await _client.get('/v1/teacher/classes/$gradeId/students') as List<dynamic>;
    return data
        .map((e) => StudentInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GradeSheet> gradeSheet({
    required int gradeId,
    required int subjectId,
    required int examPeriodId,
  }) async {
    final res = await _client.getEnvelope(
      '/v1/teacher/classes/$gradeId/subjects/$subjectId/grades',
      query: {'exam_period_id': '$examPeriodId'},
    );
    final meta = res['meta'] as Map<String, dynamic>;
    return GradeSheet(
      rows: (res['data'] as List<dynamic>)
          .map((e) => GradeRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      kkm: (meta['kkm'] as num?)?.toDouble(),
    );
  }

  /// [values] maps student id -> score (0–100). Only send the cells that changed.
  Future<SaveResult> saveGrades({
    required int gradeId,
    required int subjectId,
    required int examPeriodId,
    required Map<int, double> values,
  }) async {
    final data = await _client.put(
      '/v1/teacher/classes/$gradeId/subjects/$subjectId/grades',
      body: {
        'exam_period_id': examPeriodId,
        'grades': [
          for (final e in values.entries)
            {'student_id': e.key, 'grade_value': e.value},
        ],
      },
    ) as Map<String, dynamic>;
    return SaveResult.fromJson(data);
  }

  /// [month] is `YYYY-MM`; null = the current month (server, WIB).
  Future<AttendanceMonth> attendance({String? month}) async =>
      AttendanceMonth.fromJson(await _client.get('/v1/teacher/attendance/me',
          query: month == null ? null : {'month': month}) as Map<String, dynamic>);

  /// Lessons of [date] (`YYYY-MM-DD`) with per-class attendance state.
  Future<List<LessonItem>> lessons({required String date}) async {
    final data = await _client.get('/v1/teacher/lessons', query: {'date': date})
        as List<dynamic>;
    return data
        .map((e) => LessonItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceRoster> attendanceRoster({
    required int scheduleId,
    required String date,
  }) async =>
      AttendanceRoster.fromJson(await _client.get(
          '/v1/teacher/schedules/$scheduleId/attendance',
          query: {'date': date}) as Map<String, dynamic>);

  /// [records] maps student id -> (status, note). Idempotent on the server.
  Future<void> saveAttendance({
    required int scheduleId,
    required String date,
    required Map<int, ({String status, String? note})> records,
  }) async {
    await _client.put('/v1/teacher/schedules/$scheduleId/attendance', body: {
      'date': date,
      'records': [
        for (final e in records.entries)
          {
            'student_id': e.key,
            'status': e.value.status,
            'note': ?e.value.note,
          },
      ],
    });
  }

  Future<LeaveRequestPage> leaveRequests({String? status, int page = 1}) async {
    final res = await _client.getEnvelope('/v1/teacher/leave-requests', query: {
      'page': '$page',
      'per_page': '20',
      'status': ?status,
    });
    final meta = res['meta'] as Map<String, dynamic>;
    return LeaveRequestPage(
      items: (res['data'] as List<dynamic>)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastPage: meta['last_page'] as int? ?? 1,
      pendingCount: meta['pending_count'] as int? ?? 0,
    );
  }

  Future<LeaveRequest> leaveRequest(int id) async => LeaveRequest.fromJson(
      await _client.get('/v1/teacher/leave-requests/$id') as Map<String, dynamic>);

  /// Dates are `YYYY-MM-DD`.
  Future<LeavePreview> previewLeave(String startDate, String endDate) async =>
      LeavePreview.fromJson(await _client.get('/v1/teacher/leave-requests/preview',
          query: {'start_date': startDate, 'end_date': endDate})
          as Map<String, dynamic>);

  Future<LeaveRequest> submitLeave({
    required String type,
    required String startDate,
    required String endDate,
    required String reason,
    String? attachmentName,
    List<int>? attachmentBytes,
  }) async =>
      LeaveRequest.fromJson(await _client.postMultipart(
        '/v1/teacher/leave-requests',
        fields: {
          'type': type,
          'start_date': startDate,
          'end_date': endDate,
          'reason': reason,
        },
        files: [
          if (attachmentBytes != null)
            http.MultipartFile.fromBytes('attachment', attachmentBytes,
                filename: attachmentName ?? 'lampiran'),
        ],
      ) as Map<String, dynamic>);

  Future<LeaveRequest> cancelLeave(int id) async => LeaveRequest.fromJson(
      await _client.post('/v1/teacher/leave-requests/$id/cancel')
          as Map<String, dynamic>);

  Future<List<int>> leaveAttachment(int id) =>
      _client.getBytes('/v1/teacher/leave-requests/$id/attachment');

  /// Registers this phone for push (`token` is the FCM registration token).
  Future<void> registerDevice(String token) async {
    await _client.post('/v1/teacher/devices',
        body: {'token': token, 'platform': 'android'});
  }

  Future<void> unregisterDevice(String token) async {
    await _client.delete('/v1/teacher/devices', body: {'token': token});
  }
}
