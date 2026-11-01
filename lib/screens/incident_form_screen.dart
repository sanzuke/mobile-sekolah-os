import 'package:flutter/material.dart';

import '../models/incident_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/student_initials.dart';

/// Opens the report form (new, or an [existing] one nobody has taken up yet).
/// Returns the saved report, or null when the teacher backed out.
Future<StudentIncident?> openIncidentForm(
  BuildContext context,
  TeacherService service,
  VoidCallback onUnauthorized, {
  StudentIncident? existing,
}) => Navigator.of(context).push<StudentIncident>(
  MaterialPageRoute(
    builder: (_) => IncidentFormScreen(
      service: service,
      onUnauthorized: onUnauthorized,
      existing: existing,
    ),
  ),
);

/// File a student incident: the route (discipline to BK, medical to UKS), how
/// serious, who, when, and what happened.
class IncidentFormScreen extends StatefulWidget {
  const IncidentFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.existing,
    this.now,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final StudentIncident? existing;

  /// Overridable clock for tests.
  final DateTime? now;

  @override
  State<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends State<IncidentFormScreen> {
  static const _minDescription = 10;

  final _location = TextEditingController();
  final _description = TextEditingController();
  final _action = TextEditingController();

  String _category = 'discipline';
  String _severity = 'sedang';
  late DateTime _when;
  final List<IncidentStudent> _students = [];

  bool _busy = false;
  bool _dirty = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    // A minute back: the server refuses a time even slightly in the future.
    _when = _now.subtract(const Duration(minutes: 1));
    final i = widget.existing;
    if (i != null) {
      _category = i.category;
      _severity = i.severity;
      _when = DateTime.tryParse(i.occurredAt.replaceFirst(' ', 'T')) ?? _when;
      _location.text = i.location ?? '';
      _description.text = i.description ?? '';
      _action.text = i.actionTaken ?? '';
      _students.addAll(i.students);
    }
    for (final c in [_location, _description, _action]) {
      c.addListener(_markDirty);
    }
  }

