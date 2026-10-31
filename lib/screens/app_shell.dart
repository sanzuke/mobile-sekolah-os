import 'package:flutter/material.dart';

import '../services/teacher_service.dart';
import '../state/session_controller.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'schedule_screen.dart';

/// Bottom-nav shell from the design: Beranda, Jadwal, Kotak masuk, Akun.
/// Beranda, Jadwal, Kotak masuk (Pengumuman, Agenda, Notifikasi) and Akun are live.
/// IndexedStack keeps each tab's loaded data when switching.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.service});

  final SessionController session;
  final TeacherService service;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Unread notification count, shared by the nav badge, Beranda and Kotak masuk.
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);

  @override
  void dispose() {
    _unread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacher = widget.session.teacher!;
    final pages = <Widget>[
      HomeScreen(
        teacher: teacher,
        service: widget.service,
        unread: _unread,
        onUnauthorized: widget.session.logout,
        onOpenSchedule: () => setState(() => _index = 1),
      ),
      ScheduleScreen(
        service: widget.service,
        onUnauthorized: widget.session.logout,
      ),
      InboxScreen(
        service: widget.service,
        unread: _unread,
        onUnauthorized: widget.session.logout,
      ),
      _AccountPage(session: widget.session),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.schedule_outlined), label: 'Jadwal'),
          NavigationDestination(
              icon: ValueListenableBuilder<int>(
                valueListenable: _unread,
                builder: (_, count, _) => Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.inbox_outlined),
                ),
              ),
              label: 'Kotak masuk'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Akun'),
        ],
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final t = session.teacher!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(radius: 28, child: Text(t.initials)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(t.isHomeroom ? 'Wali kelas' : 'Guru'),
                  if (t.nip != null) Text('NIP ${t.nip}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: session.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}
