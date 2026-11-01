// Mirrors `/api/v1/teacher/facility-reports*` (`FacilityReportController` in admin-siakad).

/// `category` values the server accepts.
const facilityCategories = <(String, String)>[
  ('bangunan', 'Bangunan'),
  ('listrik', 'Listrik'),
  ('air', 'Air'),
  ('furnitur', 'Furnitur'),
  ('elektronik', 'Elektronik'),
  ('kebersihan', 'Kebersihan'),
  ('lainnya', 'Lainnya'),
];

const facilityPriorities = <(String, String)>[
  ('rendah', 'Rendah'),
  ('sedang', 'Sedang'),
  ('mendesak', 'Mendesak'),
];

const facilityStatuses = <(String?, String)>[
  (null, 'Semua'),
  ('reported', 'Dilaporkan'),
  ('handling', 'Ditangani'),
  ('resolved', 'Selesai'),
  ('rejected', 'Ditolak'),
  ('cancelled', 'Dibatalkan'),
];

class FacilityReport {
  const FacilityReport({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.priority,
    required this.priorityLabel,
    required this.location,
    required this.status,
    required this.statusLabel,
    required this.canEdit,
    required this.createdAt,
    this.publicNote,
    this.description,
  });

  final int id;
  final String category;
  final String categoryLabel;
  final String priority;
  final String priorityLabel;
  final String location;
  final String status;
  final String statusLabel;
  final bool canEdit;

  /// `YYYY-MM-DD HH:mm` (WIB).
  final String createdAt;

  /// What the handler wrote for the reporter; never the internal note.
  final String? publicNote;

  // Detail only.
  final String? description;

  bool get isUrgent => priority == 'mendesak';

  factory FacilityReport.fromJson(Map<String, dynamic> j) => FacilityReport(
    id: j['id'] as int,
    category: j['category'] as String? ?? 'lainnya',
    categoryLabel: j['category_label'] as String? ?? '',
    priority: j['priority'] as String? ?? 'sedang',
    priorityLabel: j['priority_label'] as String? ?? '',
    location: j['location'] as String? ?? '',
    status: j['status'] as String? ?? 'reported',
    statusLabel: j['status_label'] as String? ?? '',
    canEdit: j['can_edit'] as bool? ?? false,
    createdAt: j['created_at'] as String? ?? '',
    publicNote: j['public_note'] as String?,
    description: j['description'] as String?,
  );
}

class FacilityReportPage {
  const FacilityReportPage({required this.items, required this.lastPage});

  final List<FacilityReport> items;
  final int lastPage;
}
