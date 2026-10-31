import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import 'leave_detail_screen.dart';
import 'leave_requests_screen.dart';

/// Whether tapping [item] goes anywhere (otherwise it only informs).
bool hasNotificationTarget(NotificationItem item) =>
    item.target?.type == 'leave_request';

/// Opens what a notification is about. A leave decision opens that request; one
/// stored before the id existed opens the list.
void openNotificationTarget(
  BuildContext context,
  TeacherService service,
  VoidCallback onUnauthorized,
  NotificationItem item,
) {
  final target = item.target;
  if (target == null || target.type != 'leave_request') return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => target.id == null
        ? LeaveRequestsScreen(service: service, onUnauthorized: onUnauthorized)
        : LeaveDetailScreen(
            service: service, onUnauthorized: onUnauthorized, id: target.id!),
  ));
}
