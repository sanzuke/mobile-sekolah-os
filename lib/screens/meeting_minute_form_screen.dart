import 'package:flutter/material.dart';

import '../models/meeting_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/date_format.dart';
import '../widgets/one_line_label.dart';

/// Opens the minutes form (new, or [existing] draft). Returns the saved minutes,
/// or null when the teacher backed out.
Future<MeetingMinute?> openMeetingForm(
  BuildContext context,
  TeacherService service,
  VoidCallback onUnauthorized, {
  MeetingMinute? existing,
}) => Navigator.of(context).push<MeetingMinute>(
  MaterialPageRoute(
    builder: (_) => MeetingMinuteFormScreen(
      service: service,
      onUnauthorized: onUnauthorized,
      existing: existing,
    ),
  ),
);

/// Write minutes: basics, attendees, notes, decisions and follow-ups. "Simpan
/// draft" keeps it private; "Finalkan" publishes and locks it.
class MeetingMinuteFormScreen extends StatefulWidget {
  const MeetingMinuteFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.existing,
    this.now,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final MeetingMinute? existing;

  /// Overridable clock for tests.
  final DateTime? now;

  @override
  State<MeetingMinuteFormScreen> createState() =>
      _MeetingMinuteFormScreenState();
}

class _MeetingMinuteFormScreenState extends State<MeetingMinuteFormScreen> {
  static const _minDiscussion = 10;

  final _title = TextEditingController();
  final _location = TextEditingController();
  final _agenda = TextEditingController();
  final _discussion = TextEditingController();
  final _decisions = TextEditingController();

  String _category = 'staff';
  late DateTime _heldOn;
  TimeOfDay? _start;
  TimeOfDay? _end;
  final List<MeetingAttendee> _attendees = [];
  final List<MeetingAction> _actions = [];

  bool _busy = false;
  bool _dirty = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = {};

