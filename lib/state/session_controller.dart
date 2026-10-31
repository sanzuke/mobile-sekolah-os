import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

enum SessionStatus { loading, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this._auth, {BiometricLogin? biometric})
      : _biometric = biometric ?? BiometricLogin();

  final AuthService _auth;
  final BiometricLogin _biometric;

  /// Device has biometrics enrolled, and the teacher turned the feature on.
  bool biometricAvailable = false;
  bool biometricEnabled = false;

  SessionStatus status = SessionStatus.loading;
  AuthenticatedTeacher? teacher;
  String? error;
  bool busy = false;

  Future<void> start() async {
    try {
      teacher = await _auth.restore();
    } catch (_) {
      // Offline, server down, or storage unavailable on cold start: never stay
      // on the spinner — fall back to the login screen.
      teacher = null;
    }
    await refreshBiometric();
    status = teacher == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> refreshBiometric() async {
    try {
      biometricAvailable = await _biometric.isAvailable();
      biometricEnabled = biometricAvailable && await _biometric.isEnabled();
    } catch (_) {
      biometricAvailable = false;
      biometricEnabled = false;
    }
  }

  /// Login screen button: fingerprint/face, then the usual login with the stored
  /// credentials. Cancelling the prompt is silent.
  Future<void> loginWithBiometric() async {
    if (busy) return;
    final saved =
        await _biometric.unlock('Masuk ke akun guru Anda dengan biometrik');
    if (saved == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      teacher = await _auth.login(saved.email, saved.password);
      status = SessionStatus.signedIn;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 422) {
        // Password changed (or account disabled): the stored one is useless.
        await _biometric.disable();
        biometricEnabled = false;
        error = 'Kata sandi berubah. Masuk dengan kata sandi, lalu aktifkan lagi login biometrik di menu Akun.';
      } else {
        error = e.message;
      }
    } catch (_) {
      error = 'Tidak dapat terhubung ke server.';
    }
    busy = false;
    notifyListeners();
  }

  /// Akun toggle. Confirms with the biometric prompt, then checks [password]
  /// against the server before storing it. Returns an error message, or null.
  Future<String?> enableBiometric(String password) async {
    final email = teacher?.email;
    if (email == null || email.isEmpty) return 'Email akun tidak tersedia.';
    if (!await _biometric.gate.authenticate('Konfirmasi untuk mengaktifkan login biometrik')) {
      return 'Biometrik tidak dikonfirmasi.';
    }
    try {
      teacher = await _auth.login(email, password);
    } on ApiException catch (e) {
      return e.statusCode == 401 || e.statusCode == 422
          ? 'Kata sandi salah.'
          : e.message;
    } catch (_) {
      return 'Tidak dapat terhubung ke server.';
    }
    await _biometric.enable(email, password);
    biometricEnabled = true;
    notifyListeners();
    return null;
  }

  Future<void> disableBiometric() async {
    await _biometric.disable();
    biometricEnabled = false;
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
