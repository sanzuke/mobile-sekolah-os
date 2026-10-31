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
}
