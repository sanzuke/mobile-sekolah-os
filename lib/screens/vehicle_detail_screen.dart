import 'package:flutter/material.dart';

import '../models/vehicle_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';
import 'incidents_screen.dart' show incidentWhen;
import 'vehicle_form_screen.dart';
import 'vehicle_requests_screen.dart';
import '../widgets/one_line_label.dart';

/// One request. While it waits the requester may change or withdraw it; once
/// approved only withdraw (the vehicle is then released). Shows the vehicle and
/// driver the manager assigned, and the manager's note.
class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.id,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final int id;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  VehicleRequest? _request;
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
      _request = await widget.service.vehicleRequest(widget.id);
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
    final saved = await openVehicleForm(
      context,
      widget.service,
      widget.onUnauthorized,
      existing: _request,
    );
    if (saved != null && mounted) setState(() => _request = saved);
  }

  Future<void> _cancel() async {
    final approved = _request?.status == 'approved';
    final ok = await confirmDialog(
      context,
      title: 'Batalkan pengajuan?',
      message: approved
          ? 'Kendaraan yang sudah disetujui akan dilepas dan pengelola diberi tahu.'
          : 'Pengajuan yang dibatalkan tidak lagi diproses pengelola.',
      action: 'Batalkan pengajuan',
      cancel: 'Tidak',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.service.cancelVehicleRequest(widget.id);
      if (mounted) setState(() => _request = updated);
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
    final r = _request;
    return Scaffold(
      appBar: AppBar(title: const Text('Detail pengajuan')),
      bottomNavigationBar: r != null && r.canCancel
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _cancel,
                        child: const OneLineLabel('Batalkan pengajuan'),
                      ),
                    ),
                    if (r.canEdit) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _edit,
                          child: const OneLineLabel('Ubah'),
                        ),
                      ),
                    ],
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
                  _error ?? 'Pengajuan tidak dapat dimuat.',
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

  Widget _content(VehicleRequest r) {
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE0E7FF), Colors.white],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E7FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.destination,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3730A3),
                  ),
                ),
                const SizedBox(height: 6),
                VehicleStatusChip(status: r.status, label: r.statusLabel),
                const SizedBox(height: 14),
                _InfoRow(Icons.flag_outlined, r.purpose),
                const SizedBox(height: 6),
                _InfoRow(Icons.logout, 'Berangkat ${incidentWhen(r.startAt)}'),
                const SizedBox(height: 6),
                _InfoRow(Icons.login, 'Kembali ${incidentWhen(r.endAt)}'),
                const SizedBox(height: 6),
                _InfoRow(
                  Icons.groups_outlined,
                  '${r.passengerCount} penumpang',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (r.status == 'pending')
            const _Banner(
              Icons.hourglass_top,
              'Menunggu keputusan pengelola kendaraan. Anda masih bisa mengubah atau membatalkan pengajuan ini.',
              Color(0xFFFEF3E2),
              Color(0xFF92400E),
            )
          else if (r.status == 'rejected')
            const _Banner(
              Icons.cancel_outlined,
              'Pengajuan ini ditolak. Alasannya ada di bawah.',
              Color(0xFFFEE2E2),
              Color(0xFFB91C1C),
            )
          else if (r.status == 'cancelled')
            const _Banner(
              Icons.block,
              'Pengajuan ini dibatalkan.',
              Color(0xFFF1F5F9),
              Color(0xFF475569),
            ),
          if (r.isApproved && r.vehicleName != null) ...[
            const SizedBox(height: 16),
            _Section(
              icon: Icons.directions_car_outlined,
              title: 'Kendaraan',
              tint: const Color(0xFFD5EDEA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.vehicleName} · ${r.vehiclePlate}',
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((r.driverName ?? '').isNotEmpty)
                    Text('Sopir: ${r.driverName}', style: text.bodyLarge),
                ],
              ),
            ),
          ],
          if ((r.publicNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              icon: Icons.notes_outlined,
              title: r.status == 'rejected'
                  ? 'Alasan penolakan'
                  : 'Catatan dari pengelola',
              child: Text(r.publicNote!, style: text.bodyLarge),
            ),
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
