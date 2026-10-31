import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';

/// Keeps the unread badge fresh and reports notifications that arrived while the
/// app is open: it looks every [interval] while in the foreground, and right away
/// when the app comes back from the background. (Not a push: nothing arrives while
/// the app is closed.)
///
/// The first successful look only records what is already there, so opening the
/// app never announces old notifications.
class NotificationWatcher with WidgetsBindingObserver {
  NotificationWatcher({
    required this.service,
    required this.unread,
    required this.onNew,
    required this.onUnauthorized,
    this.interval = const Duration(seconds: 45),
  });

  final TeacherService service;
  final ValueNotifier<int> unread;

  /// Unread notifications not seen before, newest first.
  final void Function(List<NotificationItem> fresh) onNew;
  final VoidCallback onUnauthorized;
  final Duration interval;

  final Set<String> _seen = {};
  bool _seeded = false;
  bool _busy = false;
  Timer? _timer;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _schedule();
    check();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      check();
    } else {
      // No point polling a backgrounded app (and it saves battery).
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> check() async {
    if (_busy) return;
    _busy = true;
    try {
      final page = await service.notifications(page: 1);
      unread.value = page.unreadCount;
      final fresh = [
        for (final n in page.items)
          if (!n.isRead && !_seen.contains(n.id)) n,
      ];
      _seen.addAll(page.items.map((n) => n.id));
      if (_seeded && fresh.isNotEmpty) onNew(fresh);
      _seeded = true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) onUnauthorized();
    } catch (_) {
      // Offline or server down: try again at the next tick.
    } finally {
      _busy = false;
    }
  }
}
