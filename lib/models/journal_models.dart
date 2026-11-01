// Mirrors `/api/v1/teacher/schedules/{id}/journal` (`LessonJournalController` in admin-siakad)
// and the `journal` entry that `/lessons` carries for every class.

import 'teacher_models.dart';

/// One lesson's stored journal, as `GET /schedules/{id}/journal` returns it.
class LessonJournalData {
  const LessonJournalData({
    required this.submitted,
    required this.editable,
    this.topic,
    this.material,
    this.notes,
    this.lockedMessage,
  });

  final bool submitted;

  /// False once the correction window (7 days) has closed, or the date does not fit the schedule.
  final bool editable;
  final String? topic;
  final String? material;
  final String? notes;
  final String? lockedMessage;

  factory LessonJournalData.fromJson(Map<String, dynamic> j) {
    final x = j['journal'] as Map<String, dynamic>? ?? const {};
    return LessonJournalData(
      submitted: x['state'] == 'submitted',
      editable: x['editable'] as bool? ?? false,
      topic: x['topic'] as String?,
      material: x['material'] as String?,
      notes: x['notes'] as String?,
      lockedMessage: x['locked_message'] as String?,
    );
  }
}

/// What one journal covers: a lesson, which may span several classes (a kelas gabungan) and several
/// back-to-back JP. The teacher writes it once; the app saves it to every schedule row in [scheduleIds].
class JournalTarget {
  const JournalTarget({
    required this.subject,
    required this.classNames,
    required this.jpLabel,
    required this.start,
    required this.end,
    required this.scheduleIds,
    required this.writtenScheduleIds,
    this.topic,
  });

  final String subject;

  /// "8D" or "9A + 9B".
  final String classNames;
  final String jpLabel;
  final String start;
  final String end;

  /// Every class-JP this journal is saved against.
  final List<int> scheduleIds;

  /// The subset that already has a journal.
  final List<int> writtenScheduleIds;

  /// The topic of one written entry, for the list.
  final String? topic;

  String get timeRange => '$start – $end';

  /// pending | partial | submitted
  String get state {
    if (writtenScheduleIds.isEmpty) return 'pending';
    return writtenScheduleIds.length == scheduleIds.length
        ? 'submitted'
        : 'partial';
  }

  /// The row to read the existing text from, when anything was written.
  int? get prefillScheduleId => writtenScheduleIds.firstOrNull;
}

JournalTarget _targetOf(List<LessonBlock> blocks) {
  final first = blocks.first;
  final sessions = [for (final b in blocks) ...b.sessions];
  final written = sessions.where((s) => s.journalSubmitted).toList();
  final classes = blocks.map((b) => b.className).toSet().toList()..sort();
  final firstJp = blocks.map((b) => b.firstJp).reduce((a, b) => a < b ? a : b);
  final lastJp = blocks.map((b) => b.lastJp).reduce((a, b) => a > b ? a : b);
  return JournalTarget(
    subject: first.subject,
    classNames: classes.join(' + '),
    jpLabel: firstJp == lastJp ? 'JP $firstJp' : 'JP $firstJp–$lastJp',
    start: blocks
        .map((b) => b.start)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b),
    end: blocks.map((b) => b.end).reduce((a, b) => a.compareTo(b) >= 0 ? a : b),
    scheduleIds: [for (final s in sessions) s.scheduleId],
    writtenScheduleIds: [for (final s in written) s.scheduleId],
    topic: written.map((s) => s.journalTopic).nonNulls.firstOrNull,
  );
}

/// The day's lessons as journal targets: the same subject over the same JP range in several classes
/// (a kelas gabungan) is one target. Ordered by time, then class.
List<JournalTarget> journalTargets(List<LessonBlock> blocks) {
  final byLesson = <String, List<LessonBlock>>{};
  for (final b in blocks) {
    byLesson
        .putIfAbsent('${b.subject}|${b.firstJp}|${b.lastJp}', () => [])
        .add(b);
  }
  final groups = byLesson.values.toList()
    ..sort((a, b) {
      final byJp = a.first.firstJp.compareTo(b.first.firstJp);
      return byJp != 0 ? byJp : a.first.subject.compareTo(b.first.subject);
    });
  return [for (final g in groups) _targetOf(g)];
}

/// The journal target of one schedule card (a [LessonGroup]), from the day's blocks;
/// null when nothing matches (the day's lessons have not loaded, or the card has no class-JP in them).
JournalTarget? journalForGroup(LessonGroup group, List<LessonBlock> blocks) {
  final matching = blocks
      .where(
        (b) =>
            b.subject == group.subject &&
            b.firstJp >= group.firstJp &&
            b.lastJp <= group.lastJp,
      )
      .toList();
  return matching.isEmpty ? null : _targetOf(matching);
}
