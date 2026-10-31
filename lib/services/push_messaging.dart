import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// What a push says, reduced to what the app acts on (the FCM `data` map).
class PushMessage {
  const PushMessage({this.type, this.leaveRequestId, this.notificationId});

  /// `leave_request` (more later).
  final String? type;
  final int? leaveRequestId;

  /// The in-app notification this push mirrors (to mark it read when opened).
  final String? notificationId;

  factory PushMessage.fromData(Map<String, dynamic> data) => PushMessage(
        type: data['type'] as String?,
        leaveRequestId: int.tryParse('${data['leave_request_id'] ?? ''}'),
        notificationId: data['notification_id'] as String?,
      );
}

/// The device's push channel (Firebase Cloud Messaging). Behind an interface so
/// the rest of the app, and its tests, never touch Firebase.
abstract class PushMessaging {
  /// Asks for the notification permission (Android 13+). True when allowed.
  Future<bool> requestPermission();

  /// This phone's registration token; null when push is unavailable.
  Future<String?> token();

  Stream<String> get onTokenRefresh;

  /// A push arrived while the app is open (the system shows nothing then).
  Stream<PushMessage> get onForeground;

  /// The user tapped a push while the app was in the background.
  Stream<PushMessage> get onOpened;

  /// The push that launched the app from a closed state, if any.
  Future<PushMessage?> initialMessage();
}

/// No push (Firebase not configured / not available): everything is a no-op.
class NoPushMessaging implements PushMessaging {
  const NoPushMessaging();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<PushMessage> get onForeground => const Stream.empty();

  @override
  Stream<PushMessage> get onOpened => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => null;
}

/// FCM through `firebase_messaging`. Call [init] once at start-up; if Firebase
/// cannot start (no google-services.json, no Play services) it behaves like
/// [NoPushMessaging] instead of crashing the app.
class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging? _fm;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _fm = FirebaseMessaging.instance;
    } catch (_) {
      _fm = null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final fm = _fm;
    if (fm == null) return false;
    try {
      final s = await fm.requestPermission();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  // firebase_messaging 17 deprecates getToken/onTokenRefresh for register()/onRegistered,
  // but those return a Firebase *Installation ID*. The server sends with the classic
  // registration token (FCM HTTP v1 `token`), so keep these until that is verified.
  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await _fm?.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _fm == null
      ? const Stream.empty()
      // ignore: deprecated_member_use
      : _fm!.onTokenRefresh;

  @override
  Stream<PushMessage> get onForeground => _fm == null
      ? const Stream.empty()
      : FirebaseMessaging.onMessage.map((m) => PushMessage.fromData(m.data));

  @override
  Stream<PushMessage> get onOpened => _fm == null
      ? const Stream.empty()
      : FirebaseMessaging.onMessageOpenedApp
          .map((m) => PushMessage.fromData(m.data));

  @override
  Future<PushMessage?> initialMessage() async {
    try {
      final m = await _fm?.getInitialMessage();
      return m == null ? null : PushMessage.fromData(m.data);
    } catch (_) {
      return null;
    }
  }
}
