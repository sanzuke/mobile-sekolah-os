import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/surface_cards.dart';
import 'lesson_attendance_screen.dart';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Presensi siswa": the teacher's lessons of one day, with back-to-back JP of
/// the same class merged into one entry. The server accepts recording up to 7
/// days back, so day navigation is limited to that window.
class LessonsScreen extends StatefulWidget {
  const LessonsScreen({
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
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
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
    final canPrev = _date.isAfter(oldest);
    final canNext = _date.isBefore(_today);
    return Scaffold(
      appBar: AppBar(title: const Text('Presensi siswa')),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                  tooltip: 'Hari sebelumnya',
                  onPressed: canPrev ? () => _shift(-1) : null,
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(
                  formatDate(isoDate(_date)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                  tooltip: 'Hari berikutnya',
                  onPressed: canNext ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Expanded(
            child: AsyncView<List<LessonBlock>>(
              key: _viewKey,
              load: () async => buildLessonBlocks(
                  await widget.service.lessons(date: isoDate(_date))),
              onUnauthorized: widget.onUnauthorized,
              builder: (context, blocks) {
                if (blocks.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 60),
                      Icon(Icons.event_busy, size: 48),
                      SizedBox(height: 12),
                      Text('Tidak ada jadwal mengajar pada tanggal ini.',
                          textAlign: TextAlign.center),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: blocks.length,
                  itemBuilder: (context, i) => _BlockTile(
                    block: blocks[i],
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LessonAttendanceScreen(
                          service: widget.service,
                          onUnauthorized: widget.onUnauthorized,
                          block: blocks[i],
                          date: isoDate(_date),
                        ),
                      ));
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

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block, required this.onTap});

  final LessonBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (block.state) {
      'submitted' => (block.summary ?? 'Tersimpan', const Color(0xFF15803D)),
      'partial' => ('Sebagian JP', const Color(0xFFB45309)),
      _ => ('Belum presensi', const Color(0xFFB45309)),
    };
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(block.jpLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                      ),
                      const SizedBox(width: 8),
                      // Status gets its own chip so it never squeezes the subject.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(block.subject,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${block.className} · ${block.start} – ${block.end}',
                      style: Theme.of(context).textTheme.bodyMedium),
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
