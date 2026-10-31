import 'package:flutter/foundation.dart';

import '../services/teacher_service.dart';

const kTabHome = 0;
const kTabSchedule = 1;
const kTabInbox = 2;
const kTabAccount = 3;

const kInboxAnnouncements = 0;
const kInboxNotifications = 1;
const kInboxReports = 2;

/// What screens opened from the shell need: the API, the shared unread badge,
/// and ways to switch tabs. Keeps child screens free of the shell's state.
class ShellActions {
  const ShellActions({
    required this.service,
    required this.unread,
    required this.onUnauthorized,
    required this.goTab,
    required this.openInboxSegment,
  });

  final TeacherService service;
  final ValueNotifier<int> unread;
  final VoidCallback onUnauthorized;
  final void Function(int tab) goTab;
  final void Function(int segment) openInboxSegment;
}
