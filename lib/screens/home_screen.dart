import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/auth_service.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/lesson_tile.dart';
import 'announcement_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.teacher,
    required this.service,
    required this.unread,
    required this.onUnauthorized,
    required this.onOpenSchedule,
  });

  final AuthenticatedTeacher teacher;
  final TeacherService service;
  final ValueNotifier<int> unread;
  final VoidCallback onUnauthorized;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    return AsyncView<HomeData>(
      load: () async {
        final data = await service.home();
        // Keeps the nav badge in step with every Beranda refresh.
        unread.value = data.unreadNotifications;
        return data;
      },
      onUnauthorized: onUnauthorized,
      builder: (context, data) {
        final text = Theme.of(context).textTheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Assalamu'alaikum,", style: text.bodyMedium),
            Text(teacher.name, style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              [
                if (data.dayName != null) data.dayName!,
                formatDate(data.date),
              ].join(', '),
              style: text.bodySmall,
            ),
            const SizedBox(height: 16),
            _NextLessonCard(data: data, onOpenSchedule: onOpenSchedule),
            if (data.week != null) ...[
              const SizedBox(height: 12),
              _WeekCard(week: data.week!, semester: data.semesterName),
            ],
            const SizedBox(height: 20),
            Text('Jadwal hari ini', style: text.titleMedium),
            const SizedBox(height: 8),
            if (data.lessons.isEmpty)
              _EmptyNote(message: _stateMessage(data))
            else
              for (final l in data.lessons) LessonTile(lesson: l),
            const SizedBox(height: 20),
            Text('Agenda hari ini', style: text.titleMedium),
            const SizedBox(height: 8),
            if (data.agenda.isEmpty)
              const _EmptyNote(message: 'Tidak ada agenda hari ini.')
            else
              for (final a in data.agenda)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(a.title),
                  subtitle: Text([
                    a.typeLabel,
                    if (a.startTime != null) a.startTime!,
                    if (a.location != null) a.location!,
                  ].join(' · ')),
                ),
            const SizedBox(height: 20),
            Text('Pengumuman', style: text.titleMedium),
            const SizedBox(height: 8),
            if (data.announcements.isEmpty)
              const _EmptyNote(message: 'Belum ada pengumuman.')
            else
              for (final a in data.announcements)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(a.title),
                  subtitle: a.publishedAt == null
                      ? null
                      : Text(formatDate(
                          a.publishedAt!.toLocal().toIso8601String())),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AnnouncementDetailScreen(
                      id: a.id,
                      title: a.title,
                      service: service,
                      onUnauthorized: onUnauthorized,
                    ),
                  )),
                ),
          ],
        );
      },
    );
  }

  static String _stateMessage(HomeData d) => switch (d.todayState) {
        'holiday' => 'Tidak ada kegiatan belajar hari ini.',
        'unpublished' =>
          'Jadwal Anda belum dipublikasikan (${d.draftCount} sesi masih draft).',
        'none' => 'Belum ada jadwal mengajar untuk Anda.',
        _ => 'Tidak ada jadwal mengajar hari ini.',
      };
}

class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({required this.data, required this.onOpenSchedule});

  final HomeData data;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = data.nextLesson;
    return Card(
      elevation: 0,
      color: scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenSchedule,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle(
            style: TextStyle(color: scheme.onPrimary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next == null
                      ? 'Sesi berikutnya'
                      : next.status == 'current'
                          ? 'Sedang berlangsung'
                          : 'Sesi berikutnya',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                if (next == null)
                  const Text('Tidak ada sesi tersisa hari ini',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
                else ...[
                  Text('JP ${next.sessionNumber} · ${next.subject}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text([
                    next.classes,
                    next.timeRange,
                    if (next.room != null) next.room!,
                  ].join(' · ')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, this.semester});

  final WeekInfo week;
  final String? semester;

  @override
  Widget build(BuildContext context) {
    final number = week.number;
    final progress = number == null || week.total == 0
        ? 0.0
        : (number / week.total).clamp(0.0, 1.0);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number == null
                  ? 'Di luar masa semester'
                  : 'Pekan ke-$number dari ${week.total} · ${week.sessionsPerWeek} sesi per pekan',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              [
                formatRange(week.start, week.end),
                if (semester != null && semester!.isNotEmpty) semester!,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}