  DateTime get _today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _heldOn = _today;
    final m = widget.existing;
    if (m != null) {
      _title.text = m.title;
      _location.text = m.location ?? '';
      _agenda.text = m.agenda ?? '';
      _discussion.text = m.discussion ?? '';
      _decisions.text = m.decisions ?? '';
      _category = m.category;
      _heldOn = DateTime.tryParse(m.heldOn) ?? _today;
      _start = _parseTime(m.startTime);
      _end = _parseTime(m.endTime);
      _attendees.addAll(m.attendees);
      _actions.addAll(m.actions);
    }
    for (final c in [_title, _location, _agenda, _discussion, _decisions]) {
      c.addListener(_markDirty);
    }
  }

  // PopScope reads `_dirty` at build time, so the first edit must rebuild.
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [_title, _location, _agenda, _discussion, _decisions]) {
      c.dispose();
    }
    super.dispose();
  }

  TimeOfDay? _parseTime(String? hhmm) {
    final p = (hhmm ?? '').split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _touch(VoidCallback change) => setState(() {
    _dirty = true;
    change();
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _heldOn,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today.add(const Duration(days: 7)),
    );
    if (picked != null) _touch(() => _heldOn = picked);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (start ? _start : _end) ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) _touch(() => start ? _start = picked : _end = picked);
  }

  Future<TeacherOption?> _pickTeacher() => showModalBottomSheet<TeacherOption>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TeacherPicker(
      service: widget.service,
      onUnauthorized: widget.onUnauthorized,
    ),
  );

  Future<void> _addAttendee() async {
    final t = await _pickTeacher();
    if (t == null) return;
    if (_attendees.any((a) => a.teacherId == t.id)) return;
    _touch(
      () => _attendees.add(MeetingAttendee(teacherId: t.id, name: t.name)),
    );
  }

  Future<void> _addGuest() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _GuestDialog(),
    );
    if (name == null || name.isEmpty) return;
    _touch(() => _attendees.add(MeetingAttendee(name: name)));
  }

  Future<void> _editAction([int? index]) async {
    final result = await showModalBottomSheet<MeetingAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ActionEditor(
        initial: index == null ? null : _actions[index],
        service: widget.service,
        onUnauthorized: widget.onUnauthorized,
        firstDate: _heldOn,
        lastDate: _heldOn.add(const Duration(days: 730)),
      ),
    );
    if (result == null) return;
    _touch(
      () => index == null ? _actions.add(result) : _actions[index] = result,
    );
  }

  Map<String, dynamic> _body({required bool finalize}) => {
    'title': _title.text.trim(),
    'category': _category,
    'held_on': _ymd(_heldOn),
    if (_start != null) 'start_time': _hhmm(_start!),
    if (_end != null) 'end_time': _hhmm(_end!),
    'location': _location.text.trim(),
    'agenda': _agenda.text.trim(),
    'discussion': _discussion.text.trim(),
    'decisions': _decisions.text.trim(),
    'attendees': [for (final a in _attendees) a.toJson()],
    'actions': [for (final a in _actions) a.toJson()],
    'finalize': finalize,
  };

  /// Checks what the server would refuse, so the teacher sees it next to the field.
  Map<String, List<String>> _validate({required bool finalize}) {
    final errors = <String, List<String>>{};
    if (_title.text.trim().isEmpty) errors['title'] = ['Judul wajib diisi.'];
    if (_start != null &&
        _end != null &&
        _hhmm(_end!).compareTo(_hhmm(_start!)) <= 0) {
      errors['end_time'] = ['Jam selesai harus setelah jam mulai.'];
    }
    if (finalize && _discussion.text.trim().length < _minDiscussion) {
      errors['discussion'] = [
        'Isi pembahasan minimal $_minDiscussion karakter sebelum difinalkan.',
      ];
    }
    return errors;
  }

  Future<void> _save({required bool finalize}) async {
    final errors = _validate(finalize: finalize);
    setState(() {
      _fieldErrors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;

    if (finalize) {
      final ok = await confirmDialog(
        context,
        title: 'Finalkan notulen?',
        message: 'Setelah difinalkan, isi notulen tidak bisa diubah lagi. Penerima tugas akan diberi tahu.',
        action: 'Finalkan',
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final saved = await widget.service.saveMeetingMinute(
        _body(finalize: finalize),
        id: widget.existing?.id,
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              finalize ? 'Notulen difinalkan.' : 'Draft tersimpan.',
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
          entry.key: [
            for (final v
                in (entry.value is List ? entry.value as List : [entry.value]))
              '$v',
          ],
      };
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await confirmDialog(
      context,
      title: 'Keluar tanpa menyimpan?',
      message: 'Perubahan yang belum disimpan akan hilang.',
      action: 'Keluar',
      cancel: 'Lanjut menulis',
      destructive: true,
    );
    return leave == true;
  }

  String? _err(String key) => _fieldErrors[key]?.first;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'Tulis notulen' : 'Ubah draft'),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _save(finalize: false),
                    child: const OneLineLabel('Simpan draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _save(finalize: true),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const OneLineLabel('Finalkan'),
                  ),
                ),
              ],
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
            TextField(
              controller: _title,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Judul rapat',
                border: const OutlineInputBorder(),
                errorText: _err('title'),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final (value, label) in meetingCategories)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: (v) => _touch(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),
            _PickerField(
              label: 'Tanggal',
              value: formatDate(_ymd(_heldOn)),
              icon: Icons.event_outlined,
              errorText: _err('held_on'),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Mulai',
                    value: _start == null ? null : _hhmm(_start!),
                    icon: Icons.schedule,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerField(
                    label: 'Selesai',
                    value: _end == null ? null : _hhmm(_end!),
                    icon: Icons.schedule,
                    errorText: _err('end_time'),
                    onTap: () => _pickTime(false),
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
            _SectionTitle('Peserta'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _attendees.length; i++)
                  InputChip(
                    label: Text(_attendees[i].name),
                    onDeleted: () => _touch(() => _attendees.removeAt(i)),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _addAttendee,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Tambah guru'),
                ),
                TextButton.icon(
                  onPressed: _addGuest,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Tambah tamu'),
                ),
              ],
            ),
            if (_err('attendees') != null) _FieldError(_err('attendees')!),
            const SizedBox(height: 8),
            TextField(
              controller: _agenda,
              maxLines: 3,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Agenda (opsional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _discussion,
              minLines: 5,
              maxLines: 12,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Pembahasan',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText: _err('discussion'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _decisions,
              minLines: 3,
              maxLines: 8,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keputusan (opsional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            _SectionTitle('Tindak lanjut'),
            for (var i = 0; i < _actions.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_actions[i].description),
                subtitle: Text(
                  [
                    if (_actions[i].assignee != null)
                      _actions[i].assignee!.name,
                    if (_actions[i].dueDate != null)
                      'tenggat ${formatDate(_actions[i].dueDate!)}',
                  ].join(' · '),
                ),
                onTap: () => _editAction(i),
                trailing: IconButton(
                  tooltip: 'Hapus tugas',
                  icon: const Icon(Icons.close),
                  onPressed: () => _touch(() => _actions.removeAt(i)),
                ),
              ),
            TextButton.icon(
              onPressed: _editAction,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Tambah tindak lanjut'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Asks for a guest's name. Owns its controller so it outlives the closing animation.
class _GuestDialog extends StatefulWidget {
  const _GuestDialog();

  @override
  State<_GuestDialog> createState() => _GuestDialogState();
}

class _GuestDialogState extends State<_GuestDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tambah tamu'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 150,
      decoration: const InputDecoration(labelText: 'Nama tamu'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _name.text.trim()),
        child: const Text('Tambah'),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String? value;
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
      child: Text(value ?? 'Pilih'),
    ),
  );
}

/// Search the active teachers and return one.
class _TeacherPicker extends StatefulWidget {
  const _TeacherPicker({required this.service, required this.onUnauthorized});

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  State<_TeacherPicker> createState() => _TeacherPickerState();
}

class _TeacherPickerState extends State<_TeacherPicker> {
  final _query = TextEditingController();
  List<TeacherOption> _results = [];
  bool _loading = true;
  String? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final mine = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await widget.service.teacherOptions(q.trim());
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari nama guru',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : _loading && _results.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Center(child: Text('Guru tidak ditemukan'))
                  : ListView(
                      children: [
                        for (final t in _results)
                          ListTile(
                            title: Text(t.name),
                            onTap: () => Navigator.pop(context, t),
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

/// Add or edit one follow-up: what, who, by when.
class _ActionEditor extends StatefulWidget {
  const _ActionEditor({
    this.initial,
    required this.service,
    required this.onUnauthorized,
    required this.firstDate,
    required this.lastDate,
  });

  final MeetingAction? initial;
  final TeacherService service;
  final VoidCallback onUnauthorized;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_ActionEditor> createState() => _ActionEditorState();
}

class _ActionEditorState extends State<_ActionEditor> {
  late final TextEditingController _description;
  TeacherOption? _assignee;
  String? _due;
  String? _error;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.initial?.description);
    _assignee = widget.initial?.assignee;
    _due = widget.initial?.dueDate;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAssignee() async {
    final t = await showModalBottomSheet<TeacherOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TeacherPicker(
        service: widget.service,
        onUnauthorized: widget.onUnauthorized,
      ),
    );
    if (t != null) setState(() => _assignee = t);
  }

  Future<void> _pickDue() async {
    final initial = DateTime.tryParse(_due ?? '') ?? widget.firstDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) {
      setState(
        () => _due =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  void _done() {
    final text = _description.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Tuliskan tugasnya.');
      return;
    }
    Navigator.pop(
      context,
      MeetingAction(
        description: text,
        assignee: _assignee,
        dueDate: _due,
        done: widget.initial?.done ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _description,
              autofocus: true,
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tugas',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            _PickerField(
              label: 'Penerima tugas (opsional)',
              value: _assignee?.name,
              icon: Icons.person_search_outlined,
              onTap: _pickAssignee,
            ),
            const SizedBox(height: 12),
            _PickerField(
              label: 'Tenggat (opsional)',
              value: _due == null ? null : formatDate(_due!),
              icon: Icons.event_outlined,
              onTap: _pickDue,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _done, child: const Text('Simpan tugas')),
          ],
        ),
      ),
    );
  }
}
