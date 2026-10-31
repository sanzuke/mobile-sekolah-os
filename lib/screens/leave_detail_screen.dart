import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/leave_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/leave_widgets.dart';
import '../widgets/surface_cards.dart';

/// One request: status, who still has to approve it, the reason and the lessons
/// it leaves uncovered. A pending request can be cancelled.
class LeaveDetailScreen extends StatefulWidget {
  const LeaveDetailScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.id,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final int id;

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  final _view = GlobalKey<AsyncViewState<LeaveRequest>>();
  bool _busy = false;

  void _say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _cancel(LeaveRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan pengajuan?'),
        content: const Text(
            'Pengajuan ini tidak akan diproses lagi. Anda bisa membuat pengajuan baru.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Batalkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.cancelLeave(r.id);
      _say('Pengajuan dibatalkan');
      await _view.currentState?.reload();
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _say(e.message);
    } catch (_) {
      _say('Tidak dapat terhubung ke server.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openAttachment(LeaveRequest r) async {
    try {
      final bytes = await widget.service.leaveAttachment(r.id);
      final dir = await getTemporaryDirectory();
      final name = (r.attachmentName ?? 'lampiran-${r.id}')
          .replaceAll(RegExp(r'[^\w.\- ]'), '_');
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _say('Tidak ada aplikasi untuk membuka lampiran ini.');
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _say(e.message);
    } catch (_) {
      _say('Lampiran tidak dapat dibuka.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail pengajuan')),
      body: AsyncView<LeaveRequest>(
        key: _view,
        load: () => widget.service.leaveRequest(widget.id),
        onUnauthorized: widget.onUnauthorized,
        builder: (context, r) => _content(context, r),
      ),
    );
  }

  Widget _content(BuildContext context, LeaveRequest r) {
    final text = Theme.of(context).textTheme;
    final style = leaveStatusStyle(r.status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Surface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(leaveTypeIcon(r.type), color: style.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // Wraps instead of cutting "Menunggu persetujuan" short.
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(r.typeLabel,
                            style: text.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        LeaveStatusChip(status: r.status, label: r.statusLabel),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(leaveRange(r.startDate, r.endDate),
                    style: text.titleSmall),
                if (r.submittedAt != null)
                  Text(
                      'Diajukan ${formatDateTime(DateTime.parse(r.submittedAt!))}',
                      style: text.bodySmall),
                const SizedBox(height: 12),
                Text(r.reason, style: text.bodyMedium),
                if (r.hasAttachment) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _openAttachment(r),
                    icon: const Icon(Icons.attach_file),
                    label: Text(r.attachmentName ?? 'Lihat lampiran'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (r.decisionNote != null && r.decisionNote!.isNotEmpty)
          Surface(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: style.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catatan keputusan',
                      style: text.labelLarge?.copyWith(color: style.fg)),
                  const SizedBox(height: 4),
                  Text(r.decisionNote!),
                ],
              ),
            ),
          ),
        if (r.approvals.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Persetujuan', style: text.titleSmall),
          const SizedBox(height: 8),
          for (final a in r.approvals) _ApprovalTile(approval: a),
        ],
        if (r.lessonCount > 0) ...[
          const SizedBox(height: 6),
          Text('${r.lessonCount} jam pelajaran terdampak',
              style: text.titleSmall),
          Surface(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: LeaveDaysList(days: r.days),
            ),
          ),
        ],
        if (r.canCancel) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _cancel(r),
            icon: const Icon(Icons.close),
            label: const Text('Batalkan pengajuan'),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ],
    );
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({required this.approval});

  final LeaveApproval approval;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = leaveStatusStyle(approval.status);
    final label = switch (approval.status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };
    return Surface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(s.icon, color: s.fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(approval.label,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      [
                        label,
                        if (approval.decidedBy != null)
                          'oleh ${approval.decidedBy}',
                      ].join(' '),
                      style: text.bodySmall?.copyWith(color: s.fg)),
                  if (approval.note != null && approval.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('“${approval.note}”', style: text.bodySmall),
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
