// Mirrors `/api/v1/teacher/leave-requests*` (`LeaveRequestController` in admin-siakad).

/// `type` values accepted by the API, with the label the API returns for them.
const leaveTypes = <(String, String)>[
  ('sick', 'Sakit'),
  ('personal', 'Izin keperluan'),
  ('leave', 'Cuti'),
  ('official', 'Dinas luar'),
];

/// `status` filter values, in the order of the chips.
const leaveStatuses = <(String?, String)>[
  (null, 'Semua'),
  ('pending', 'Menunggu'),
  ('approved', 'Disetujui'),
  ('rejected', 'Ditolak'),
  ('cancelled', 'Dibatalkan'),
];

class LeaveLesson {
  const LeaveLesson({
    required this.sessionNumber,
    required this.start,
    required this.end,
    required this.subject,
    required this.grade,
  });

  final int sessionNumber;
  final String start;
  final String end;
  final String subject;
  final String grade;

  factory LeaveLesson.fromJson(Map<String, dynamic> j) => LeaveLesson(
        sessionNumber: j['session_number'] as int? ?? 0,
        start: j['start'] as String? ?? '',
        end: j['end'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        grade: j['grade'] as String? ?? '',
      );
}

/// The lessons of one date that a leave would leave uncovered.
class LeaveDay {
  const LeaveDay({required this.date, this.dayName, required this.lessons});

  final String date;
  final String? dayName;
  final List<LeaveLesson> lessons;

  factory LeaveDay.fromJson(Map<String, dynamic> j) => LeaveDay(
        date: j['date'] as String? ?? '',
        dayName: j['day_name'] as String?,
        lessons: (j['lessons'] as List<dynamic>? ?? [])
            .map((e) => LeaveLesson.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LeaveApproval {
  const LeaveApproval({
    required this.jenjang,
    required this.label,
    required this.status,
    this.decidedBy,
    this.decidedAt,
    this.note,
  });

  final String jenjang;
  final String label;

  /// pending | approved | rejected
  final String status;
  final String? decidedBy;
  final String? decidedAt;
  final String? note;

  factory LeaveApproval.fromJson(Map<String, dynamic> j) => LeaveApproval(
        jenjang: j['jenjang'] as String? ?? '',
        label: j['label'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        decidedBy: j['decided_by'] as String?,
        decidedAt: j['decided_at'] as String?,
        note: j['note'] as String?,
      );
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.type,
    required this.typeLabel,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.statusLabel,
    this.submittedAt,
    this.decidedAt,
    this.decisionNote,
    this.hasAttachment = false,
    this.attachmentName,
    this.canCancel = false,
    this.days = const [],
    this.approvals = const [],
  });

  final int id;
  final String type;
  final String typeLabel;
  final String startDate;
  final String endDate;
  final String reason;

  /// pending | approved | rejected | cancelled
  final String status;
  final String statusLabel;
  final String? submittedAt;
  final String? decidedAt;
  final String? decisionNote;
  final bool hasAttachment;
  final String? attachmentName;

  /// Detail only.
  final bool canCancel;
  final List<LeaveDay> days;
  final List<LeaveApproval> approvals;

  bool get isPending => status == 'pending';

  int get lessonCount => days.fold(0, (n, d) => n + d.lessons.length);

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
        id: j['id'] as int,
        type: j['type'] as String? ?? '',
        typeLabel: j['type_label'] as String? ?? '',
        startDate: j['start_date'] as String? ?? '',
        endDate: j['end_date'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        statusLabel: j['status_label'] as String? ?? '',
        submittedAt: j['submitted_at'] as String?,
        decidedAt: j['decided_at'] as String?,
        decisionNote: j['decision_note'] as String?,
        hasAttachment: j['has_attachment'] as bool? ?? false,
        attachmentName: j['attachment_name'] as String?,
        canCancel: j['can_cancel'] as bool? ?? false,
        days: (j['lessons'] as List<dynamic>? ?? [])
            .map((e) => LeaveDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        approvals: (j['approvals'] as List<dynamic>? ?? [])
            .map((e) => LeaveApproval.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LeaveRequestPage {
  const LeaveRequestPage({
    required this.items,
    required this.lastPage,
    required this.pendingCount,
  });

  final List<LeaveRequest> items;
  final int lastPage;
  final int pendingCount;
}

/// `GET /leave-requests/preview`: what a request for these dates would affect.
class LeavePreview {
  const LeavePreview({
    required this.days,
    required this.lessonCount,
    required this.approvalsNeeded,
    required this.overlapsExisting,
  });

  final List<LeaveDay> days;
  final int lessonCount;

  /// Labels, e.g. `MTs (kelas 7–9)`.
  final List<String> approvalsNeeded;
  final bool overlapsExisting;

  factory LeavePreview.fromJson(Map<String, dynamic> j) => LeavePreview(
        days: (j['lessons'] as List<dynamic>? ?? [])
            .map((e) => LeaveDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        lessonCount: j['lesson_count'] as int? ?? 0,
        approvalsNeeded: (j['approvals_needed'] as List<dynamic>? ?? [])
            .map((e) => (e as Map<String, dynamic>)['label'] as String? ?? '')
            .toList(),
        overlapsExisting: j['overlaps_existing'] as bool? ?? false,
      );
}
