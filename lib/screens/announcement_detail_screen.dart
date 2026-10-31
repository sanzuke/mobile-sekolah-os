import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.id,
    required this.title,
    required this.service,
    required this.onUnauthorized,
  });

  final int id;
  final String title;
  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: AsyncView<AnnouncementDetail>(
        load: () => service.announcement(id),
        onUnauthorized: onUnauthorized,
        builder: (context, d) {
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (d.summary.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    d.summary.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 12),
              Text(d.summary.title.isEmpty ? title : d.summary.title,
                  style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                [
                  if (d.summary.category != null) d.summary.category!,
                  if (d.summary.publishedAt != null)
                    formatDate(
                        d.summary.publishedAt!.toLocal().toIso8601String()),
                ].join(' · '),
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              SelectableText(d.text, style: text.bodyMedium),
            ],
          );
        },
      ),
    );
  }
}
