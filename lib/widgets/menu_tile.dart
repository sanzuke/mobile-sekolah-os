import 'package:flutter/material.dart';

import '../screens/menu_entries.dart';

/// Four-column grid of [MenuTile]s with rows sized to the tile (a fixed 0.78
/// aspect ratio left a ~40dp hole between rows). The row height follows the
/// user's text size: a two-line label at 1.2x needs more than a fixed 108dp.
class MenuGrid extends StatelessWidget {
  const MenuGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Tile = padding 8 + icon 60 + gap 6, then up to two label lines (12sp, ~1.45).
    final label = MediaQuery.textScalerOf(context).scale(12) * 1.45;
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 76 + 2 * label,
        mainAxisSpacing: 2,
      ),
      children: children,
    );
  }
}

/// Rounded icon square with its label underneath (design: "Menu utama").
/// Every tile has the same accent colours; one that is not built yet only says
/// "akan segera hadir" when tapped.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.soon = false,
  });

  factory MenuTile.entry(MenuEntry e, {required VoidCallback onTap, String? label}) =>
      MenuTile(label: label ?? e.label, icon: e.icon, soon: e.soon, onTap: onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Not built yet (kept for callers; it does not change how the tile looks).
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.primary.withValues(alpha: 0.12);
    final fg = scheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
