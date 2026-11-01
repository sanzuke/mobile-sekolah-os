import 'package:flutter/material.dart';

import '../models/journal_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/date_format.dart';

/// Write the teaching journal of one lesson: topic, material, notes. The same text is saved to every
/// class and JP the lesson covers ([JournalTarget.scheduleIds]); the server upserts, so a retry is safe.
/// Once the correction window has closed it is read-only and says why.
class JournalFormScreen extends StatefulWidget {
  const JournalFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.target,
    required this.date,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final JournalTarget target;

  /// `YYYY-MM-DD` of the lesson.
  final String date;

  @override
  State<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends State<JournalFormScreen> {
  static const _minTopic = 3;

  final _topic = TextEditingController();
  final _material = TextEditingController();
  final _notes = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  bool _editable = true;
  String? _lockedMessage;
  String? _loadError;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_topic, _material, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Reads the existing text (from any row that has one) and whether the window is still open.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final id =
          widget.target.prefillScheduleId ?? widget.target.scheduleIds.first;
      final data = await widget.service.lessonJournal(id, widget.date);
      _topic.text = data.topic ?? '';
      _material.text = data.material ?? '';
      _notes.text = data.notes ?? '';
      _editable = data.editable;
      _lockedMessage = data.lockedMessage;
      for (final c in [_topic, _material, _notes]) {
        c.addListener(_markDirty);
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _loading = false);
  }

  // PopScope reads `_dirty` at build time, so the first edit must rebuild.
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_topic.text.trim().length < _minTopic) {
      errors['topic'] =
          'Tuliskan topik pembelajaran, minimal $_minTopic karakter.';
    }
    return errors;
  }

  Future<void> _save() async {
    final errors = _validate();
    setState(() {
      _fieldErrors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    final body = {
      'topic': _topic.text.trim(),
      'material': _material.text.trim(),
      'notes': _notes.text.trim(),
    };
    try {
      for (final id in widget.target.scheduleIds) {
        await widget.service.saveLessonJournal(id, widget.date, body);
      }
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Jurnal tersimpan.')));
      Navigator.of(context).pop(true);
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

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus jurnal?',
      message: 'Jurnal pelajaran ini dihapus dari semua kelas dan JP di dalamnya. Anda bisa menulisnya lagi.',
      action: 'Hapus',
      cancel: 'Tidak',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      for (final id in widget.target.writtenScheduleIds) {
        await widget.service.deleteLessonJournal(id, widget.date);
      }
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Jurnal dihapus.')));
      Navigator.of(context).pop(true);
      return;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = widget.target;
    final canWrite = _editable && !_loading && _loadError == null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await confirmDialog(
          context,
          title: 'Keluar tanpa menyimpan?',
          message: 'Jurnal yang belum disimpan akan hilang.',
          action: 'Keluar',
          cancel: 'Lanjut menulis',
          destructive: true,
        );
        if (leave == true) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Jurnal mengajar')),
        bottomNavigationBar: canWrite
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (t.writtenScheduleIds.isNotEmpty) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _delete,
                            child: const Text('Hapus'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _busy ? null : _save,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Simpan jurnal'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 60),
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: _load,
                      child: const Text('Coba lagi'),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.subject,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.classNames} · ${t.jpLabel} · ${t.timeRange}',
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(formatDate(widget.date), style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_editable)
                    _Banner(
                      Icons.lock_outline,
                      _lockedMessage ?? 'Jurnal ini tidak bisa diubah lagi.',
                      const Color(0xFFF1F5F9),
                      const Color(0xFF475569),
                    )
                  else if (t.scheduleIds.length > 1)
                    _Banner(
                      Icons.info_outline,
                      'Isi yang sama disimpan untuk semua kelas dan JP pelajaran ini (${t.scheduleIds.length} baris).',
                      const Color(0xFFE0F2FE),
                      const Color(0xFF0369A1),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _topic,
                    enabled: _editable,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Topik',
                      hintText: 'Mis. Bab Thaharah',
                      border: const OutlineInputBorder(),
                      errorText: _fieldErrors['topic'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _material,
                    enabled: _editable,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Materi / kegiatan (opsional)',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      errorText: _fieldErrors['material'],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    enabled: _editable,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Catatan: kendala, tindak lanjut (opsional)',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      errorText: _fieldErrors['notes'],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.icon, this.message, this.bg, this.fg);

  final IconData icon;
  final String message;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: TextStyle(color: fg, fontSize: 13)),
        ),
      ],
    ),
  );
}
