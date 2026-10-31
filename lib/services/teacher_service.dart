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
}
