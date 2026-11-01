import 'package:flutter/material.dart';

import '../models/meeting_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/date_format.dart';
import 'meeting_minute_form_screen.dart';
import 'meeting_minutes_screen.dart';
import '../widgets/one_line_label.dart';

/// One set of minutes. A draft can be edited, finalised or deleted by its
/// author; a final one is read-only, except that tasks can be ticked.
class MeetingMinuteDetailScreen extends StatefulWidget {
  const MeetingMinuteDetailScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.id,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final int id;

  @override
  State<MeetingMinuteDetailScreen> createState() =>
      _MeetingMinuteDetailScreenState();
}

class _MeetingMinuteDetailScreenState extends State<MeetingMinuteDetailScreen> {
  MeetingMinute? _minute;
  String? _error;
  bool _loading = true;
  bool _busy = false;

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
      _minute = await widget.service.meetingMinute(widget.id);
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs a server call that returns the updated minutes; shows the API's reason on refusal.
  Future<void> _run(Future<MeetingMinute> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      final updated = await call();
      if (!mounted) return;
      setState(() => _minute = updated);
      _toast(done);
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Tidak dapat terhubung ke server.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit() async {
    final saved = await openMeetingForm(
      context,
      widget.service,
      widget.onUnauthorized,
      existing: _minute,
    );
    if (saved != null && mounted) setState(() => _minute = saved);
  }

  Future<void> _finalize() async {
    final ok = await confirmDialog(
      context,
      title: 'Finalkan notulen?',
      message: 'Setelah difinalkan, isi notulen tidak bisa diubah lagi. Peserta dan penerima tugas akan dapat membacanya.',
      action: 'Finalkan',
    );
    if (ok != true) return;
    await _run(
      () => widget.service.finalizeMeetingMinute(widget.id),
      'Notulen difinalkan.',
    );
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus draft ini?',
      message: 'Draft yang dihapus tidak bisa dikembalikan.',
      action: 'Hapus',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.service.deleteMeetingMinute(widget.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (mounted) {
        _toast(e.message);
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        _toast('Tidak dapat terhubung ke server.');
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggle(MeetingAction a, bool done) async {
    final m = _minute!;
    setState(() => _busy = true);
    try {
      final updated = await widget.service.setMeetingActionDone(
        m.id,
        a.id!,
        done,
      );
      if (!mounted) return;
      setState(
        () => _minute = MeetingMinute(
          id: m.id,
          title: m.title,
          category: m.category,
          categoryLabel: m.categoryLabel,
          heldOn: m.heldOn,
          startTime: m.startTime,
          endTime: m.endTime,
          status: m.status,
          isAuthor: m.isAuthor,
          authorName: m.authorName,
          location: m.location,
          agenda: m.agenda,
          discussion: m.discussion,
          decisions: m.decisions,
          attendees: m.attendees,
          actions: [
            for (final x in m.actions) x.id == updated.id ? updated : x,
          ],
        ),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Tidak dapat terhubung ke server.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final m = _minute;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notulen'),
        actions: [
          if (m != null && m.isAuthor && m.isDraft)
            IconButton(
              tooltip: 'Hapus draft',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      bottomNavigationBar: m != null && m.isAuthor && m.isDraft
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _edit,
                        child: const OneLineLabel('Ubah'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _finalize,
                        child: const OneLineLabel('Finalkan'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: m != null
          ? _content(m)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Text(
                  _error ?? 'Notulen tidak dapat dimuat.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton(
                    onPressed: _load,
                    child: const Text('Coba lagi'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _content(MeetingMinute m) {
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MeetingStatusChip(isFinal: m.isFinal),
              Text(m.categoryLabel, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.title,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(meetingWhen(m), style: text.bodyLarge),
          if ((m.location ?? '').isNotEmpty)
            Text(m.location!, style: text.bodyMedium),
          if (m.authorName != null)
            Text('Ditulis oleh ${m.authorName}', style: text.bodySmall),
          if (m.isDraft && m.isAuthor) ...[
            const SizedBox(height: 12),
            const _Notice(
              'Draft: hanya Anda yang bisa melihatnya. Finalkan agar peserta dan penerima tugas dapat membacanya.',
            ),
          ],
          _Section('Agenda', m.agenda),
          _Section('Pembahasan', m.discussion),
          _Section('Keputusan', m.decisions),
          if (m.attendees.isNotEmpty) ...[
            const _Heading('Peserta'),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final a in m.attendees)
                  Chip(
                    avatar: Icon(
                      a.attended
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 18,
                    ),
                    label: Text(a.name),
                  ),
              ],
            ),
          ],
          if (m.actions.isNotEmpty) ...[
            const _Heading('Tindak lanjut'),
            for (final a in m.actions)
              _ActionRow(
                action: a,
                onChanged: _busy || !a.canToggle ? null : (v) => _toggle(a, v),
              ),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.label, this.body);

  final String label;
  final String? body;

  @override
  Widget build(BuildContext context) {
    if (body == null || body!.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(label),
        Text(body!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3E2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onChanged});

  final MeetingAction action;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (action.assignee != null) action.assignee!.name,
      if (action.dueDate != null) 'tenggat ${formatDate(action.dueDate!)}',
    ].join(' · ');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: action.done,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      title: Text(
        action.description,
        style: action.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: sub.isEmpty ? null : Text(sub),
    );
  }
}
