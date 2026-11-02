import 'package:flutter/material.dart';

import '../models/rpp_models.dart';

({Color bg, Color fg, IconData icon}) rppToneStyle(String tone) =>
    switch (tone) {
      'ok' => (
        bg: const Color(0xFFDCFCE7),
        fg: const Color(0xFF166534),
        icon: Icons.check_circle_outline,
      ),
      'bad' => (
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFFB91C1C),
        icon: Icons.cancel_outlined,
      ),
      'warn' => (
        bg: const Color(0xFFFEF3E2),
        fg: const Color(0xFF92400E),
        icon: Icons.hourglass_empty,
      ),
      _ => (
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF475569),
        icon: Icons.upload_file_outlined,
      ),
    };

class RppStatusChip extends StatelessWidget {
  const RppStatusChip({super.key, required this.state, this.overdue = false});

  final String state;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final status = rppStatus(state, overdue: overdue);
    final s = rppToneStyle(status.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 13, color: s.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: s.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
