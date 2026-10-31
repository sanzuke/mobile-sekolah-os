import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

enum SessionStatus { loading, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this._auth);

  final AuthService _auth;

  SessionStatus status = SessionStatus.loading;
  AuthenticatedTeacher? teacher;
  String? error;
  bool busy = false;

  Future<void> start() async {
    try {
      teacher = await _auth.restore();
    } on ApiException {
      // Offline or server down on cold start: fall back to the login screen.
      teacher = null;
    }
    status = teacher == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      teacher = await _auth.login(email.trim(), password);
      status = SessionStatus.signedIn;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Tidak dapat terhubung ke server.';
    }
    busy = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    teacher = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }
}
