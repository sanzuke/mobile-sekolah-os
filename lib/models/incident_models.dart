// Mirrors `/api/v1/teacher/incidents*` (`StudentIncidentController` in admin-siakad).

/// `category` values: the category decides who receives the report.
const incidentCategories = <(String, String, String)>[
  ('discipline', 'Pelanggaran', 'Diteruskan ke BK'),
  ('medical', 'Kesehatan', 'Diteruskan ke UKS'),
];

const incidentSeverities = <(String, String)>[
  ('ringan', 'Ringan'),
  ('sedang', 'Sedang'),
  ('berat', 'Berat'),
];

const incidentStatuses = <(String?, String)>[
  (null, 'Semua'),
  ('reported', 'Dilaporkan'),
  ('handling', 'Ditangani'),
  ('resolved', 'Selesai'),
  ('cancelled', 'Dibatalkan'),
];

/// A student to pick (`student-options`) or one on a report.
class IncidentStudent {
  const IncidentStudent({
    required this.id,
    required this.name,
    this.gradeName,
    this.nis,
  });

  final int id;
  final String name;
  final String? gradeName;
  final String? nis;

  factory IncidentStudent.fromOption(Map<String, dynamic> j) => IncidentStudent(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    nis: j['nis'] as String?,
    gradeName: (j['grade'] as Map<String, dynamic>?)?['name'] as String?,
  );

  factory IncidentStudent.fromReport(Map<String, dynamic> j) => IncidentStudent(
    id: j['id'] as int? ?? 0,
    name: j['name'] as String? ?? '',
    gradeName: j['grade_name'] as String?,
  );
}

class StudentIncident {
  const StudentIncident({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.severity,
    required this.severityLabel,
    required this.occurredAt,
    required this.status,
    required this.statusLabel,
    required this.canEdit,
    required this.students,
    this.publicNote,
    this.location,
    this.description,
    this.actionTaken,
  });

  final int id;
  final String category;
  final String categoryLabel;
  final String severity;
  final String severityLabel;

  /// `YYYY-MM-DD HH:mm` (WIB).
  final String occurredAt;
  final String status;
  final String statusLabel;
  final bool canEdit;
  final List<IncidentStudent> students;
  final String? publicNote;

  // Detail only.
  final String? location;
  final String? description;
  final String? actionTaken;

  bool get isMedical => category == 'medical';

  factory StudentIncident.fromJson(Map<String, dynamic> j) => StudentIncident(
    id: j['id'] as int,
    category: j['category'] as String? ?? 'discipline',
    categoryLabel: j['category_label'] as String? ?? '',
    severity: j['severity'] as String? ?? 'ringan',
    severityLabel: j['severity_label'] as String? ?? '',
    occurredAt: j['occurred_at'] as String? ?? '',
    status: j['status'] as String? ?? 'reported',
    statusLabel: j['status_label'] as String? ?? '',
    canEdit: j['can_edit'] as bool? ?? false,
    publicNote: j['public_note'] as String?,
    location: j['location'] as String?,
    description: j['description'] as String?,
    actionTaken: j['action_taken'] as String?,
    students: (j['students'] as List<dynamic>? ?? [])
        .map((e) => IncidentStudent.fromReport(e as Map<String, dynamic>))
        .toList(),
  );
}

class StudentIncidentPage {
  const StudentIncidentPage({required this.items, required this.lastPage});

  final List<StudentIncident> items;
  final int lastPage;
}
