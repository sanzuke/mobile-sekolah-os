import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/surface_cards.dart';
import 'lessons_screen.dart';
import '../widgets/one_line_label.dart';

const _dayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _dayLong = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// Jadwal as in the design: title and week summary, a row of day chips, then
/// one card per lesson with back-to-back JP merged ("JP 1–2") and the
/// Presensi / Jurnal / RPP shortcuts.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.now,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  /// Injectable clock for tests; defaults to the device clock.
  final DateTime? now;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  /// Any date inside the week being shown; null = this week.
  DateTime? _anchor;
  String? _selected; // ISO date
  Key _viewKey = UniqueKey();

  DateTime get _today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _shiftWeek(ScheduleData data, int weeks) {
    final base = DateTime.tryParse(data.week?.start ?? '') ?? _today;
    setState(() {
      _anchor = base.add(Duration(days: 7 * weeks));
      _selected = null;
      _viewKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<ScheduleData>(
      key: _viewKey,
      load: () => widget.service.schedule(date: _anchor == null ? null : isoDate(_anchor!)),
      onUnauthorized: widget.onUnauthorized,
      builder: (context, data) => _WeekView(
        data: data,
        today: _today,
        selected: _selected,
        service: widget.service,
        onUnauthorized: widget.onUnauthorized,
        onSelect: (iso) => setState(() => _selected = iso),
        onShiftWeek: (w) => _shiftWeek(data, w),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.data,
    required this.today,
    required this.selected,
    required this.service,
    required this.onUnauthorized,
    required this.onSelect,
    required this.onShiftWeek,
  });

  final ScheduleData data;
  final DateTime today;
  final String? selected;
  final TeacherService service;
  final VoidCallback onUnauthorized;
  final ValueChanged<String> onSelect;
  final ValueChanged<int> onShiftWeek;

  @override
  Widget build(BuildContext context) {
    final week = data.week;
    final start = DateTime.tryParse(week?.start ?? '');
    final text = Theme.of(context).textTheme;

    if (week == null || start == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Jadwal mengajar',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const EmptyState(
            icon: Icons.event_busy,
            title: 'Belum ada semester aktif',
            message: 'Jadwal akan muncul setelah semester diaktifkan.',
          ),
        ],
      );
    }

    // All seven dates of the week; a date the API did not return has no school.
    final dates = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final byDate = {for (final d in data.days) d.date: d};
    final todayIso = isoDate(today);

    String pick() {
      if (selected != null && dates.any((d) => isoDate(d) == selected)) {
        return selected!;
      }
      if (dates.any((d) => isoDate(d) == todayIso)) return todayIso;
      final firstWithLessons =
          dates.where((d) => (byDate[isoDate(d)]?.lessons ?? []).isNotEmpty);
      return isoDate(firstWithLessons.isNotEmpty ? firstWithLessons.first : dates.first);
    }

    final selectedIso = pick();
    final selectedDay = byDate[selectedIso];
    final selectedDate = DateTime.parse(selectedIso);
    final groups = groupLessons(selectedDay?.lessons ?? const []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Jadwal mengajar',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton(
                tooltip: 'Pekan sebelumnya',
                onPressed: () => onShiftWeek(-1),
                icon: const Icon(Icons.chevron_left)),
            IconButton(
                tooltip: 'Pekan berikutnya',
                onPressed: () => onShiftWeek(1),
                icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Text(
          [
            if (week.number != null) 'Pekan ${week.number}/${week.total}' else 'Di luar masa semester',
            formatRange(week.start, week.end),
            '${week.sessionsPerWeek} sesi',
          ].join(' · '),
          style: text.bodySmall,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final d in dates)
              Expanded(
                child: _DayChip(
                  weekday: _dayShort[d.weekday - 1],
                  day: d.day,
                  selected: isoDate(d) == selectedIso,
                  isToday: isoDate(d) == todayIso,
                  hasLessons: (byDate[isoDate(d)]?.lessons ?? []).isNotEmpty,
                  onTap: () => onSelect(isoDate(d)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '${_dayLong[selectedDate.weekday - 1]}, ${formatDate(selectedIso)}',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          EmptyState(
            icon: Icons.event_available_outlined,
            title: selectedDay == null
                ? 'Tidak ada kegiatan belajar'
                : selectedDay.state == 'unpublished'
                    ? 'Jadwal belum dipublikasikan'
                    : 'Tidak ada jadwal di hari ini',
            message: 'Pilih hari lain untuk melihat sesi mengajar.',
          )
        else
          _Sessions(
            groups: groups,
            iso: selectedIso,
            recordable: _recordable(selectedDate),
            service: service,
            onUnauthorized: onUnauthorized,
          ),
      ],
    );
  }

  /// Attendance can be recorded for today and up to 7 days back (server rule).
  bool _recordable(DateTime d) =>
      !d.isAfter(today) && !d.isBefore(today.subtract(const Duration(days: 7)));
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.hasLessons,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final bool selected;
  final bool isToday;
  final bool hasLessons;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected
        ? Colors.white
        : hasLessons
            ? const Color(0xFF0F172A)
            : const Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$weekday $day',
        child: InkWell(
          key: ValueKey('day-$day'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? scheme.primary
                    : isToday
                        ? scheme.primary
                        : const Color(0xFFE2E8F0),
                width: isToday && !selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(weekday,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
                const SizedBox(height: 2),
                Text('$day',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
                const SizedBox(height: 4),
                // A dot marks days that have lessons.
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasLessons
                        ? (selected ? Colors.white : scheme.primary)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lesson cards of the selected day. When attendance can still be recorded for
/// that date, it also asks `/lessons` for each card's attendance state.
class _Sessions extends StatefulWidget {
  const _Sessions({
    required this.groups,
    required this.iso,
    required this.recordable,
    required this.service,
    required this.onUnauthorized,
  });

  final List<LessonGroup> groups;
  final String iso;
  final bool recordable;
  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  State<_Sessions> createState() => _SessionsState();
}

class _SessionsState extends State<_Sessions> {
  List<LessonBlock>? _blocks;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void didUpdateWidget(_Sessions old) {
    super.didUpdateWidget(old);
    if (old.iso != widget.iso) {
      _blocks = null;
      _loadAttendance();
    }
  }

  Future<void> _loadAttendance() async {
    if (!widget.recordable) return;
    final iso = widget.iso;
    try {
      final lessons = await widget.service.lessons(date: iso);
      if (!mounted || iso != widget.iso) return;
      setState(() => _blocks = buildLessonBlocks(lessons));
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      // The chip is a nicety; the schedule itself still shows without it.
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final g in widget.groups)
          _SessionCard(
            group: g,
            attendance: _blocks == null ? null : attendanceForGroup(g, _blocks!),
            recordable: widget.recordable,
            onPresensi: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LessonsScreen(
                  service: widget.service,
                  onUnauthorized: widget.onUnauthorized,
                  date: widget.iso,
                ),
              ));
              if (mounted) _loadAttendance();
            },
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.group,
    required this.attendance,
    required this.recordable,
    required this.onPresensi,
  });

  final LessonGroup group;
  final ({String state, String? summary})? attendance;
  final bool recordable;
  final VoidCallback onPresensi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final live = group.status == 'current';
    final done = group.status == 'done';

    return Surface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The left side wraps rather than overflows on a narrow phone or large text.
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: live
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: done ? 0.06 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(group.jpLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: live ? Colors.white : scheme.primary)),
                      ),
                      if (live || group.status == 'next')
                        Text(live ? 'Berlangsung' : 'Berikutnya',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary))
                      else if (done)
                        const Text('Selesai',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                if (attendance != null) ...[
                  const SizedBox(width: 8),
                  _AttendanceChip(attendance!),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(group.subject,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: done ? const Color(0xFF64748B) : null)),
            const SizedBox(height: 2),
            Text(
              [group.classes, group.timeRange, ?group.room].join(' · '),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: recordable ? onPresensi : null,
                    style: _shortcutStyle,
                    child: const OneLineLabel('Presensi'),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: _SoonButton('Jurnal')),
                const SizedBox(width: 8),
                const Expanded(child: _SoonButton('RPP')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceChip extends StatelessWidget {
  const _AttendanceChip(this.value);

  final ({String state, String? summary}) value;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (value.state) {
      'submitted' => (value.summary ?? 'Sudah presensi', const Color(0xFF15803D)),
      'partial' => ('Sebagian JP', const Color(0xFFB45309)),
      _ => ('Belum presensi', const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Three shortcuts share one row, so each gets about a third of a 360 dp phone: tighter
/// padding and a smaller label than the theme's, and [OneLineLabel] never wraps it.
final _shortcutStyle = ButtonStyle(
  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 14)),
  textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
);

/// Jurnal and RPP have no backend yet; they say so instead of doing nothing.
class _SoonButton extends StatelessWidget {
  const _SoonButton(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$label akan segera hadir')));
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF64748B),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
      ).merge(_shortcutStyle),
      child: OneLineLabel(label),
    );
  }
}
