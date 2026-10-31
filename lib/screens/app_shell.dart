import 'package:flutter/material.dart';

import '../services/teacher_service.dart';
import '../services/update_service.dart';
import '../state/session_controller.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'quick_actions_sheet.dart';
import 'schedule_screen.dart';
import 'shell_actions.dart';

/// Shell from the design: Beranda, Jadwal, "+" (Aksi cepat), Kotak Masuk, Akun.
/// Nilai/Akademik is not a tab; it is a menu under Semua menu.
/// IndexedStack keeps each tab's loaded data when switching.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.service,
    required this.updater,
  });

  final SessionController session;
  final TeacherService service;
  final AppUpdater updater;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = kTabHome;

  /// Unread notification count, shared by the nav badge, the bell and Kotak masuk.
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);

  /// Academic year shown on Akun; Beranda fills it when it loads.
  final ValueNotifier<String?> _academicYear = ValueNotifier<String?>(null);

  /// Segment of Kotak masuk another screen wants open (-1 = none).
  final ValueNotifier<int> _inboxSegment = ValueNotifier<int>(-1);

  late final ShellActions _actions = ShellActions(
    service: widget.service,
    unread: _unread,
    academicYear: _academicYear,
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
    _academicYear.dispose();
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
      AccountScreen(
        teacher: widget.session.teacher!,
        academicYear: _academicYear,
        onLogout: widget.session.logout,
        updater: widget.updater,
        session: widget.session,
      ),
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
        onPressed: () => showQuickActions(context, _actions),
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
