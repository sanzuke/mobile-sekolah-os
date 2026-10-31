import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/date_format.dart';
import 'attendance_screen.dart' show statusColor;

const _short = {
  'present': 'H',
  'late': 'T',
  'sick': 'S',
  'permission': 'I',
  'absent': 'A',
};

const _long = {
  'present': 'Hadir',
  'late': 'Terlambat',
  'sick': 'Sakit',
  'permission': 'Izin',
  'absent': 'Alpa',
};

/// Records attendance for one class over a block of back-to-back JP. The same
/// statuses are saved to every JP of the block (one idempotent PUT per JP).
/// Everyone starts as "Hadir"; the teacher only marks exceptions.
class LessonAttendanceScreen extends StatefulWidget {
  const LessonAttendanceScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.block,
    required this.date,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final LessonBlock block;
  final String date;

  @override
  State<LessonAttendanceScreen> createState() => _LessonAttendanceScreenState();
}

class _LessonAttendanceScreenState extends State<LessonAttendanceScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<AttendanceStudent> _students = [];
  final Map<int, String> _status = {};
  final Map<int, String?> _note = {};
  Map<int, String> _initialStatus = {};
  Map<int, String?> _initialNote = {};

  bool _allSubmitted = false;
  bool _editable = true;
  bool _mixed = false;
  String? _lockedMessage;
  List<String> _warnings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rosters = await Future.wait([
        for (final id in widget.block.scheduleIds)
          widget.service
              .attendanceRoster(scheduleId: id, date: widget.date),
      ]);

      _students = rosters.first.students;
      // One lookup per JP: student id -> that JP's stored row.
      final perJp = [
        for (final r in rosters) {for (final x in r.students) x.studentId: x},
      ];
      _status.clear();
      _note.clear();
      _mixed = false;
      for (final s in _students) {
        final rows = [for (final m in perJp) m[s.studentId]].nonNulls;
        final statuses = rows.map((x) => x.status).nonNulls.toList();
        if (statuses.toSet().length > 1) _mixed = true;
        // First recorded JP wins; nothing recorded yet = everyone "Hadir".
        _status[s.studentId] = statuses.firstOrNull ?? 'present';
        _note[s.studentId] = rows.map((x) => x.note).nonNulls.firstOrNull;
      }
      _initialStatus = Map.of(_status);
      _initialNote = Map.of(_note);
      _allSubmitted = rosters.every((r) => r.submitted);
      _editable = rosters.every((r) => r.editable);
      _lockedMessage =
          rosters.map((r) => r.lockedMessage).whereType<String>().firstOrNull;
      _warnings = {for (final r in rosters) ...r.warnings}.toList();
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _dirty {
    for (final s in _students) {
      if (_status[s.studentId] != _initialStatus[s.studentId]) return true;
      if (_note[s.studentId] != _initialNote[s.studentId]) return true;
    }
    return false;
  }

  /// Saving is meaningful when nothing is recorded yet, something changed, or
  /// the JP of the block disagree and need to be made uniform.
  bool get _canSave => _editable && (!_allSubmitted || _dirty || _mixed);

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perubahan belum disimpan'),
        content: const Text('Perubahan presensi akan hilang.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kembali')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buang')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final records = {
      for (final s in _students)
        s.studentId: (status: _status[s.studentId]!, note: _note[s.studentId]),
    };
    final saved = <int>[];
    String? failure;
    for (final session in widget.block.sessions) {
      try {
        await widget.service.saveAttendance(
          scheduleId: session.scheduleId,
          date: widget.date,
          records: records,
        );
        saved.add(session.sessionNumber);
      } on ApiException catch (e) {
        if (e.isUnauthorized) widget.onUnauthorized();
        failure = 'JP ${session.sessionNumber} gagal: ${e.message}';
        break;
      } catch (_) {
        failure = 'JP ${session.sessionNumber} gagal: tidak dapat terhubung.';
        break;
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    final String message;
    if (failure == null) {
      message = 'Presensi ${widget.block.jpLabel} tersimpan.';
      await _load();
    } else if (saved.isEmpty) {
      message = failure;
    } else {
      // Saving is idempotent, so retrying the whole block is safe.
      message =
          'JP ${saved.join(', ')} tersimpan. $failure Ketuk Simpan untuk mencoba lagi.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editNote(AttendanceStudent s) async {
    final controller = TextEditingController(text: _note[s.studentId] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Catatan · ${s.name}'),
        content: TextField(
          controller: controller,
          maxLength: 255,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Simpan')),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    setState(() => _note[s.studentId] = result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${b.subject} · ${b.className}')),
        body: _body(),
        bottomNavigationBar: _loading || _error != null ? null : _footer(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
              child: FilledButton(
                  onPressed: _load, child: const Text('Coba lagi'))),
        ],
      );
    }

    final b = widget.block;
    final counts = {
      for (final k in attendanceStatuses)
        k: _status.values.where((v) => v == k).length,
    };
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${b.jpLabel} · ${b.start} – ${b.end} · ${formatDate(widget.date)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (b.sessions.length > 1)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Status yang sama disimpan untuk semua JP di atas.'),
          ),
        for (final w in _warnings) _Banner(text: w, color: const Color(0xFFB45309)),
        if (!_editable && _lockedMessage != null)
          _Banner(text: _lockedMessage!, color: const Color(0xFFB91C1C)),
        if (_mixed)
          const _Banner(
            text: 'Status berbeda antar JP. Menyimpan akan menyeragamkannya.',
            color: Color(0xFFB45309),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final k in attendanceStatuses)
                if (counts[k]! > 0)
                  Text('${_long[k]} ${counts[k]}',
                      style: TextStyle(
                          color: statusColor(k), fontWeight: FontWeight.w600)),
              if (_editable)
                TextButton(
                  onPressed: () => setState(() {
                    for (final s in _students) {
                      _status[s.studentId] = 'present';
                    }
                  }),
                  child: const Text('Hadir semua'),
                ),
            ],
          ),
        ),
        const Divider(),
        for (final s in _students) _studentRow(s),
      ],
    );
  }

  Widget _studentRow(AttendanceStudent s) {
    final current = _status[s.studentId]!;
    final note = _note[s.studentId];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (_editable)
                IconButton(
                  tooltip: 'Catatan',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editNote(s),
                  icon: Icon(
                      note == null ? Icons.note_add_outlined : Icons.sticky_note_2,
                      size: 20),
                ),
            ],
          ),
          if (s.nis != null || note != null)
            Text([if (s.nis != null) 'NIS ${s.nis}', ?note].join(' · '),
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final k in attendanceStatuses)
                Tooltip(
                  message: _long[k]!,
                  child: ChoiceChip(
                    key: ValueKey('chip-${s.studentId}-$k'),
                    visualDensity: VisualDensity.compact,
                    label: Text(_short[k]!),
                    selected: current == k,
                    selectedColor: statusColor(k).withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      color: current == k ? statusColor(k) : null,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: _editable
                        ? (_) => setState(() => _status[s.studentId] = k)
                        : null,
                  ),
                ),
            ],
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }

  Widget _footer() {
    final label = _allSubmitted && !_dirty && !_mixed
        ? 'Tersimpan'
        : 'Simpan presensi ${widget.block.jpLabel}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canSave && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(label),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(color: color)),
      );
}
