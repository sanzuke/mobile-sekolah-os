import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';

/// Grade entry for one class + subject + exam period. Only cells the teacher
/// actually changed are sent. The backend cannot clear a grade (blank = skip),
/// so emptying a saved cell is ignored and says so.
class GradeEntryScreen extends StatefulWidget {
  const GradeEntryScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.classInfo,
    required this.subject,
    required this.periods,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final ClassInfo classInfo;
  final SubjectInfo subject;
  final List<ExamPeriodInfo> periods;

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  ExamPeriodInfo? _period;
  GradeSheet? _sheet;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _period = ClassesData(classes: const [], examPeriods: widget.periods)
        .defaultPeriod(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  Future<void> _load() async {
    final period = _period;
    if (period == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sheet = await widget.service.gradeSheet(
        gradeId: widget.classInfo.id,
        subjectId: widget.subject.id,
        examPeriodId: period.id,
      );
      _disposeControllers();
      for (final r in sheet.rows) {
        _controllers[r.studentId] =
            TextEditingController(text: r.value == null ? '' : _fmt(r.value!));
      }
      _sheet = sheet;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// null = blank, NaN = not a number / out of 0–100.
  double? _parse(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v < 0 || v > 100) return double.nan;
    return v;
  }

  /// Changed, valid cells: student id -> new score.
  Map<int, double> _changes() {
    final sheet = _sheet;
    if (sheet == null) return {};
    final out = <int, double>{};
    for (final r in sheet.rows) {
      final v = _parse(_controllers[r.studentId]!.text);
      if (v != null && !v.isNaN && v != r.value) out[r.studentId] = v;
    }
    return out;
  }

  bool get _hasInvalid =>
      _sheet?.rows.any((r) => _parse(_controllers[r.studentId]!.text)?.isNaN ?? false) ??
      false;

  bool get _dirty => _changes().isNotEmpty;

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perubahan belum disimpan'),
        content: const Text('Nilai yang sudah Anda ketik akan hilang.'),
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

  Future<void> _changePeriod(ExamPeriodInfo? next) async {
    if (next == null || next.id == _period?.id) return;
    if (!await _confirmDiscard()) return;
    setState(() => _period = next);
    await _load();
  }

  Future<void> _save() async {
    final changes = _changes();
    if (changes.isEmpty || _hasInvalid || _saving) return;
    setState(() => _saving = true);
    String message;
    try {
      final res = await widget.service.saveGrades(
        gradeId: widget.classInfo.id,
        subjectId: widget.subject.id,
        examPeriodId: _period!.id,
        values: changes,
      );
      message = 'Berhasil menyimpan ${res.saved} nilai.';
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      message = e.message;
    } catch (_) {
      message = 'Tidak dapat terhubung ke server. Nilai belum tersimpan.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.subject.name} · ${widget.classInfo.name}'),
        ),
        // The footer lives in the body, not in bottomNavigationBar: the Scaffold shrinks
        // its body for the keyboard, so Simpan stays visible while the teacher types.
        body: Column(
          children: [
            _periodPicker(),
            Expanded(child: _body()),
            if (_sheet != null) _footer(),
          ],
        ),
      ),
    );
  }

  Widget _periodPicker() {
    if (widget.periods.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Belum ada periode ujian di semester ini.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<int>(
        initialValue: _period?.id,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Periode ujian',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final p in widget.periods)
            DropdownMenuItem(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (id) => _changePeriod(
            widget.periods.where((p) => p.id == id).firstOrNull),
      ),
    );
  }

  Widget _body() {
    if (_loading && _sheet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sheet == null) {
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
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    if (sheet.rows.isEmpty) {
      return const Center(child: Text('Belum ada siswa aktif di kelas ini.'));
    }

    final kkm = sheet.kkm ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: sheet.rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = sheet.rows[i];
            final ctrl = _controllers[r.studentId]!;
            return ListenableBuilder(
              listenable: ctrl,
              builder: (context, _) {
                final v = _parse(ctrl.text);
                final invalid = v != null && v.isNaN;
                final below = v != null && !v.isNaN && kkm > 0 && v < kkm;
                final changed = v != null && !v.isNaN && v != r.value;
                return ListTile(
                  title: Text(r.name),
                  subtitle: Text([
                    if (r.nis != null) 'NIS ${r.nis}',
                    if (!changed && r.predicate != null) r.predicate!,
                    if (below) 'Di bawah KKM',
                  ].join(' · ')),
                  trailing: SizedBox(
                    width: 84,
                    child: TextField(
                      controller: ctrl,
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: TextStyle(
                        fontWeight:
                            changed ? FontWeight.w700 : FontWeight.normal,
                        color: below ? scheme.error : null,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '–',
                        border: const OutlineInputBorder(),
                        errorText: invalid ? '0–100' : null,
                        filled: changed,
                        fillColor: scheme.primaryContainer,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (_loading)
          const Positioned(
              top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _footer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ListenableBuilder(
          listenable: Listenable.merge(_controllers.values.toList()),
          builder: (context, _) {
            final n = _changes().length;
            final invalid = _hasInvalid;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (invalid)
                  Text('Ada nilai di luar 0–100.',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error)),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (n == 0 || invalid || _saving) ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(n == 0 ? 'Simpan' : 'Simpan ($n nilai)'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Mengosongkan kolom tidak menghapus nilai yang sudah tersimpan.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
