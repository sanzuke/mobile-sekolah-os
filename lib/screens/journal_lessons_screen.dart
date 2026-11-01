import 'package:flutter/material.dart';

import '../models/journal_models.dart';
import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/surface_cards.dart';
import 'journal_form_screen.dart';
import 'lessons_screen.dart' show isoDate;

/// "Jurnal mengajar": the teacher's lessons of one day, each with whether its journal is written.
/// A lesson shared by several classes is one entry. The server accepts a journal up to 7 days back,
/// so day navigation is limited to that window (the same as Presensi).
class JournalLessonsScreen extends StatefulWidget {
  const JournalLessonsScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.date,
    this.today,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  /// `YYYY-MM-DD` to open on.
  final String date;

  /// Injectable "today" for tests; defaults to the device clock.
  final DateTime? today;

  @override
  State<JournalLessonsScreen> createState() => _JournalLessonsScreenState();
}

class _JournalLessonsScreenState extends State<JournalLessonsScreen> {
  static const _windowDays = 7;

  late DateTime _date;
  late final DateTime _today;
  Key _viewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _date = DateTime.tryParse(widget.date) ?? _today;
  }

  void _shift(int days) {
    setState(() {
      _date = _date.add(Duration(days: days));
      _viewKey = UniqueKey();
    });
  }

  void _reload() => setState(() => _viewKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final oldest = _today.subtract(const Duration(days: _windowDays));
    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal mengajar')),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Hari sebelumnya',
                onPressed: _date.isAfter(oldest) ? () => _shift(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  formatDate(isoDate(_date)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Hari berikutnya',
                onPressed: _date.isBefore(_today) ? () => _shift(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Expanded(
            child: AsyncView<List<JournalTarget>>(
              key: _viewKey,
              load: () async => journalTargets(
                buildLessonBlocks(
                  await widget.service.lessons(date: isoDate(_date)),
                ),
              ),
              onUnauthorized: widget.onUnauthorized,
              builder: (context, targets) {
                if (targets.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 60),
                      Icon(Icons.event_busy, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Tidak ada jadwal mengajar pada tanggal ini.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: targets.length,
                  itemBuilder: (context, i) => _TargetTile(
                    target: targets[i],
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JournalFormScreen(
                            service: widget.service,
                            onUnauthorized: widget.onUnauthorized,
                            target: targets[i],
                            date: isoDate(_date),
                          ),
                        ),
                      );
                      if (mounted) _reload();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The small status chip for a journal, shared with the schedule card.
class JournalChip extends StatelessWidget {
  const JournalChip(this.state, {super.key});

  /// pending | partial | submitted
  final String state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'submitted' => ('Jurnal terisi', const Color(0xFF15803D)),
      'partial' => ('Jurnal sebagian', const Color(0xFFB45309)),
      _ => ('Belum jurnal', const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target, required this.onTap});

  final JournalTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          target.jpLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      JournalChip(target.state),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    target.subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${target.classNames} · ${target.timeRange}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if ((target.topic ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      target.topic!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
