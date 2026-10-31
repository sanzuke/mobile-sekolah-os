/// Backend base URL, overridable at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://staging.example.com/api
/// Never hardcode a real server URL here — this repo is public.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