  // PopScope reads `_dirty` at build time, so the first edit must rebuild.
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [_location, _description, _action]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    _dirty = true;
    change();
  });

  String _two(int n) => n.toString().padLeft(2, '0');

  String get _whenApi =>
      '${_when.year}-${_two(_when.month)}-${_two(_when.day)} ${_two(_when.hour)}:${_two(_when.minute)}';

  Future<void> _pickDate() async {
    final today = DateTime(_now.year, _now.month, _now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_when.year, _when.month, _when.day),
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today,
    );
    if (picked != null) {
      _touch(
        () => _when = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _when.hour,
          _when.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _when.hour, minute: _when.minute),
    );
    if (picked != null) {
      _touch(
        () => _when = DateTime(
          _when.year,
          _when.month,
          _when.day,
          picked.hour,
          picked.minute,
        ),
      );
    }
  }

  Future<void> _addStudent() async {
    final s = await showModalBottomSheet<IncidentStudent>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StudentPicker(
        service: widget.service,
        onUnauthorized: widget.onUnauthorized,
        selectedIds: {for (final s in _students) s.id},
      ),
    );
    if (s == null || _students.any((x) => x.id == s.id)) return;
    _touch(() => _students.add(s));
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_students.isEmpty) errors['students'] = 'Pilih minimal satu siswa.';
    if (_description.text.trim().length < _minDescription) {
      errors['description'] =
          'Tuliskan kronologi minimal $_minDescription karakter.';
    }
    if (_when.isAfter(_now)) {
      errors['occurred_at'] = 'Waktu kejadian tidak boleh di masa depan.';
    }
    return errors;
  }

  Future<void> _submit() async {
    final errors = _validate();
    setState(() {
      _fieldErrors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;

    final route = _category == 'medical' ? 'UKS' : 'BK';
    final ok = await confirmDialog(
      context,
      title: widget.existing == null ? 'Kirim laporan?' : 'Simpan perubahan?',
      message: _category == 'medical' && _severity == 'berat'
          ? 'Laporan akan diteruskan ke $route. Untuk keadaan darurat, hubungi petugas UKS langsung.'
          : 'Laporan akan diteruskan ke $route.',
      action: widget.existing == null ? 'Kirim' : 'Simpan',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final saved = await widget.service.saveIncident({
        'category': _category,
        'severity': _severity,
        'occurred_at': _whenApi,
        'location': _location.text.trim(),
        'description': _description.text.trim(),
        'action_taken': _action.text.trim(),
        'students': [for (final s in _students) s.id],
      }, id: widget.existing?.id);
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.existing == null
                  ? 'Laporan terkirim.'
                  : 'Laporan diperbarui.',
            ),
          ),
        );
      Navigator.of(context).pop(saved);
      return;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
      _fieldErrors = {
        for (final entry in (e.details ?? const <String, dynamic>{}).entries)
          entry.key:
              '${entry.value is List && (entry.value as List).isNotEmpty ? (entry.value as List).first : entry.value}',
      };
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await confirmDialog(
          context,
          title: 'Keluar tanpa menyimpan?',
          message: 'Perubahan yang belum dikirim akan hilang.',
          action: 'Keluar',
          cancel: 'Lanjut menulis',
          destructive: true,
        );
        if (leave == true) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? 'Lapor kejadian siswa' : 'Ubah laporan',
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.existing == null
                          ? 'Kirim laporan'
                          : 'Simpan perubahan',
                    ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Jenis kejadian',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label, hint) in incidentCategories)
                  ChoiceChip(
                    label: Text('$label · $hint'),
                    selected: _category == value,
                    onSelected: (_) => _touch(() => _category = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Tingkat',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in incidentSeverities)
                  ChoiceChip(
                    label: Text(label),
                    selected: _severity == value,
                    onSelected: (_) => _touch(() => _severity = value),
                  ),
              ],
            ),
            if (_category == 'medical' && _severity == 'berat') ...[
              const SizedBox(height: 8),
              const Text(
                'Bila darurat, hubungi petugas UKS langsung.',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Siswa',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in _students)
                  InputChip(
                    label: Text(
                      s.gradeName == null
                          ? s.name
                          : '${s.name} (${s.gradeName})',
                    ),
                    onDeleted: () => _touch(
                      () => _students.removeWhere((x) => x.id == s.id),
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              onPressed: _addStudent,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Tambah siswa'),
            ),
            if (_fieldErrors['students'] != null)
              Text(
                _fieldErrors['students']!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Picker(
                    label: 'Tanggal',
                    value: '${_when.day}/${_when.month}/${_when.year}',
                    icon: Icons.event_outlined,
                    errorText: _fieldErrors['occurred_at'],
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Picker(
                    label: 'Jam',
                    value: '${_two(_when.hour)}:${_two(_when.minute)}',
                    icon: Icons.schedule,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _location,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Tempat (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Kronologi: apa yang terjadi',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['description'],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _action,
              minLines: 2,
              maxLines: 6,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tindakan awal (opsional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Icon(icon),
        errorText: errorText,
      ),
      child: Text(value),
    ),
  );
}

/// Search active students by name or NIS (two characters at least) and pick one.
class _StudentPicker extends StatefulWidget {
  const _StudentPicker({
    required this.service,
    required this.onUnauthorized,
    required this.selectedIds,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  /// Students already on the report: shown, but not pickable twice.
  final Set<int> selectedIds;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  /// The most results the server returns for one search.
  static const _serverLimit = 20;

  final _query = TextEditingController();
  List<IncidentStudent> _results = [];
  bool _loading = false;
  String? _error;
  int _seq = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final mine = ++_seq;
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await widget.service.studentOptions(q.trim());
      if (mine != _seq || !mounted) return; // a newer search is on its way
      setState(() => _results = found);
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (mine == _seq && mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mine == _seq && mounted) {
        setState(() => _error = 'Tidak dapat terhubung ke server.');
      }
    }
    if (mine == _seq && mounted) setState(() => _loading = false);
  }

  Widget _message(IconData icon, String title, [String? hint]) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _body() {
    final q = _query.text.trim();
    if (_error != null) return _message(Icons.cloud_off_outlined, _error!);
    if (q.length < 2) {
      return _message(
        Icons.person_search_outlined,
        'Cari siswa',
        'Ketik minimal 2 huruf dari nama atau NIS.',
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return _message(
        Icons.search_off,
        'Siswa tidak ditemukan',
        'Coba nama lain atau periksa ejaannya.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, n) => _StudentOption(
        student: _results[n],
        query: q,
        picked: widget.selectedIds.contains(_results[n].id),
        onTap: () => Navigator.pop(context, _results[n]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Cari nama atau NIS siswa',
                  border: const OutlineInputBorder(),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _query.clear();
                            _search('');
                          },
                        ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: _loading && _results.isNotEmpty
                  ? const LinearProgressIndicator(minHeight: 2)
                  : const SizedBox(height: 2),
            ),
            if (_results.isNotEmpty && _query.text.trim().length >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _results.length >= _serverLimit
                        ? 'Menampilkan $_serverLimit hasil pertama. Ketik lebih lengkap untuk mempersempit.'
                        : '${_results.length} siswa ditemukan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }
}

/// One search result: avatar, name with the typed part in bold, class and NIS.
class _StudentOption extends StatelessWidget {
  const _StudentOption({
    required this.student,
    required this.query,
    required this.picked,
    required this.onTap,
  });

  final IncidentStudent student;
  final String query;
  final bool picked;
  final VoidCallback onTap;

  /// [name] with every occurrence of [query] (any case) in bold.
  List<TextSpan> _highlight(String name, TextStyle? base) {
    final lower = name.toLowerCase();
    final needle = query.toLowerCase();
    final spans = <TextSpan>[];
    var from = 0;
    while (needle.isNotEmpty) {
      final at = lower.indexOf(needle, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: name.substring(from, at)));
      spans.add(
        TextSpan(
          text: name.substring(at, at + needle.length),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F766E),
          ),
        ),
      );
      from = at + needle.length;
    }
    if (from < name.length) spans.add(TextSpan(text: name.substring(from)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: picked ? const Color(0xFFF1F5F9) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: picked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              StudentInitials(student.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        children: _highlight(student.name, text.bodyLarge),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (student.gradeName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5EDEA),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Kelas ${student.gradeName}',
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (student.nis != null)
                          Text('NIS ${student.nis}', style: text.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              if (picked)
                const Icon(Icons.check_circle, color: Color(0xFF0F766E))
              else
                const Icon(Icons.add_circle_outline, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}
