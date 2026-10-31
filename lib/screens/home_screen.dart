import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/auth_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/menu_tile.dart';
import '../widgets/surface_cards.dart';
import '../widgets/teacher_avatar.dart';
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
        actions.academicYear.value = data.academicYear;
        return data;
      },
      onUnauthorized: actions.onUnauthorized,
      builder: (context, data) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 64),
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
            MenuGrid(
              children: [
                for (final id in _homeTiles)
                  MenuTile.entry(menuEntry(id),
                      label: _shortLabel(id),
                      onTap: () =>
                          openMenuEntry(context, actions, menuEntry(id))),
                MenuTile(
                  label: 'Semua',
                  icon: Icons.grid_view_rounded,
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
              for (final a in data.agenda) AgendaCard(item: a),
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
                AnnouncementCard(
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
    final parts = teacher.nameParts;
    final date = [if (data.dayName != null) data.dayName!, formatDate(data.date)]
        .join(', ');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF064E3B)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x330F766E), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Soft rings in the corner, purely decorative.
            Positioned(right: -36, top: -36, child: _Ring(size: 150)),
            Positioned(right: 30, top: 54, child: _Ring(size: 70)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: TeacherAvatar(
                          teacher: teacher,
                          size: 54,
                          background: const Color(0xFFCCFBF1),
                          foreground: const Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Assalamu'alaikum,",
                                  style: TextStyle(
                                      color: Color(0xCCFFFFFF), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text: parts.main,
                                      style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800)),
                                  if (parts.degrees.isNotEmpty)
                                    TextSpan(
                                        text: ' ${parts.degrees}',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xE6FFFFFF))),
                                ]),
                                style: const TextStyle(
                                    color: Colors.white, height: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Bell(actions: actions),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        icon: teacher.isHomeroom
                            ? Icons.workspace_premium_outlined
                            : Icons.menu_book_outlined,
                        label: teacher.isHomeroom ? 'Wali Kelas' : 'Guru Mapel',
                        solid: true,
                      ),
                      if (data.academicYear != null)
                        _Chip(
                            icon: Icons.school_outlined,
                            label: 'TA ${data.academicYear}'),
                      _Chip(icon: Icons.calendar_today_outlined, label: date),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x1FFFFFFF), width: 1.5),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.solid = false});

  final IconData icon;
  final String label;

  /// The role chip is white on teal; the others are a translucent wash.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? const Color(0xFF0F766E) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: solid ? Colors.white : const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.actions});

  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: actions.unread,
      builder: (_, count, _) => Material(
        color: const Color(0x2EFFFFFF),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => actions.openInboxSegment(kInboxNotifications),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none, color: Colors.white),
                if (count > 0)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                          color: Color(0xFF064E3B), shape: BoxShape.circle),
                      child: const CircleAvatar(
                          radius: 5, backgroundColor: Color(0xFFFB7185)),
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Surface(
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
