// Mirrors `/api/v1/teacher/rpp*` (`RppController` in admin-siakad).

/// Where one week's RPP stands. `none` = nothing uploaded yet.
const rppStates = {'none', 'draft', 'submitted', 'approved', 'rejected'};

/// One week of RPP (Monday–Sunday), with the document if one was uploaded.
class RppWeek {
  const RppWeek({
    this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.isCurrent,
    required this.state,
    this.title,
    this.description,
    this.fileExtension,
    this.reviewNotes,
    required this.canSubmit,
    required this.due,
    required this.overdue,
  });

  final int? id;

  /// Monday, `YYYY-MM-DD`.
  final String weekStart;
  final String weekEnd;
  final bool isCurrent;

  /// none | draft | submitted | approved | rejected
  final String state;
  final String? title;
  final String? description;
  final String? fileExtension;

  /// The head's reason, shown after a rejection.
  final String? reviewNotes;

  /// False once approved, and for weeks outside last/this/next week.
  final bool canSubmit;

  /// The deadline (the Sunday of the week), `YYYY-MM-DD`.
  final String due;

  /// Past the deadline and still not handed in; only a label, uploading stays open.
  final bool overdue;

  bool get hasFile => id != null;

  factory RppWeek.fromJson(Map<String, dynamic> j) => RppWeek(
    id: j['id'] as int?,
    weekStart: j['week_start'] as String? ?? '',
    weekEnd: j['week_end'] as String? ?? '',
    isCurrent: j['is_current'] as bool? ?? false,
    state: j['state'] as String? ?? 'none',
    title: j['title'] as String?,
    description: j['description'] as String?,
    fileExtension: j['file_extension'] as String?,
    reviewNotes: j['review_notes'] as String?,
    canSubmit: j['can_submit'] as bool? ?? false,
    due: j['due'] as String? ?? '',
    overdue: j['overdue'] as bool? ?? false,
  );
}

class RppPage {
  const RppPage({required this.weeks, this.maxSizeMb = 10});

  final List<RppWeek> weeks;
  final int maxSizeMb;

  int get maxBytes => maxSizeMb * 1024 * 1024;
}

/// `duties.rpp` of `/home`: this week's RPP.
class RppDuty {
  const RppDuty({
    required this.weekStart,
    required this.state,
    required this.due,
    required this.overdue,
  });

  final String weekStart;
  final String state;
  final String due;
  final bool overdue;

  factory RppDuty.fromJson(Map<String, dynamic> j) => RppDuty(
    weekStart: j['week_start'] as String? ?? '',
    state: j['state'] as String? ?? 'none',
    due: j['due'] as String? ?? '',
    overdue: j['overdue'] as bool? ?? false,
  );
}

/// Status text and tone for a week. [tone]: ok | warn | bad | muted.
({String label, String tone}) rppStatus(String state, {bool overdue = false}) =>
    switch (state) {
      'approved' => (label: 'Disetujui', tone: 'ok'),
      'submitted' => (label: 'Menunggu review', tone: 'warn'),
      'draft' => (label: 'Draf', tone: 'warn'),
      'rejected' => (label: 'Ditolak', tone: 'bad'),
      _ =>
        overdue
            ? (label: 'Terlambat', tone: 'bad')
            : (label: 'Belum diunggah', tone: 'muted'),
    };
