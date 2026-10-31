import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// The device's fingerprint / face prompt. Behind an interface so tests need no
/// platform channel.
abstract class BiometricGate {
  /// True when the device has biometric hardware AND at least one enrolled
  /// fingerprint / face. Never throws.
  Future<bool> isAvailable();

  /// Shows the system prompt. False when cancelled or not recognised; never throws.
  Future<bool> authenticate(String reason);
}

class LocalAuthGate implements BiometricGate {
  LocalAuthGate([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Biometric only: the phone's PIN/pattern is not a fallback here, otherwise
      // anyone who knows the phone PIN could open the teacher's account.
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Masuk dengan biometrik',
            signInHint: 'Sentuh sensor sidik jari atau pindai wajah',
            cancelButton: 'Batal',
          ),
        ],
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Opt-in "log in with fingerprint / face". The email and password are kept in
/// secure storage (Android Keystore) only after the teacher turns it on, and are
/// released only after the biometric prompt succeeds. A password is kept (not
/// the token) because logging out revokes the token on the server.
class BiometricLogin {
  BiometricLogin({BiometricGate? gate, FlutterSecureStorage? storage})
      : gate = gate ?? LocalAuthGate(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _emailKey = 'bio_email';
  static const _passwordKey = 'bio_password';

  final BiometricGate gate;
  final FlutterSecureStorage _storage;

  Future<bool> isAvailable() => gate.isAvailable();

  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _passwordKey) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> enable(String email, String password) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> disable() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {
      // Nothing stored or storage unavailable: nothing to clear.
    }
  }

  /// Prompts, then returns the stored credentials; null when cancelled, failed or
  /// not enabled.
  Future<({String email, String password})?> unlock(String reason) async {
    if (!await gate.authenticate(reason)) return null;
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }
}
