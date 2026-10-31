import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/teacher_service.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

void main() {
  final client = ApiClient();
  final session = SessionController(AuthService(client: client))..start();
  runApp(SekolahOsApp(session: session, service: TeacherService(client)));
}

class SekolahOsApp extends StatelessWidget {
  const SekolahOsApp({super.key, required this.session, required this.service});

  final SessionController session;
  final TeacherService service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SekolahOS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.status) {
          SessionStatus.loading =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionStatus.signedOut => LoginScreen(session: session),
          SessionStatus.signedIn => AppShell(session: session, service: service),
        },
      ),
    );
  }
}
