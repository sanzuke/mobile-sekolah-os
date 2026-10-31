import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/state/session_controller.dart';

class _ThrowingAuth extends AuthService {
  _ThrowingAuth(this.error) : super(client: ApiClient());

  final Object error;

  @override
  Future<AuthenticatedTeacher?> restore() async => throw error;
}

void main() {
  // Regression: a cold start must never stay on the spinner, whatever restore throws
  // (found on a real device: storage threw before the binding was initialized).
  for (final error in <Object>[
    PlatformException(code: 'storage', message: 'unavailable'),
    StateError('Binding has not yet been initialized'),
    ApiException('offline'),
  ]) {
    test('start() falls back to signedOut when restore throws ${error.runtimeType}',
        () async {
      final session = SessionController(_ThrowingAuth(error));
      expect(session.status, SessionStatus.loading);

      await session.start();

      expect(session.status, SessionStatus.signedOut);
      expect(session.teacher, isNull);
    });
  }
}
