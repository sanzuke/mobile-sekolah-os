import 'package:flutter/material.dart';

import '../services/teacher_service.dart';
import '../state/session_controller.dart';
import 'attendance_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'quick_actions_sheet.dart';
import 'schedule_screen.dart';
import 'shell_actions.dart';

/// Shell from the design: Beranda, Jadwal, "+" (Aksi cepat), Kotak Masuk, Akun.
/// Nilai/Akademik is not a tab; it is a menu under Semua menu.
/// IndexedStack keeps each tab's loaded data when switching.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.service});

  final SessionController session;
  final TeacherService service;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = kTabHome;

  /// Unread notification count, shared by the nav badge, the bell and Kotak masuk.
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);

  /// Segment of Kotak masuk another screen wants open (-1 = none).
  final ValueNotifier<int> _inboxSegment = ValueNotifier<int>(-1);

  late final ShellActions _actions = ShellActions(
    service: widget.service,
    unread: _unread,
    onUnauthorized: widget.session.logout,
    goTab: (tab) => setState(() => _index = tab),
    openInboxSegment: (segment) {
      setState(() => _index = kTabInbox);
      _inboxSegment.value = segment;
    },
  );

  @override
  void dispose() {
    _unread.dispose();
    _inboxSegment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(teacher: widget.session.teacher!, actions: _actions),
      ScheduleScreen(
        service: widget.service,
        onUnauthorized: widget.session.logout,
      ),
      InboxScreen(
        service: widget.service,
        unread: _unread,
        onUnauthorized: widget.session.logout,
        segmentRequest: _inboxSegment,
      ),
      _AccountPage(session: widget.session, service: widget.service),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Aksi cepat',
        shape: const CircleBorder(),
        // The design's "+" is solid accent with a white glyph (the M3 default is a pale container).
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () => showQuickActions(context),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          children: [
            _NavItem(
                label: 'Beranda',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                selected: _index == kTabHome,
                onTap: () => setState(() => _index = kTabHome)),
            _NavItem(
                label: 'Jadwal',
                icon: Icons.calendar_today_outlined,
                selectedIcon: Icons.calendar_today,
                selected: _index == kTabSchedule,
                onTap: () => setState(() => _index = kTabSchedule)),
            const SizedBox(width: 64), // room for the docked "+"
            _NavItem(
                label: 'Kotak masuk',
                icon: Icons.notifications_none,
                selectedIcon: Icons.notifications,
                badge: _unread,
                selected: _index == kTabInbox,
                onTap: () => setState(() => _index = kTabInbox)),
            _NavItem(
                label: 'Akun',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                selected: _index == kTabAccount,
                onTap: () => setState(() => _index = kTabAccount)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final ValueNotifier<int>? badge;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF64748B);
    Widget glyph = Icon(selected ? selectedIcon : icon, color: color, size: 24);
    if (badge != null) {
      glyph = ValueListenableBuilder<int>(
        valueListenable: badge!,
        builder: (_, count, child) =>
            Badge(isLabelVisible: count > 0, label: Text('$count'), child: child),
        child: glyph,
      );
    }
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              glyph,
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.session, required this.service});

  final SessionController session;
  final TeacherService service;

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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Rekap kehadiran'),
          subtitle: const Text('Presensi Anda dari mesin absen'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              service: service,
              onUnauthorized: session.logout,
            ),
          )),
        ),
        const Divider(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: session.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}
