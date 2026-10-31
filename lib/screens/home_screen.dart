import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/auth_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/menu_tile.dart';
import 'announcement_detail_screen.dart';
import 'lessons_screen.dart';
import 'menu_entries.dart';
import 'menu_screen.dart';
import 'shell_actions.dart';

/// Beranda, laid out as in the design: header + bell, menu search, next-session
/// card, "Menu utama" grid, "Kewajiban pekan ini", then today's agenda and the
/// latest announcements.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.teacher, required this.actions});

  final AuthenticatedTeacher teacher;
  final ShellActions actions;

  static const _homeTiles = [
    'presensi',
    'jadwal',
    'rpp',
    'jurnal',
    'tahfidz',
    'agenda',
    'rapat',
  ];

  @override
  Widget build(BuildContext context) {
    return AsyncView<HomeData>(
      load: () async {
        final data = await actions.service.home();
        // Keeps the nav badge in step with every Beranda refresh.
        actions.unread.value = data.unreadNotifications;
        return data;
      },
      onUnauthorized: actions.onUnauthorized,
      builder: (context, data) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Header(teacher: teacher, data: data, actions: actions),
            const SizedBox(height: 16),
            _SearchField(actions: actions),
            const SizedBox(height: 14),
            _SessionCard(data: data, actions: actions),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Menu utama',
              action: 'Semua menu',
              onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MenuScreen(actions: actions))),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.78,
              children: [
                for (final id in _homeTiles)
                  MenuTile.entry(menuEntry(id),
                      label: _shortLabel(id),
                      onTap: () =>
                          openMenuEntry(context, actions, menuEntry(id))),
                MenuTile(
                  label: 'Semua',
                  icon: Icons.grid_view_rounded,
                  neutral: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MenuScreen(actions: actions))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DutiesCard(data: data),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Agenda hari ini',
              action: 'Lihat semua',
              onAction: () =>
                  openMenuEntry(context, actions, menuEntry('agenda')),
            ),
            if (data.agenda.isEmpty)
              const _EmptyCard(message: 'Tidak ada agenda hari ini.')
            else
              for (final a in data.agenda) _AgendaCard(item: a),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Pengumuman',
              action: 'Lihat semua',
              onAction: () => actions.openInboxSegment(kInboxAnnouncements),
            ),
            if (data.announcements.isEmpty)
              const _EmptyCard(message: 'Belum ada pengumuman.')
            else
              for (final a in data.announcements)
                _AnnouncementCard(
                  item: a,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AnnouncementDetailScreen(
                      id: a.id,
                      title: a.title,
                      service: actions.service,
                      onUnauthorized: actions.onUnauthorized,
                    ),
                  )),
                ),
          ],
        );
      },
    );
  }

  /// The home grid uses the short names from the design.
  static String _shortLabel(String id) => switch (id) {
        'presensi' => 'Presensi',
        'jadwal' => 'Jadwal',
        'rpp' => 'RPP',
        'jurnal' => 'Jurnal',
        'tahfidz' => 'Tahfidz',
        'agenda' => 'Agenda',
        'rapat' => 'Rapat',
        _ => menuEntry(id).label,
      };
}

class _Header extends StatelessWidget {
  const _Header({required this.teacher, required this.data, required this.actions});

