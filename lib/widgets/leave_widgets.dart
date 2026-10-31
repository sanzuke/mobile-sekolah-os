import 'package:flutter/material.dart';

import '../models/leave_models.dart';
import 'date_format.dart';

/// `31 Okt 2026`, or `26 Okt – 1 Nov 2026` for a range.
String leaveRange(String start, String end) =>
    start == end ? formatDate(start) : formatRange(start, end);

({Color bg, Color fg, IconData icon}) leaveStatusStyle(String status) =>
    switch (status) {
      'approved' => (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF166534),
          icon: Icons.check_circle_outline
        ),
      'rejected' => (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          icon: Icons.cancel_outlined
        ),
      'cancelled' => (
          bg: const Color(0xFFF1F5F9),
          fg: const Color(0xFF475569),
          icon: Icons.block
        ),
      _ => (
          bg: const Color(0xFFFEF3E2),
          fg: const Color(0xFF92400E),
          icon: Icons.hourglass_empty
        ),
    };

IconData leaveTypeIcon(String type) => switch (type) {
      'sick' => Icons.medical_services_outlined,
      'leave' => Icons.beach_access_outlined,
      'official' => Icons.work_outline,
      _ => Icons.event_busy_outlined,
    };

class LeaveStatusChip extends StatelessWidget {
  const LeaveStatusChip({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = leaveStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: s.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: s.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: s.fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Consecutive JP of the same subject and class, shown as one row ("JP 1–2").
class _LeaveBlock {
  _LeaveBlock(LeaveLesson l)
      : first = l.sessionNumber,
        last = l.sessionNumber,
        start = l.start,
        end = l.end,
        subject = l.subject,
        grade = l.grade;

  int first;
  int last;
  final String start;
  String end;
  final String subject;
  final String grade;

  String get jp => first == last ? 'JP $first' : 'JP $first–$last';

  bool absorbs(LeaveLesson l) =>
      l.subject == subject && l.grade == grade && l.sessionNumber == last + 1;
}

List<_LeaveBlock> _blocks(List<LeaveLesson> lessons) {
  final blocks = <_LeaveBlock>[];
  for (final l in lessons) {
    if (blocks.isNotEmpty && blocks.last.absorbs(l)) {
      blocks.last
        ..last = l.sessionNumber
        ..end = l.end;
    } else {
      blocks.add(_LeaveBlock(l));
    }
  }
  return blocks;
}

/// The affected lessons, one block per date.
class LeaveDaysList extends StatelessWidget {
  const LeaveDaysList({super.key, required this.days});

  final List<LeaveDay> days;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
                '${day.dayName != null ? '${day.dayName}, ' : ''}${formatDate(day.date)}',
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          for (final b in _blocks(day.lessons))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      width: 64,
                      child: Text(b.jp,
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b.subject} — ${b.grade}',
                            style: text.bodyMedium),
                        Text('${b.start}–${b.end}', style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
