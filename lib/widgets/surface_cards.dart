import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import 'date_format.dart';

/// White rounded card used by agenda, announcements and empty states.
class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}


/// Bar colour plus chip colours for an agenda event type (as in the design:
/// a coloured bar on the left and a small tag).
({Color bar, Color chipBg, Color chipFg}) agendaColors(String type) =>
    switch (type) {
      'exam' => (
          bar: const Color(0xFFD97706),
          chipBg: const Color(0xFFFEF3E2),
          chipFg: const Color(0xFF92400E)
        ),
      'holiday' => (
          bar: const Color(0xFFDC2626),
          chipBg: const Color(0xFFFEE2E2),
          chipFg: const Color(0xFFB91C1C)
        ),
      'academic' => (
          bar: const Color(0xFF0F766E),
          chipBg: const Color(0xFFD5EDEA),
          chipFg: const Color(0xFF0F766E)
        ),
      _ => (
          bar: const Color(0xFF64748B),
          chipBg: const Color(0xFFF1F5F9),
          chipFg: const Color(0xFF334155)
        ),
    };

class AgendaCard extends StatelessWidget {
  const AgendaCard({super.key, required this.item, this.showDate = false});

  final AgendaItem item;

  /// Show the event's date (range) in the meta line; used on the full Agenda page.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final c = agendaColors(item.type);
    final meta = [
      if (showDate && item.startDate != null)
        item.endDate == null || item.endDate == item.startDate
            ? formatDate(item.startDate!)
            : formatRange(item.startDate!, item.endDate!),
      if (item.timeRange != null) item.timeRange!,
      ?item.location,
    ].join(' · ');
    return Surface(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: c.bar),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (item.typeLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.chipBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(item.typeLabel,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.chipFg)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item, required this.onTap});

  final Announcement item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final date = item.publishedAt == null
        ? null
        : formatDate(item.publishedAt!.toLocal().toIso8601String());
    // Some posts use their title as the excerpt; showing it twice only adds noise.
    final excerpt = item.excerpt?.trim();
    final showExcerpt = excerpt != null &&
        excerpt.isNotEmpty &&
        excerpt.toLowerCase() != item.title.trim().toLowerCase();
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.category != null || date != null)
                    Row(
                      children: [
                        if (item.category != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(item.category!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary)),
                          ),
                        if (date != null) Text(date, style: text.bodySmall),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (showExcerpt) ...[
                    const SizedBox(height: 4),
                    Text(excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}


/// Centered icon, title and hint, for lists with nothing in them (design: Kotak masuk).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B))),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
