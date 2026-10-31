// Mirrors `/api/v1/teacher/meeting-minutes*` (`MeetingMinuteController` in admin-siakad).

/// `category` values accepted by the API, with their labels.
const meetingCategories = <(String, String)>[
  ('staff', 'Rapat staf/guru'),
  ('jenjang', 'Rapat jenjang'),
  ('komite', 'Rapat komite'),
  ('lainnya', 'Lainnya'),
];

/// A teacher to pick as attendee or task owner (`attendee-options`).
class TeacherOption {
  const TeacherOption({required this.id, required this.name});

  final int id;
  final String name;

  factory TeacherOption.fromJson(Map<String, dynamic> j) =>
      TeacherOption(id: j['id'] as int, name: j['name'] as String? ?? '');
}

/// One person at the meeting. [teacherId] is null for a guest (name only).
class MeetingAttendee {
  const MeetingAttendee({
    this.teacherId,
    required this.name,
    this.attended = true,
  });

  final int? teacherId;
  final String name;
  final bool attended;

  factory MeetingAttendee.fromJson(Map<String, dynamic> j) => MeetingAttendee(
    teacherId: j['teacher_id'] as int?,
    name: j['name'] as String? ?? '',
    attended: j['attended'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    if (teacherId != null) 'teacher_id': teacherId,
    'name': name,
    'attended': attended,
  };
}

/// A follow-up decided in the meeting: what, who, by when.
class MeetingAction {
  const MeetingAction({
    this.id,
    required this.description,
    this.assignee,
    this.dueDate,
    this.done = false,
    this.canToggle = false,
  });

  final int? id;
  final String description;
  final TeacherOption? assignee;

  /// `YYYY-MM-DD`.
  final String? dueDate;
  final bool done;

  /// Whether this viewer may tick it (the server decides; see the API).
  final bool canToggle;

  factory MeetingAction.fromJson(Map<String, dynamic> j) => MeetingAction(
    id: j['id'] as int?,
    description: j['description'] as String? ?? '',
    assignee: j['assignee'] is Map<String, dynamic>
        ? TeacherOption.fromJson(j['assignee'] as Map<String, dynamic>)
        : null,
    dueDate: j['due_date'] as String?,
    done: j['done'] as bool? ?? false,
    canToggle: j['can_toggle'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'description': description,
    if (assignee != null) 'assignee_teacher_id': assignee!.id,
    if (dueDate != null) 'due_date': dueDate,
  };
}

class MeetingMinute {
  const MeetingMinute({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.heldOn,
    this.startTime,
    this.endTime,
    required this.status,
    required this.isAuthor,
    this.attendeeCount,
    this.actionCount,
    this.openActionCount,
    this.authorName,
    this.location,
    this.agenda,
    this.discussion,
    this.decisions,
    this.attendees = const [],
    this.actions = const [],
  });

  final int id;
  final String title;
  final String category;
  final String categoryLabel;

  /// `YYYY-MM-DD`.
  final String heldOn;

  /// `HH:mm`.
  final String? startTime;
  final String? endTime;

  /// `draft` or `final`.
  final String status;
  final bool isAuthor;

  // List rows only.
  final int? attendeeCount;
  final int? actionCount;
  final int? openActionCount;

  // Detail only.
  final String? authorName;
  final String? location;
  final String? agenda;
  final String? discussion;
  final String? decisions;
  final List<MeetingAttendee> attendees;
  final List<MeetingAction> actions;

  bool get isFinal => status == 'final';
  bool get isDraft => !isFinal;

  factory MeetingMinute.fromJson(Map<String, dynamic> j) => MeetingMinute(
    id: j['id'] as int,
    title: j['title'] as String? ?? '',
    category: j['category'] as String? ?? 'lainnya',
    categoryLabel: j['category_label'] as String? ?? '',
    heldOn: j['held_on'] as String? ?? '',
    startTime: j['start_time'] as String?,
    endTime: j['end_time'] as String?,
    status: j['status'] as String? ?? 'draft',
    isAuthor: j['is_author'] as bool? ?? false,
    attendeeCount: j['attendee_count'] as int?,
    actionCount: j['action_count'] as int?,
    openActionCount: j['open_action_count'] as int?,
    authorName: (j['author'] as Map<String, dynamic>?)?['name'] as String?,
    location: j['location'] as String?,
    agenda: j['agenda'] as String?,
    discussion: j['discussion'] as String?,
    decisions: j['decisions'] as String?,
    attendees: (j['attendees'] as List<dynamic>? ?? [])
        .map((e) => MeetingAttendee.fromJson(e as Map<String, dynamic>))
        .toList(),
    actions: (j['actions'] as List<dynamic>? ?? [])
        .map((e) => MeetingAction.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class MeetingMinutePage {
  const MeetingMinutePage({required this.items, required this.lastPage});

  final List<MeetingMinute> items;
  final int lastPage;
}
