import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';

/// "Rekap kehadiran": the teacher's own attendance (fingerprint/face device)
/// for one month, with prev/next month navigation. Cannot go past this month.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.now,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  /// Injectable "today" for tests; defaults to the device clock.
  final DateTime? now;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late DateTime _month;
  late final DateTime _thisMonth;
  Key _viewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _thisMonth = DateTime(now.year, now.month);
    _month = _thisMonth;
  }

  String get _monthParam =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _viewKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _month.isBefore(_thisMonth);
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap kehadiran')),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                  tooltip: 'Bulan sebelumnya',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(
                  formatMonth(_monthParam),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                  tooltip: 'Bulan berikutnya',
                  onPressed: canNext ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          Expanded(
            child: AsyncView<AttendanceMonth>(
              key: _viewKey,
              load: () => widget.service.attendance(month: _monthParam),
              onUnauthorized: widget.onUnauthorized,
              builder: (context, data) => _MonthView(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.data});

  final AttendanceMonth data;

  static const _order = [
    'present',
    'late',
    'sick',
    'permission',
    'excused',
    'absent',
  ];

  @override
  Widget build(BuildContext context) {
    if (data.days.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          Icon(Icons.event_busy, size: 48),
          SizedBox(height: 12),
          Text(
            'Belum ada data kehadiran bulan ini.\n'
            'Data masuk dari mesin absen sekolah.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final shown = _order.where((s) => data.count(s) > 0).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in shown)
              _SummaryChip(status: s, count: data.count(s)),
          ],
        ),
        const SizedBox(height: 12),
        for (final d in data.days) _DayTile(day: d),
      ],
    );
  }
}

Color statusColor(String status) => switch (status) {
      'present' => const Color(0xFF15803D),
      'late' => const Color(0xFFB45309),
      'absent' => const Color(0xFFB91C1C),
      _ => const Color(0xFF1D4ED8), // sick / permission / excused
    };

String statusLabel(String status) => switch (status) {
      'present' => 'Hadir',
      'late' => 'Terlambat',
      'absent' => 'Alpa',
      'sick' => 'Sakit',
      _ => 'Izin',
    };

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.status, required this.count});

  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Chip(
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      label: Text('${statusLabel(status)} $count',
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final AttendanceDay day;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(day.status);
    final times = [
      if (day.checkIn != null) 'Masuk ${day.checkIn}',
      if (day.checkOut != null) 'Keluar ${day.checkOut}',
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)),
      ),
      title: Text([
        if (day.dayName != null) day.dayName!,
        formatDate(day.date),
      ].join(', ')),
      subtitle: Text([
        if (times.isNotEmpty) times,
        if (day.notes != null && day.notes!.isNotEmpty) day.notes!,
      ].join('\n')),
      isThreeLine: times.isNotEmpty && day.notes != null && day.notes!.isNotEmpty,
      trailing: Text(day.statusLabel.isEmpty ? statusLabel(day.status) : day.statusLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
