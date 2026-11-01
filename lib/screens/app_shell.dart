import 'dart:async';

import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/push_messaging.dart';
import '../services/teacher_service.dart';
import '../services/update_service.dart';
import '../state/notification_watcher.dart';
import '../state/session_controller.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'facility_detail_screen.dart';
import 'leave_detail_screen.dart';
import 'incident_detail_screen.dart';
import 'meeting_minute_detail_screen.dart';
import 'notification_target.dart';
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
    this.push = const NoPushMessaging(),
  });

  final SessionController session;
  final TeacherService service;
  final AppUpdater updater;
  final PushMessaging push;

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

  /// Bumped when the background check finds new notifications, so an already
  /// loaded Notifikasi list reloads.
  final ValueNotifier<int> _notificationsVersion = ValueNotifier<int>(0);

  late final NotificationWatcher _watcher = NotificationWatcher(
    service: widget.service,
    unread: _unread,
    onUnauthorized: widget.session.logout,
    onNew: _announce,
  );

  /// A decision (or any news) arrived while the app is open: say so, and offer to
  /// open what it is about.
  void _announce(List<NotificationItem> fresh) {
    _notificationsVersion.value++;
    if (!mounted) return;
    final first = fresh.first;
    final single = fresh.length == 1;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(single ? first.title : '${fresh.length} notifikasi baru',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (single && first.body != null)
              Text(first.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: SnackBarAction(
          label: 'Lihat',
          onPressed: () {
            if (single && hasNotificationTarget(first)) {
              _markRead(first);
              openNotificationTarget(
                  context, widget.service, widget.session.logout, first);
            } else {
              _actions.openInboxSegment(kInboxNotifications);
            }
          },
        ),
      ));
  }

  /// Opening a notification from the toast reads it, like tapping its card does.
  Future<void> _markRead(NotificationItem item) async {
    _unread.value = (_unread.value - 1).clamp(0, 1 << 30);
    try {
      await widget.service.markNotificationRead(item.id);
    } catch (_) {
      // The next look at the server restores the real count.
    }
    if (mounted) _notificationsVersion.value++;
  }

  final List<StreamSubscription<PushMessage>> _pushSubs = [];

  /// The user tapped a push: open what it is about and read it.
  Future<void> _openFromPush(PushMessage m) async {
    if (!mounted) return;
    if (m.notificationId != null) {
      widget.service.markNotificationRead(m.notificationId!).catchError((_) {});
      _watcher.check();
    }
    if (m.type == 'leave_request' && m.leaveRequestId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LeaveDetailScreen(
              service: widget.service,
              onUnauthorized: widget.session.logout,
              id: m.leaveRequestId!)));
    } else if (m.type == 'facility_report' && m.facilityReportId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FacilityDetailScreen(
              service: widget.service,
              onUnauthorized: widget.session.logout,
              id: m.facilityReportId!)));
    } else if (m.type == 'student_incident' && m.studentIncidentId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(
              service: widget.service,
              onUnauthorized: widget.session.logout,
              id: m.studentIncidentId!)));
    } else if (m.type == 'meeting_minute' && m.meetingMinuteId != null) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MeetingMinuteDetailScreen(
              service: widget.service,
              onUnauthorized: widget.session.logout,
              id: m.meetingMinuteId!)));
    } else if (m.type != null) {
      _actions.openInboxSegment(kInboxNotifications);
    }
  }

  @override
  void initState() {
    super.initState();
    _watcher.start();
    _pushSubs
      // The system shows nothing while the app is open: look right away so the
      // toast appears now instead of at the next 45-second tick.
      ..add(widget.push.onForeground.listen((_) => _watcher.check()))
      ..add(widget.push.onOpened.listen(_openFromPush));
    widget.push.initialMessage().then((m) {
      if (m != null) _openFromPush(m);
    });
  }

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
    for (final s in _pushSubs) {
      s.cancel();
    }
    _watcher.stop();
    _notificationsVersion.dispose();
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
        notificationsRefresh: _notificationsVersion,
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
