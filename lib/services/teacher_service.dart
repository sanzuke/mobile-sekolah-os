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
}
