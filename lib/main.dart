import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/teacher_service.dart';
import 'services/update_service.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';

void main() {
  // Secure storage (session restore) uses a platform channel; the binding must
  // exist before SessionController.start() touches it.
  WidgetsFlutterBinding.ensureInitialized();
  final client = ApiClient();
  final session = SessionController(AuthService(client: client))..start();
  runApp(SekolahOsApp(
    session: session,
    service: TeacherService(client),
    updater: HttpAppUpdater(client: client),
  ));
}

class SekolahOsApp extends StatelessWidget {
  const SekolahOsApp({
    super.key,
    required this.session,
    required this.service,
    required this.updater,
  });

  final SessionController session;
  final TeacherService service;
  final AppUpdater updater;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asatidz PPI 50',
      // Dialogs and pickers (date range, etc.) speak Indonesian.
      locale: const Locale('id'),
      supportedLocales: const [Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.status) {
          SessionStatus.loading =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionStatus.signedOut => LoginScreen(session: session),
          SessionStatus.signedIn => AppShell(session: session, service: service, updater: updater),
        },
      ),
    );
  }
}
