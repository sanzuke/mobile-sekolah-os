import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_messaging.dart';
import 'services/teacher_service.dart';
import 'services/update_service.dart';
import 'state/push_registrar.dart';
import 'state/session_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/content_width.dart';

Future<void> main() async {
  // Secure storage (session restore) uses a platform channel; the binding must
  // exist before SessionController.start() touches it.
  WidgetsFlutterBinding.ensureInitialized();
  // Falls back to "no push" if Firebase cannot start; never blocks the app.
  final messaging = FirebasePushMessaging();
  await messaging.init();
  final client = ApiClient();
  final service = TeacherService(client);
  final session = SessionController(
    AuthService(client: client),
    push: PushRegistrar(service: service, messaging: messaging),
  )..start();
  runApp(SekolahOsApp(
    session: session,
    service: service,
    updater: HttpAppUpdater(client: client),
    push: messaging,
  ));
}

class SekolahOsApp extends StatelessWidget {
  const SekolahOsApp({
    super.key,
    required this.session,
    required this.service,
    required this.updater,
    this.push = const NoPushMessaging(),
  });

  final SessionController session;
  final TeacherService service;
  final AppUpdater updater;
  final PushMessaging push;

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
      builder: (context, child) => ContentWidth(child: child!),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.status) {
          SessionStatus.loading =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionStatus.signedOut => LoginScreen(session: session),
          SessionStatus.signedIn => AppShell(
              session: session,
              service: service,
              updater: updater,
              push: push,
            ),
        },
      ),
    );
  }
}
