import 'package:flutter/material.dart';

import '../models/facility_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import 'facility_form_screen.dart';
import 'facility_reports_screen.dart';
import 'incidents_screen.dart' show incidentWhen;

/// One report. While nobody has taken it up the reporter may change or withdraw
/// it; afterwards it is read-only, with the handler's public note.
class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.id,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final int id;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  FacilityReport? _report;
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
      _report = await widget.service.facilityReport(widget.id);
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
    final saved = await openFacilityForm(
      context,
      widget.service,
      widget.onUnauthorized,
      existing: _report,
    );
    if (saved != null && mounted) setState(() => _report = saved);
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Batalkan laporan?',
      message: 'Laporan yang dibatalkan tidak lagi diproses petugas sarpras.',
      action: 'Batalkan laporan',
      cancel: 'Tidak',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.service.cancelFacilityReport(widget.id);
      if (mounted) setState(() => _report = updated);
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
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail laporan')),
      bottomNavigationBar: r != null && r.canEdit
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
      body: r != null
          ? _content(r)
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

  Widget _content(FacilityReport r) {
    final text = Theme.of(context).textTheme;
    final tone = r.isUrgent
        ? (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C))
        : (bg: const Color(0xFFFEF3E2), fg: const Color(0xFF92400E));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone.bg, Colors.white],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tone.bg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.categoryLabel,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tone.fg,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FacilityStatusChip(status: r.status, label: r.statusLabel),
                    Text(
                      'Prioritas ${r.priorityLabel.toLowerCase()}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoRow(Icons.place_outlined, r.location),
                const SizedBox(height: 6),
                _InfoRow(Icons.schedule, incidentWhen(r.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (r.status == 'cancelled')
            const _Banner(
              Icons.block,
              'Laporan ini dibatalkan oleh pelapor.',
              Color(0xFFF1F5F9),
              Color(0xFF475569),
            )
          else if (r.status == 'rejected')
            const _Banner(
              Icons.cancel_outlined,
              'Laporan ini ditolak. Alasannya ada di bawah.',
              Color(0xFFFEE2E2),
              Color(0xFFB91C1C),
            )
          else if (r.canEdit)
            const _Banner(
              Icons.edit_outlined,
              'Belum diambil petugas sarpras. Anda masih bisa mengubah atau membatalkan laporan ini.',
              Color(0xFFFEF3E2),
              Color(0xFF92400E),
            ),
          if ((r.publicNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              icon: Icons.verified_outlined,
              title: r.status == 'rejected'
                  ? 'Alasan penolakan'
                  : 'Tindakan dari petugas',
              tint: const Color(0xFFD5EDEA),
              child: Text(r.publicNote!, style: text.bodyLarge),
            ),
          ],
          const SizedBox(height: 16),
          _Section(
            icon: Icons.notes_outlined,
            title: 'Masalah',
            child: Text(r.description ?? '', style: text.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF475569)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.tint,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: tint ?? const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}
