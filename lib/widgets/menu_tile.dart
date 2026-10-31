import 'package:flutter/material.dart';

import '../screens/menu_entries.dart';

/// Rounded icon square with its label underneath (design: "Menu utama").
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.soon = false,
    this.neutral = false,
  });

  factory MenuTile.entry(MenuEntry e, {required VoidCallback onTap, String? label}) =>
      MenuTile(label: label ?? e.label, icon: e.icon, soon: e.soon, onTap: onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Not built yet: muted colours.
  final bool soon;

  /// The "Semua" tile uses slate instead of the accent.
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = soon || neutral;
    final bg = muted ? const Color(0xFFE2E8F0) : scheme.primary.withValues(alpha: 0.12);
    final fg = muted ? const Color(0xFF334155) : scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: soon ? const Color(0xFF64748B) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
