import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/lesson_tile.dart';
import 'lessons_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  /// Any date inside the week being shown; null = this week.
  DateTime? _anchor;
  int? _selectedDay;
  Key _viewKey = UniqueKey();

  String? get _anchorIso => _anchor == null
      ? null
      : '${_anchor!.year.toString().padLeft(4, '0')}-'
          '${_anchor!.month.toString().padLeft(2, '0')}-'
          '${_anchor!.day.toString().padLeft(2, '0')}';

  /// Attendance can be recorded for today and up to 7 days back (server rule).
  bool _canRecord(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !d.isAfter(today) &&
        !d.isBefore(today.subtract(const Duration(days: 7)));
  }

  void _shiftWeek(ScheduleData data, int weeks) {
    final base = DateTime.tryParse(data.week?.start ?? '') ?? DateTime.now();
    setState(() {
      _anchor = base.add(Duration(days: 7 * weeks));
      _selectedDay = null;
      _viewKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<ScheduleData>(
      key: _viewKey,
      load: () => widget.service.schedule(date: _anchorIso),
      onUnauthorized: widget.onUnauthorized,
      builder: (context, data) {
        if (data.days.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _WeekHeader(
                  data: data,
                  onPrev: () => _shiftWeek(data, -1),
                  onNext: () => _shiftWeek(data, 1)),
              const SizedBox(height: 40),
              const Center(child: Text('Tidak ada jadwal pada pekan ini.')),
            ],
          );
        }

        final selected = data.days.firstWhere(
          (d) => d.day == _selectedDay,
          orElse: () => data.days.firstWhere((d) => d.isToday,
              orElse: () => data.days.first),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeekHeader(
                data: data,
                onPrev: () => _shiftWeek(data, -1),
                onNext: () => _shiftWeek(data, 1)),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in data.days)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: d.day == selected.day,
                        onSelected: (_) => setState(() => _selectedDay = d.day),
                        label: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(d.name,
                                style: const TextStyle(fontSize: 12)),
                            Text(formatDate(d.date, withYear: false),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (selected.lessons.isNotEmpty && _canRecord(selected.date))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: Text('Presensi ${formatDate(selected.date, withYear: false)}'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LessonsScreen(
                      service: widget.service,
                      onUnauthorized: widget.onUnauthorized,
                      date: selected.date,
                    ),
                  )),
                ),
              ),
            if (selected.lessons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    selected.state == 'unpublished'
                        ? 'Jadwal Anda belum dipublikasikan.'
                        : 'Tidak ada jadwal di hari ini.',
                  ),
                ),
              )
            else
              for (final l in selected.lessons) LessonTile(lesson: l),
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader(
      {required this.data, required this.onPrev, required this.onNext});

  final ScheduleData data;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final w = data.week;
    final title = w == null
        ? 'Jadwal mengajar'
        : w.number == null
            ? 'Di luar masa semester'
            : 'Pekan ${w.number}/${w.total}';
    return Row(
      children: [
        IconButton(
            tooltip: 'Pekan sebelumnya',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (w != null)
                Text('${formatRange(w.start, w.end)} · ${w.sessionsPerWeek} sesi',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
            tooltip: 'Pekan berikutnya',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}
