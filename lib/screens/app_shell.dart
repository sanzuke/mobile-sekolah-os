import 'package:flutter/material.dart';

import '../services/teacher_service.dart';
import '../state/session_controller.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';

/// Bottom-nav shell from the design: Beranda, Jadwal, Kotak masuk, Akun.
/// Beranda, Jadwal and Akun are live; Kotak masuk is a placeholder until its
/// endpoints land. IndexedStack keeps each tab's loaded data when switching.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.service});

  final SessionController session;
  final TeacherService service;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final teacher = widget.session.teacher!;
    final pages = <Widget>[
      HomeScreen(
        teacher: teacher,
        service: widget.service,
        onUnauthorized: widget.session.logout,
        onOpenSchedule: () => setState(() => _index = 1),
      ),
      ScheduleScreen(
        service: widget.service,
        onUnauthorized: widget.session.logout,
      ),
      const _Placeholder(
          title: 'Kotak masuk', subtitle: 'Segera hadir', icon: Icons.inbox),
      _AccountPage(session: widget.session),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.schedule_outlined), label: 'Jadwal'),
          NavigationDestination(
              icon: Icon(Icons.inbox_outlined), label: 'Kotak masuk'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Akun'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(
      {required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle),
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
