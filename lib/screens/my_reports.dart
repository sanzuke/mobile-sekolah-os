import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../models/facility_models.dart';
import '../models/incident_models.dart';
import '../models/leave_models.dart';
import '../models/vehicle_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/leave_widgets.dart';
import '../widgets/surface_cards.dart';
import 'facility_detail_screen.dart';
import 'incident_detail_screen.dart';
import 'incidents_screen.dart' show incidentStudentNames, incidentWhen;
import 'leave_detail_screen.dart';
import 'vehicle_detail_screen.dart';

/// What kind of report a card stands for; also the filter chips' values.
enum ReportKind {
  leave(
    'Izin / cuti',
    Icons.event_busy_outlined,
    Color(0xFFD5EDEA),
    Color(0xFF0F766E),
  ),
  incident(
    'Kejadian siswa',
    Icons.warning_amber_outlined,
    Color(0xFFFEE2E2),
    Color(0xFFB91C1C),
  ),
  facility(
    'Sarpras',
    Icons.build_outlined,
    Color(0xFFFEF3E2),
    Color(0xFF92400E),
  ),
  vehicle(
    'Kendaraan',
    Icons.directions_car_outlined,
    Color(0xFFE0E7FF),
    Color(0xFF3730A3),
  );

  const ReportKind(this.label, this.icon, this.bg, this.fg);

  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
}

/// One row of "Laporan saya": a leave request, incident, facility report or vehicle
/// request, reduced to what a card shows. Opening it goes to that kind's own detail.
class MyReport {
  const MyReport({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusLabel,
    required this.whenLabel,
    required this.sortKey,
  });

  final ReportKind kind;
  final int id;
  final String title;
  final String subtitle;

  /// The kind's own status code (`pending`, `reported`, `handling`, `approved`, ...).
  final String status;
  final String statusLabel;
  final String whenLabel;

  /// School wall-clock time as a UTC value, so the four kinds compare with each other.
  final DateTime sortKey;
}

/// `2026-11-01 08:30` (the API's WIB wall clock) as a comparable value.
DateTime? _wall(String api) {
  final d = DateTime.tryParse(api.replaceFirst(' ', 'T'));
  return d == null
      ? null
      : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);
}

/// An ISO-8601 instant (leave `submitted_at`) as WIB wall clock; leave dates alone are `YYYY-MM-DD`.
DateTime? _instant(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return null;
  return d.isUtc || iso!.contains('+') || iso.endsWith('Z')
      ? d.toUtc().add(const Duration(hours: 7))
      : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);
}

