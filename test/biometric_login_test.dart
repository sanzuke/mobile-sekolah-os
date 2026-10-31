import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/screens/login_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/services/biometric_service.dart';
import 'package:mobile_sekolah_os/state/session_controller.dart';

class _Gate implements BiometricGate {
  bool available = true;
  bool pass = true;
  int prompts = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    prompts++;
    return pass;
  }
}

class _Auth extends AuthService {
  _Auth() : super(client: ApiClient());

  String validPassword = 'rahasia';
  final logins = <String>[];

  @override
  Future<AuthenticatedTeacher?> restore() async => null;

  @override
  Future<AuthenticatedTeacher> login(String email, String password) async {
    logins.add('$email|$password');
    if (password != validPassword) {
      throw ApiException('Email atau kata sandi salah.', statusCode: 422);
    }
    return const AuthenticatedTeacher(id: 1, name: 'Guru Uji', email: 'guru@x.id');
  }
}

void main() {
  late _Gate gate;
  late _Auth auth;
  late SessionController session;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    gate = _Gate();
    auth = _Auth();
    session = SessionController(auth, biometric: BiometricLogin(gate: gate));
  });

  Future<void> signInAndEnable() async {
    await session.start();
    await session.login('guru@x.id', 'rahasia');
    expect(await session.enableBiometric('rahasia'), isNull);
    await session.logout();
  }

  test('enabling needs the biometric prompt and the right password', () async {
    await session.start();
    await session.login('guru@x.id', 'rahasia');

    gate.pass = false;
    expect(await session.enableBiometric('rahasia'), isNotNull);
    expect(session.biometricEnabled, isFalse);

    gate.pass = true;
    expect(await session.enableBiometric('salah'), 'Kata sandi salah.');
    expect(session.biometricEnabled, isFalse);

    expect(await session.enableBiometric('rahasia'), isNull);
    expect(session.biometricEnabled, isTrue);
  });

  test('biometric login signs in with the stored credentials', () async {
    await signInAndEnable();
    expect(session.status, SessionStatus.signedOut);
    expect(session.biometricEnabled, isTrue); // logging out keeps the setting
    auth.logins.clear();

    await session.loginWithBiometric();

    expect(auth.logins, ['guru@x.id|rahasia']);
    expect(session.status, SessionStatus.signedIn);
  });

  test('a cancelled prompt does nothing and says nothing', () async {
    await signInAndEnable();
    auth.logins.clear();
    gate.pass = false;

    await session.loginWithBiometric();

    expect(auth.logins, isEmpty);
    expect(session.status, SessionStatus.signedOut);
    expect(session.error, isNull);
  });

  test('a changed password switches biometric login off with an explanation',
      () async {
    await signInAndEnable();
    auth.validPassword = 'baru';

    await session.loginWithBiometric();

    expect(session.status, SessionStatus.signedOut);
    expect(session.biometricEnabled, isFalse);
    expect(session.error, contains('Kata sandi berubah'));

    // and the stored password is really gone
    await session.start();
    expect(session.biometricEnabled, isFalse);
  });

  test('a device without enrolled biometrics never offers it', () async {
    gate.available = false;
    await session.start();
    expect(session.biometricAvailable, isFalse);
    expect(session.biometricEnabled, isFalse);
  });

  testWidgets('login screen shows the biometric button only when enabled',
      (tester) async {
    await signInAndEnable();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: session)));
    expect(find.text('Masuk dengan biometrik'), findsOneWidget);

    await session.disableBiometric();
    await tester.pump();
    expect(find.text('Masuk dengan biometrik'), findsNothing);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
