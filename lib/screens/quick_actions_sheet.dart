import 'package:flutter/material.dart';

import '../models/leave_models.dart';
import 'leave_detail_screen.dart';
import 'leave_form_screen.dart';
import 'shell_actions.dart';

class _Quick {
  const _Quick(this.id, this.label, this.sub, this.icon, this.bg, this.fg);

  final String id;
  final String label;
  final String sub;
  final IconData icon;
  final Color bg;
  final Color fg;
}

const _quick = [
  _Quick(
    'leave',
    'Ajukan izin / cuti',
    'Jam terdampak dihitung otomatis',
    Icons.event_busy_outlined,
    Color(0xFFD5EDEA),
    Color(0xFF0F766E),
  ),
  _Quick(
    'incident',
    'Lapor kejadian siswa',
    'Pelanggaran ke BK, medis ke UKS',
    Icons.warning_amber_outlined,
    Color(0xFFFEE2E2),
    Color(0xFFB91C1C),
  ),
  _Quick(
    'facility',
    'Lapor sarana prasarana',
    'Fasilitas atau kendaraan rusak',
    Icons.build_outlined,
    Color(0xFFFEF3E2),
    Color(0xFF92400E),
  ),
  _Quick(
    'vehicle',
    'Pinjam kendaraan',
    'Cek ketersediaan, ajukan ke PJ',
    Icons.directions_car_outlined,
    Color(0xFFE0E7FF),
    Color(0xFF3730A3),
  ),
  _Quick(
    'minutes',
    'Input notulen',
    'Catat notulen rapat dengan cepat',
    Icons.event_note_outlined,
    Color(0xFFF1F5F9),
    Color(0xFF334155),
  ),
];

/// "Ajukan izin / cuti": the form, then the request that was just sent.
Future<void> _openLeaveForm(BuildContext context, ShellActions actions) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final created = await navigator.push<LeaveRequest>(
    MaterialPageRoute(
      builder: (_) => LeaveFormScreen(
        service: actions.service,
        onUnauthorized: actions.onUnauthorized,
      ),
    ),
  );
  if (created == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Pengajuan terkirim dan menunggu persetujuan.'),
      ),
    );
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => LeaveDetailScreen(
        service: actions.service,
        onUnauthorized: actions.onUnauthorized,
        id: created.id,
      ),
    ),
  );
}

/// The "+" in the middle of the bottom bar. Izin / cuti is live; the others have
/// no backend yet, so each says it is coming rather than pretending to work.
Future<void> showQuickActions(BuildContext context, ShellActions actions) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // The default cap is 9/16 of the screen: too short for five rows in landscape.
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Aksi cepat',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final q in _quick)
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: q.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(q.icon, color: q.fg),
                ),
                title: Text(
                  q.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(q.sub),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (q.id == 'leave') {
                    _openLeaveForm(context, actions);
                    return;
                  }
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${q.label} akan segera hadir')),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
