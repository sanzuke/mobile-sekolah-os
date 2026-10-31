import 'package:flutter/material.dart';

import '../widgets/menu_tile.dart';
import 'menu_entries.dart';
import 'shell_actions.dart';

/// "Semua menu": every entry of the design grouped, with a search box that
/// filters by menu or group name (as in the prototype).
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.actions, this.autofocus = false});

  final ShellActions actions;
  final bool autofocus;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _query = '';

  bool _matches(MenuEntry e, String q) =>
      q.isEmpty ||
      e.label.toLowerCase().contains(q) ||
      e.group.title.toLowerCase().contains(q);

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final groups = [
      for (final g in MenuGroup.values)
        (g, [for (final e in menuEntries) if (e.group == g && _matches(e, q)) e]),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Semua menu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            autofocus: widget.autofocus,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari menu, misal: presensi, RPP',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('Menu tidak ditemukan. Coba kata lain.',
                  textAlign: TextAlign.center),
            ),
          for (final (group, entries) in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(group.title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            MenuGrid(
              children: [
                for (final e in entries)
                  MenuTile.entry(
                    e,
                    onTap: () => openMenuEntry(context, widget.actions, e,
                        popFirst: true),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
