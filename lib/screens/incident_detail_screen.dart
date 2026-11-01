import 'package:flutter/material.dart';

import '../models/incident_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import 'incident_form_screen.dart';
import 'incidents_screen.dart';

/// One report. While nobody has taken it up the reporter may change or withdraw
/// it; afterwards it is read-only, with the handler's public note.
class IncidentDetailScreen extends StatefulWidget {
  const IncidentDetailScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.id,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final int id;

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  StudentIncident? _incident;
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
      _incident = await widget.service.incident(widget.id);
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

  Future<void> _edit() async {
    final saved = await openIncidentForm(
      context,
      widget.service,
      widget.onUnauthorized,
      existing: _incident,
    );
    if (saved != null && mounted) setState(() => _incident = saved);
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Batalkan laporan?',
      message: 'Laporan yang dibatalkan tidak lagi diproses BK/UKS.',
      action: 'Batalkan laporan',
      cancel: 'Tidak',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.service.cancelIncident(widget.id);
      if (mounted) setState(() => _incident = updated);
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
    final i = _incident;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail laporan')),
      bottomNavigationBar: i != null && i.canEdit
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancel,
                        child: const Text('Batalkan laporan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _edit,
                        child: const Text('Ubah'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: i != null
          ? _content(i)
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Text(
                  _error ?? 'Laporan tidak dapat dimuat.',
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

  Widget _content(StudentIncident i) {
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
              IncidentStatusChip(status: i.status, label: i.statusLabel),
              Text(
                '${i.categoryLabel} · ${i.severityLabel}',
                style: text.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            incidentWhen(i.occurredAt),
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if ((i.location ?? '').isNotEmpty)
            Text(i.location!, style: text.bodyMedium),
          if (i.canEdit) ...[
            const SizedBox(height: 12),
            const _Note(
              'Laporan ini belum diambil. Anda masih bisa mengubah atau membatalkannya.',
              Color(0xFFFEF3E2),
              Color(0xFF92400E),
            ),
          ],
          if ((i.publicNote ?? '').isNotEmpty) ...[
            const _Heading('Tindakan dari penangan'),
            _Note(
              i.publicNote!,
              const Color(0xFFD5EDEA),
              const Color(0xFF0F766E),
            ),
          ],
          const _Heading('Siswa'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in i.students)
                Chip(
                  label: Text(
                    s.gradeName == null ? s.name : '${s.name} (${s.gradeName})',
                  ),
                ),
            ],
          ),
          const _Heading('Kronologi'),
          Text(i.description ?? '', style: text.bodyMedium),
          if ((i.actionTaken ?? '').isNotEmpty) ...[
            const _Heading('Tindakan awal'),
            Text(i.actionTaken!, style: text.bodyMedium),
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

class _Note extends StatelessWidget {
  const _Note(this.message, this.bg, this.fg);

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
    child: Text(message, style: TextStyle(color: fg, fontSize: 13)),
  );
}
