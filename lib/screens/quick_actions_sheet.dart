import 'package:flutter/material.dart';

class _Quick {
  const _Quick(this.label, this.sub, this.icon, this.bg, this.fg);

  final String label;
  final String sub;
  final IconData icon;
  final Color bg;
  final Color fg;
}

const _quick = [
  _Quick('Ajukan izin / cuti', 'Jam terdampak & guru pengganti otomatis',
      Icons.event_busy_outlined, Color(0xFFD5EDEA), Color(0xFF0F766E)),
  _Quick('Lapor kejadian siswa', 'Pelanggaran ke BK, medis ke UKS',
      Icons.warning_amber_outlined, Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  _Quick('Lapor sarana prasarana', 'Fasilitas atau kendaraan rusak',
      Icons.build_outlined, Color(0xFFFEF3E2), Color(0xFF92400E)),
  _Quick('Pinjam kendaraan', 'Cek ketersediaan, ajukan ke PJ',
      Icons.directions_car_outlined, Color(0xFFE0E7FF), Color(0xFF3730A3)),
  _Quick('Input notulen', 'Catat notulen rapat dengan cepat',
      Icons.event_note_outlined, Color(0xFFF1F5F9), Color(0xFF334155)),
];

/// The "+" in the middle of the bottom bar. None of these have a backend yet,
/// so each says it is coming rather than pretending to work.
Future<void> showQuickActions(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Aksi cepat',
                style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          for (final q in _quick)
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: q.bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(q.icon, color: q.fg),
              ),
              title: Text(q.label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(q.sub),
              onTap: () {
                Navigator.pop(sheetContext);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                    SnackBar(content: Text('${q.label} akan segera hadir')));
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