/// The four lists merged into one, newest first. Pure, so it is easy to test.
List<MyReport> mergeMyReports({
  List<LeaveRequest> leaves = const [],
  List<StudentIncident> incidents = const [],
  List<FacilityReport> facilities = const [],
  List<VehicleRequest> vehicles = const [],
}) {
  final epoch = DateTime.utc(1970);
  final all = <MyReport>[
    for (final r in leaves)
      MyReport(
        kind: ReportKind.leave,
        id: r.id,
        title: r.typeLabel,
        subtitle: leaveRange(r.startDate, r.endDate),
        status: r.status,
        statusLabel: r.statusLabel,
        whenLabel:
            'Diajukan ${_instant(r.submittedAt) == null ? '-' : incidentWhen(_fmt(_instant(r.submittedAt)!))}',
        sortKey:
            _instant(r.submittedAt) ?? _wall('${r.startDate} 00:00') ?? epoch,
      ),
    for (final r in incidents)
      MyReport(
        kind: ReportKind.incident,
        id: r.id,
        title: '${r.categoryLabel} · ${r.severityLabel}',
        subtitle: incidentStudentNames(r.students),
        status: r.status,
        statusLabel: r.statusLabel,
        whenLabel: 'Kejadian ${incidentWhen(r.occurredAt)}',
        sortKey: _wall(r.occurredAt) ?? epoch,
      ),
    for (final r in facilities)
      MyReport(
        kind: ReportKind.facility,
        id: r.id,
        title: '${r.categoryLabel} · ${r.priorityLabel}',
        subtitle: r.location,
        status: r.status,
        statusLabel: r.statusLabel,
        whenLabel: 'Dilaporkan ${incidentWhen(r.createdAt)}',
        sortKey: _wall(r.createdAt) ?? epoch,
      ),
    for (final r in vehicles)
      MyReport(
        kind: ReportKind.vehicle,
        id: r.id,
        title: r.destination,
        subtitle: r.purpose,
        status: r.status,
        statusLabel: r.statusLabel,
        whenLabel: 'Berangkat ${incidentWhen(r.startAt)}',
        sortKey: _wall(r.startAt) ?? epoch,
      ),
  ];
  all.sort((a, b) {
    final byTime = b.sortKey.compareTo(a.sortKey);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
  return all;
}

String _fmt(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// What loading the four lists produced: the merged rows, and which kinds failed.
class MyReportsResult {
  const MyReportsResult({
    required this.items,
    required this.failed,
    required this.truncated,
  });

  final List<MyReport> items;
  final List<ReportKind> failed;

  /// True when some kind has more reports than the first page shows.
  final bool truncated;
}

/// Loads the first page of each kind in parallel. One kind failing does not hide the others;
/// an expired session is reported through [onUnauthorized].
Future<MyReportsResult> loadMyReports(
  TeacherService service,
  VoidCallback onUnauthorized,
) async {
  final failed = <ReportKind>[];
  var truncated = false;
  var unauthorized = false;

  Future<T?> guard<T>(ReportKind kind, Future<T> Function() load) async {
    try {
      return await load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) unauthorized = true;
      failed.add(kind);
    } catch (_) {
      failed.add(kind);
    }
    return null;
  }

  final results = await Future.wait<Object?>([
    guard(ReportKind.leave, () => service.leaveRequests()),
    guard(ReportKind.incident, () => service.incidents()),
    guard(ReportKind.facility, () => service.facilityReports()),
    guard(ReportKind.vehicle, () => service.vehicleRequests()),
  ]);
  if (unauthorized) onUnauthorized();

  final leave = results[0] as LeaveRequestPage?;
  final incident = results[1] as StudentIncidentPage?;
  final facility = results[2] as FacilityReportPage?;
  final vehicle = results[3] as VehicleRequestPage?;
  truncated =
      (leave?.lastPage ?? 1) > 1 ||
      (incident?.lastPage ?? 1) > 1 ||
      (facility?.lastPage ?? 1) > 1 ||
      (vehicle?.lastPage ?? 1) > 1;

  return MyReportsResult(
    items: mergeMyReports(
      leaves: leave?.items ?? const [],
      incidents: incident?.items ?? const [],
      facilities: facility?.items ?? const [],
      vehicles: vehicle?.items ?? const [],
    ),
    failed: failed,
    truncated: truncated,
  );
}

/// "Laporan saya": everything the teacher filed, newest first, with a filter by kind.
/// It loads the first time it is shown ([reload] is bumped) and again whenever that
/// happens, so opening the tab always shows the current state.
class MyReportsList extends StatefulWidget {
  const MyReportsList({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.reload,
    this.onCreate,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  /// Bumped to (re)load. Nothing is fetched until the first bump.
  final ValueListenable<int> reload;

  /// "Buat laporan" on the empty state; opens Aksi cepat.
  final VoidCallback? onCreate;

  @override
  State<MyReportsList> createState() => _MyReportsListState();
}

class _MyReportsListState extends State<MyReportsList> {
  MyReportsResult? _result;
  ReportKind? _kind;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.reload.addListener(_load);
    if (widget.reload.value > 0) _load();
  }

  @override
  void dispose() {
    widget.reload.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final result = await loadMyReports(widget.service, widget.onUnauthorized);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _open(MyReport r) async {
    final service = widget.service;
    final out = widget.onUnauthorized;
    final Widget page = switch (r.kind) {
      ReportKind.leave => LeaveDetailScreen(
        service: service,
        onUnauthorized: out,
        id: r.id,
      ),
      ReportKind.incident => IncidentDetailScreen(
        service: service,
        onUnauthorized: out,
        id: r.id,
      ),
      ReportKind.facility => FacilityDetailScreen(
        service: service,
        onUnauthorized: out,
        id: r.id,
      ),
      ReportKind.vehicle => VehicleDetailScreen(
        service: service,
        onUnauthorized: out,
        id: r.id,
      ),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load(); // it may have been edited or withdrawn
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null) {
      // Before the first load (the tab has not been shown) there is nothing to spin for.
      return _loading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink();
    }
    final shown = _kind == null
        ? result.items
        : result.items.where((r) => r.kind == _kind).toList();

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Semua'),
                  selected: _kind == null,
                  onSelected: (_) => setState(() => _kind = null),
                ),
              ),
              for (final k in ReportKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              children: [
                if (result.failed.isNotEmpty)
                  _Notice(
                    result.items.isEmpty &&
                            result.failed.length == ReportKind.values.length
                        ? 'Laporan tidak dapat dimuat. Tarik ke bawah untuk mencoba lagi.'
                        : 'Sebagian tidak dapat dimuat: ${result.failed.map((k) => k.label).join(', ')}. Tarik ke bawah untuk mencoba lagi.',
                  ),
                if (shown.isEmpty &&
                    result.failed.length < ReportKind.values.length)
                  EmptyState(
                    icon: Icons.insert_chart_outlined,
                    title: _kind == null
                        ? 'Belum ada laporan'
                        : 'Belum ada ${_kind!.label.toLowerCase()}',
                    message: 'Izin, kejadian siswa, sarpras, dan pinjam kendaraan yang Anda kirim akan muncul di sini beserta statusnya.',
                    actionLabel: widget.onCreate == null
                        ? null
                        : 'Buat laporan',
                    onAction: widget.onCreate,
                  ),
                for (final r in shown)
                  _ReportCard(report: r, onTap: () => _open(r)),
                if (result.truncated && shown.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'Menampilkan yang terbaru dari tiap jenis. Daftar lengkapnya ada di Semua menu → Laporan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3E2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: Color(0xFF92400E)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final MyReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final k = report.kind;
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: k.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(k.icon, color: k.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    k.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: k.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        report.title,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _StatusChip(
                        status: report.status,
                        label: report.statusLabel,
                      ),
                    ],
                  ),
                  if (report.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      report.subtitle,
                      style: text.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(report.whenLabel, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One palette over every kind's status words.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'handling' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'approved' ||
      'resolved' => (const Color(0xFFD5EDEA), const Color(0xFF0F766E)),
      'rejected' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'cancelled' ||
      'completed' => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      _ => (
        const Color(0xFFFEF3E2),
        const Color(0xFF92400E),
      ), // pending, reported
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
