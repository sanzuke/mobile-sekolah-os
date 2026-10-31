import 'package:flutter/material.dart';

import '../models/teacher_models.dart';

class LessonTile extends StatelessWidget {
  const LessonTile({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = lesson.status == 'current' || lesson.status == 'next';
    final done = lesson.status == 'done';

    final label = switch (lesson.status) {
      'current' => 'Berlangsung',
      'next' => 'Berikutnya',
      'done' => 'Selesai',
      _ => null,
    };

    return Card(
      elevation: 0,
      color: highlighted ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: done ? 0.06 : 0.12),
          foregroundColor: scheme.primary,
          child: Text('${lesson.sessionNumber}'),
        ),
        title: Text(
          lesson.subject,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: done ? scheme.outline : null,
          ),
        ),
        subtitle: Text([
          lesson.classes,
          lesson.timeRange,
          if (lesson.room != null) lesson.room!,
        ].join(' · ')),
        trailing: label == null
            ? null
            : Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: highlighted ? scheme.primary : scheme.outline)),
      ),
    );
  }
}
