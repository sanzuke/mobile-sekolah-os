import 'package:flutter/material.dart';

import '../models/incident_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/student_initials.dart';
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Header(incident: i),
          const SizedBox(height: 12),
          if (i.status == 'cancelled')
            const _Banner(
              Icons.block,
              'Laporan ini dibatalkan oleh pelapor.',
              Color(0xFFF1F5F9),
              Color(0xFF475569),
            )
          else
            _StatusSteps(status: i.status),
          if (i.canEdit) ...[
            const SizedBox(height: 12),
            const _Banner(
              Icons.edit_outlined,
              'Belum diambil BK/UKS. Anda masih bisa mengubah atau membatalkan laporan ini.',
              Color(0xFFFEF3E2),
              Color(0xFF92400E),
            ),
          ],
          if ((i.publicNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              icon: Icons.verified_outlined,
              title: 'Tindakan dari penangan',
              tint: const Color(0xFFD5EDEA),
              child: Text(
                i.publicNote!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Section(
            icon: Icons.groups_outlined,
            title: 'Siswa terlibat (${i.students.length})',
            child: Column(
              children: [
                for (var n = 0; n < i.students.length; n++) ...[
                  if (n > 0) const Divider(height: 16),
                  _StudentRow(student: i.students[n]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            icon: Icons.notes_outlined,
            title: 'Kronologi',
            child: Text(
              i.description ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if ((i.actionTaken ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              icon: Icons.healing_outlined,
              title: 'Tindakan awal oleh pelapor',
              child: Text(
                i.actionTaken!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Colours of a report's route: amber for discipline, red for medical.
({Color bg, Color fg}) incidentTone(bool medical) => medical
    ? (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C))
    : (bg: const Color(0xFFFEF3E2), fg: const Color(0xFF92400E));

class _Header extends StatelessWidget {
  const _Header({required this.incident});

  final StudentIncident incident;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tone = incidentTone(incident.isMedical);
    return Container(
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
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  incident.isMedical
                      ? Icons.favorite_border
                      : Icons.warning_amber_rounded,
                  color: tone.fg,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.categoryLabel,
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
                        _Pill(
                          'Tingkat ${incident.severityLabel.toLowerCase()}',
                          Colors.white,
                          tone.fg,
                        ),
                        IncidentStatusChip(
                          status: incident.status,
                          label: incident.statusLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(Icons.schedule, incidentWhen(incident.occurredAt)),
          if ((incident.location ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _InfoRow(Icons.place_outlined, incident.location!),
          ],
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

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.bg, this.fg);

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
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

/// Where the report stands: reported, being handled, resolved. Three equal
/// columns with a line through the dots, so it fits any width or text size.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.status});

  final String status;

  static const _steps = [
    ('reported', 'Dilaporkan'),
    ('handling', 'Ditangani'),
    ('resolved', 'Selesai'),
  ];
  static const _done = Color(0xFF0F766E);
  static const _todo = Color(0xFFCBD5E1);
  static const _dot = 26.0;

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexWhere((s) => s.$1 == status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          // The line runs from the first dot's centre to the last one's.
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                final inset = box.maxWidth / 6;
                final span = box.maxWidth - 2 * inset;
                final reached = current <= 0
                    ? 0.0
                    : current / (_steps.length - 1);
                return Stack(
                  children: [
                    Positioned(
                      left: inset,
                      top: _dot / 2 - 1,
                      width: span,
                      child: Container(height: 2, color: _todo),
                    ),
                    Positioned(
                      left: inset,
                      top: _dot / 2 - 1,
                      width: span * reached,
                      child: Container(height: 2, color: _done),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              for (var n = 0; n < _steps.length; n++)
                Expanded(child: _dotAt(n, current)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dotAt(int n, int current) {
    final reached = n <= current;
    return Column(
      children: [
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? _done : Colors.white,
            border: Border.all(color: reached ? _done : _todo, width: 2),
          ),
          child: reached
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _steps[n].$2,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: n == current ? FontWeight.w800 : FontWeight.w500,
              color: reached
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
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

/// A titled white card, like the other detail screens.
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
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final IncidentStudent student;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      StudentInitials(student.name),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          student.name,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      if (student.gradeName != null)
        _Pill(
          'Kelas ${student.gradeName}',
          const Color(0xFFD5EDEA),
          const Color(0xFF0F766E),
        ),
    ],
  );
}
