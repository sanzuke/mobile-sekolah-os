import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import 'facility_detail_screen.dart';
import 'facility_reports_screen.dart';
import 'leave_detail_screen.dart';
import 'incident_detail_screen.dart';
import 'incidents_screen.dart';
import 'leave_requests_screen.dart';
import 'meeting_minute_detail_screen.dart';
import 'meeting_minutes_screen.dart';

/// Whether tapping [item] goes anywhere (otherwise it only informs).
bool hasNotificationTarget(NotificationItem item) =>
    item.target?.type == 'leave_request' ||
    item.target?.type == 'meeting_minute' ||
    item.target?.type == 'student_incident' ||
    item.target?.type == 'facility_report';

/// Opens what a notification is about. A leave decision opens that request; one
/// stored before the id existed opens the list.
void openNotificationTarget(
  BuildContext context,
  TeacherService service,
  VoidCallback onUnauthorized,
  NotificationItem item,
) {
  final target = item.target;
  if (target == null || !hasNotificationTarget(item)) return;
  if (target.type == 'facility_report') {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => target.id == null
          ? FacilityReportsScreen(
              service: service, onUnauthorized: onUnauthorized)
          : FacilityDetailScreen(
              service: service, onUnauthorized: onUnauthorized, id: target.id!),
    ));
    return;
  }
  if (target.type == 'student_incident') {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => target.id == null
          ? IncidentsScreen(service: service, onUnauthorized: onUnauthorized)
          : IncidentDetailScreen(
              service: service, onUnauthorized: onUnauthorized, id: target.id!),
    ));
    return;
  }
  if (target.type == 'meeting_minute') {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => target.id == null
          ? MeetingMinutesScreen(
              service: service, onUnauthorized: onUnauthorized)
          : MeetingMinuteDetailScreen(
              service: service, onUnauthorized: onUnauthorized, id: target.id!),
    ));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => target.id == null
        ? LeaveRequestsScreen(service: service, onUnauthorized: onUnauthorized)
        : LeaveDetailScreen(
            service: service, onUnauthorized: onUnauthorized, id: target.id!),
  ));
}
