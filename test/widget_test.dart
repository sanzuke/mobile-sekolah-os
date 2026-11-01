import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_sekolah_os/screens/login_screen.dart';
import 'package:mobile_sekolah_os/services/api_client.dart';
import 'package:mobile_sekolah_os/services/auth_service.dart';
import 'package:mobile_sekolah_os/state/session_controller.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('login screen shows email, password and Masuk', (tester) async {
    final session = SessionController(AuthService(client: ApiClient()));
    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: session, animateBackground: false)));

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