  final AuthenticatedTeacher teacher;
  final HomeData data;
  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Assalamu'alaikum,", style: text.bodyMedium),
              Text(teacher.name,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                [
                  [if (data.dayName != null) data.dayName!, formatDate(data.date)]
                      .join(', '),
                  teacher.isHomeroom ? 'Wali Kelas' : 'Guru Mapel',
                ].join(' · '),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ValueListenableBuilder<int>(
          valueListenable: actions.unread,
          builder: (_, count, _) => Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => actions.openInboxSegment(kInboxNotifications),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_none, color: scheme.onSurface),
                    if (count > 0)
                      const Positioned(
                        top: 11,
                        right: 12,
                        child: CircleAvatar(
                            radius: 5, backgroundColor: Color(0xFFDC2626)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.actions});

  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    // A button that looks like a field: typing happens on the Semua menu page.
    return TextField(
      readOnly: true,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MenuScreen(actions: actions, autofocus: true))),
      decoration: InputDecoration(
        hintText: 'Cari menu, misal: presensi, RPP',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.data, required this.actions});

  final HomeData data;
  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final next = data.nextLesson;
    final week = data.week;
    final weekText = week == null
        ? null
        : week.number == null
            ? 'Di luar masa semester'
            : 'Pekan ke-${week.number} dari ${week.total} · ${week.sessionsPerWeek} sesi per pekan';

    final String title;
    final String? subtitle;
    if (next != null) {
      title = '${next.status == 'current' ? 'Sedang berlangsung' : 'Sesi berikutnya'}\n'
          'JP ${next.sessionNumber} · ${next.subject}';
      subtitle = [next.classes, next.timeRange, ?next.room].join(' · ');
    } else if (data.lessons.isNotEmpty) {
      title = 'Tidak ada sesi tersisa hari ini';
      subtitle = weekText;
    } else {
      title = switch (data.todayState) {
        'unpublished' => 'Jadwal Anda belum dipublikasikan',
        'none' => 'Belum ada jadwal mengajar untuk Anda',
        _ => 'Tidak ada jadwal mengajar hari ini',
      };
      subtitle = weekText;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => actions.goTab(kTabSchedule),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.schedule, color: scheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        if (subtitle != null)
                          Text(subtitle, style: text.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (next != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LessonsScreen(
                          service: actions.service,
                          onUnauthorized: actions.onUnauthorized,
                          date: data.date,
                        ),
                      ),
                    ),
                    child: const Text('Input Presensi Siswa'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DutiesCard extends StatelessWidget {
  const _DutiesCard({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final week = data.week;
    final duty = data.attendanceDuty;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Kewajiban pekan ini',
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                if (week != null)
                  Text(formatRange(week.start, week.end).replaceAll(RegExp(r' \d{4}$'), ''),
                      style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 14),
            // RPP and Jurnal have no backend yet: shown as "Segera", never as a made-up 0%.
            const _DutyRow(label: 'RPP', value: 'Segera'),
            const SizedBox(height: 12),
            const _DutyRow(label: 'Jurnal mengajar', value: 'Segera'),
            const SizedBox(height: 12),
            _DutyRow(
              label: 'Presensi siswa',
              value: duty?.percent == null ? '—' : '${duty!.percent}%',
              progress: duty?.percent == null ? null : duty!.percent! / 100,
              emphasis: (duty?.percent ?? 100) >= 50
                  ? _Tone.normal
                  : _Tone.warning,
            ),
            if (duty != null && duty.total > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${duty.done} dari ${duty.total} JP kelas sudah dicatat',
                    style: text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Tone { normal, warning, muted }

class _DutyRow extends StatelessWidget {
  const _DutyRow({
    required this.label,
    required this.value,
    this.progress,
    this.emphasis = _Tone.muted,
  });

  final String label;
  final String value;
  final double? progress;
  final _Tone emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (emphasis) {
      _Tone.normal => scheme.onSurface,
      _Tone.warning => const Color(0xFFB45309),
      _Tone.muted => const Color(0xFF64748B),
    };
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress ?? 0,
            backgroundColor: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }
}


/// Same heading style for every section of Beranda, with an optional link on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// White rounded card used by agenda, announcements and empty states.
class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined, color: Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar colour plus chip colours for an agenda event type (as in the design:
/// a coloured bar on the left and a small tag).
({Color bar, Color chipBg, Color chipFg}) agendaColors(String type) =>
    switch (type) {
      'exam' => (
          bar: const Color(0xFFD97706),
          chipBg: const Color(0xFFFEF3E2),
          chipFg: const Color(0xFF92400E)
        ),
      'holiday' => (
          bar: const Color(0xFFDC2626),
          chipBg: const Color(0xFFFEE2E2),
          chipFg: const Color(0xFFB91C1C)
        ),
      'academic' => (
          bar: const Color(0xFF0F766E),
          chipBg: const Color(0xFFD5EDEA),
          chipFg: const Color(0xFF0F766E)
        ),
      _ => (
          bar: const Color(0xFF64748B),
          chipBg: const Color(0xFFF1F5F9),
          chipFg: const Color(0xFF334155)
        ),
    };

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final c = agendaColors(item.type);
    final meta = [
      if (item.timeRange != null) item.timeRange!,
      ?item.location,
    ].join(' · ');
    return _Surface(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: c.bar),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (item.typeLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(item.typeLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.chipFg)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, required this.onTap});

  final Announcement item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final date = item.publishedAt == null
        ? null
        : formatDate(item.publishedAt!.toLocal().toIso8601String());
    // Some posts use their title as the excerpt; showing it twice only adds noise.
    final excerpt = item.excerpt?.trim();
    final showExcerpt = excerpt != null &&
        excerpt.isNotEmpty &&
        excerpt.toLowerCase() != item.title.trim().toLowerCase();
    return _Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.category != null || date != null)
                    Row(
                      children: [
                        if (item.category != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(item.category!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary)),
                          ),
                        if (date != null) Text(date, style: text.bodySmall),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (showExcerpt) ...[
                    const SizedBox(height: 4),
                    Text(excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall),
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
