import 'dart:async';

import '../services/push_messaging.dart';
import '../services/teacher_service.dart';

/// Tells the server which phone to push to: registers this phone's token after
/// sign-in (and whenever FCM rotates it), and removes it at sign-out. All of it is
/// best effort: no push must ever block signing in or out.
class PushRegistrar {
  PushRegistrar({required this.service, required this.messaging});

  final TeacherService service;
  final PushMessaging messaging;

  String? _token;
  StreamSubscription<String>? _refresh;

  Future<void> register() async {
    try {
      if (!await messaging.requestPermission()) return;
      final token = await messaging.token();
      if (token == null) return;
      _token = token;
      await service.registerDevice(token);
      _refresh ??= messaging.onTokenRefresh.listen((t) {
        _token = t;
        service.registerDevice(t).catchError((_) {});
      });
    } catch (_) {
      // Offline or push unavailable: the next sign-in tries again.
    }
  }

  /// Call while the session is still valid (before the API token is revoked).
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await service.unregisterDevice(token).timeout(const Duration(seconds: 3));
    } catch (_) {
      // The server also drops tokens FCM reports as dead.
    }
  }
}
