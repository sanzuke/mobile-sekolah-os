import 'package:flutter/material.dart';

import 'attendance_screen.dart';
import 'classes_screen.dart';
import 'inbox_screen.dart';
import 'leave_requests_screen.dart';
import 'facility_reports_screen.dart';
import 'incidents_screen.dart';
import 'meeting_minutes_screen.dart';
import 'lessons_screen.dart';
import 'shell_actions.dart';

enum MenuGroup {
  mengajar('Mengajar'),
  kegiatan('Kegiatan'),
  kepegawaian('Kepegawaian'),
  laporan('Laporan');

  const MenuGroup(this.title);
  final String title;
}

/// One entry of "Menu utama" / "Semua menu". An entry either switches a tab,
/// opens a page, or is not built yet (`soon`) and just says so.
class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.tab,
    this.inboxSegment,
    this.page,
  });

  final String id;
  final String label;
  final IconData icon;
  final MenuGroup group;

  /// Switch to this bottom-nav tab.
  final int? tab;

  /// Switch to Kotak masuk on this segment.
  final int? inboxSegment;

  /// Push this page.
  final Widget Function(BuildContext context, ShellActions actions)? page;

  bool get soon => tab == null && inboxSegment == null && page == null;
}

Widget _titled(String title, Widget body) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );

String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// Every menu of the design. Only those backed by an API are live; the rest are
/// `soon` (see docs/TEACHER_MOBILE_APP_PLAN.md §9 for the order they will arrive).
final List<MenuEntry> menuEntries = [
  const MenuEntry(
      id: 'jadwal',
      label: 'Jadwal Pelajaran',
      icon: Icons.schedule,
      group: MenuGroup.mengajar,
      tab: kTabSchedule),
  MenuEntry(
      id: 'presensi',
      label: 'Presensi Siswa',
      icon: Icons.check_box_outlined,
      group: MenuGroup.mengajar,
      page: (context, a) => LessonsScreen(
          service: a.service,
          onUnauthorized: a.onUnauthorized,
          date: _todayIso())),
  const MenuEntry(
      id: 'rpp',
      label: 'Kurikulum & RPP',
      icon: Icons.menu_book_outlined,
      group: MenuGroup.mengajar),
  const MenuEntry(
      id: 'jurnal',
      label: 'Jurnal Mengajar',
      icon: Icons.edit_outlined,
      group: MenuGroup.mengajar),
  const MenuEntry(
      id: 'tahfidz',
      label: 'Tahfidz (IHQA)',
      icon: Icons.auto_stories_outlined,
      group: MenuGroup.mengajar),
  MenuEntry(
      id: 'akademik',
      label: 'Akademik',
      icon: Icons.fact_check_outlined,
      group: MenuGroup.mengajar,
      page: (context, a) => _titled(
          'Akademik',
          ClassesScreen(service: a.service, onUnauthorized: a.onUnauthorized))),
  MenuEntry(
      id: 'agenda',
      label: 'Agenda Sekolah',
      icon: Icons.calendar_today_outlined,
      group: MenuGroup.kegiatan,
      page: (context, a) => _titled('Agenda Sekolah',
          AgendaList(service: a.service, onUnauthorized: a.onUnauthorized))),
  const MenuEntry(
      id: 'agenda_pribadi',
      label: 'Agenda Pribadi',
      icon: Icons.event_note_outlined,
      group: MenuGroup.kegiatan),
  MenuEntry(
      id: 'rapat',
      label: 'Rapat & Notulen',
      icon: Icons.groups_outlined,
      group: MenuGroup.kegiatan,
      page: (context, a) => MeetingMinutesScreen(
          service: a.service, onUnauthorized: a.onUnauthorized)),
  const MenuEntry(
      id: 'task',
      label: 'Task',
      icon: Icons.checklist,
      group: MenuGroup.kegiatan),
  const MenuEntry(
      id: 'dokumen',
      label: 'Dokumen',
      icon: Icons.description_outlined,
      group: MenuGroup.kegiatan),
  const MenuEntry(
      id: 'pengumuman',
      label: 'Pengumuman',
      icon: Icons.campaign_outlined,
      group: MenuGroup.kegiatan,
      inboxSegment: kInboxAnnouncements),
  const MenuEntry(
      id: 'data_dokumen',
      label: 'Data & Dokumen',
      icon: Icons.work_outline,
      group: MenuGroup.kepegawaian),
  MenuEntry(
      id: 'izin',
      label: 'Izin / Cuti',
      icon: Icons.event_busy_outlined,
      group: MenuGroup.kepegawaian,
      page: (context, a) => LeaveRequestsScreen(
          service: a.service, onUnauthorized: a.onUnauthorized)),
  MenuEntry(
      id: 'rekap',
      label: 'Rekap Kehadiran',
      icon: Icons.event_available_outlined,
      group: MenuGroup.kepegawaian,
      page: (context, a) => AttendanceScreen(
          service: a.service, onUnauthorized: a.onUnauthorized)),
  const MenuEntry(
      id: 'inventaris',
      label: 'Inventaris',
      icon: Icons.inventory_2_outlined,
      group: MenuGroup.kepegawaian),
  const MenuEntry(
      id: 'tugas_saya',
      label: 'Tugas Saya',
      icon: Icons.assignment_outlined,
      group: MenuGroup.kepegawaian),
  MenuEntry(
      id: 'kejadian',
      label: 'Kejadian Siswa',
      icon: Icons.warning_amber_outlined,
      group: MenuGroup.laporan,
      page: (context, a) => IncidentsScreen(
          service: a.service, onUnauthorized: a.onUnauthorized)),
  MenuEntry(
      id: 'sarpras',
      label: 'Sarpras',
      icon: Icons.build_outlined,
      group: MenuGroup.laporan,
      page: (context, a) => FacilityReportsScreen(
          service: a.service, onUnauthorized: a.onUnauthorized)),
  const MenuEntry(
      id: 'kendaraan',
      label: 'Pinjam Kendaraan',
      icon: Icons.directions_car_outlined,
      group: MenuGroup.laporan),
  const MenuEntry(
      id: 'laporan_saya',
      label: 'Laporan Saya',
      icon: Icons.insert_chart_outlined,
      group: MenuGroup.laporan),
];

MenuEntry menuEntry(String id) => menuEntries.firstWhere((e) => e.id == id);

/// Runs an entry. [popFirst] closes the page it was opened from (Semua menu)
/// before switching tabs, so the tab is actually visible.
void openMenuEntry(
  BuildContext context,
  ShellActions actions,
  MenuEntry entry, {
  bool popFirst = false,
}) {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (entry.tab != null) {
    if (popFirst) nav.pop();
    actions.goTab(entry.tab!);
  } else if (entry.inboxSegment != null) {
    if (popFirst) nav.pop();
    actions.openInboxSegment(entry.inboxSegment!);
  } else if (entry.page != null) {
    nav.push(MaterialPageRoute(builder: (ctx) => entry.page!(ctx, actions)));
  } else {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
        SnackBar(content: Text('${entry.label} akan segera hadir')));
  }
}
