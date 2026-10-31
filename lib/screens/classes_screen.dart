import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import 'grade_entry_screen.dart';
import 'students_screen.dart';

/// "Nilai" tab: the classes the teacher teaches (or is homeroom for), each
/// with its subjects (tap -> grade entry) and the class roster.
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  Widget build(BuildContext context) {
    return AsyncView<ClassesData>(
      load: service.classes,
      onUnauthorized: onUnauthorized,
      builder: (context, data) {
        if (data.classes.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              SizedBox(height: 60),
              Icon(Icons.school_outlined, size: 48),
              SizedBox(height: 12),
              Text('Belum ada kelas atau mata pelajaran yang Anda ampu '
                  'di semester ini.',
                  textAlign: TextAlign.center),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Kelas & nilai', style: Theme.of(context).textTheme.titleLarge),
            if (data.semesterName != null)
              Text(data.semesterName!,
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final c in data.classes)
              _ClassTile(
                info: c,
                data: data,
                service: service,
                onUnauthorized: onUnauthorized,
              ),
          ],
        );
      },
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.info,
    required this.data,
    required this.service,
    required this.onUnauthorized,
  });

  final ClassInfo info;
  final ClassesData data;
  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          foregroundColor: scheme.primary,
          child: Text(info.name, style: const TextStyle(fontSize: 12)),
        ),
        title: Text('Kelas ${info.name}'),
        subtitle: Text([
          '${info.studentCount} siswa',
          if (info.isHomeroom) 'Wali kelas',
        ].join(' · ')),
        children: [
          for (final s in info.subjects)
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(s.path),
              subtitle: s.kkm != null && s.kkm! > 0
                  ? Text('KKM ${_fmt(s.kkm!)}')
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GradeEntryScreen(
                  service: service,
                  onUnauthorized: onUnauthorized,
                  classInfo: info,
                  subject: s,
                  periods: data.examPeriods,
                ),
              )),
            ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Daftar siswa'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StudentsScreen(
                service: service,
                onUnauthorized: onUnauthorized,
                classInfo: info,
              ),
            )),
          ),
        ],
      ),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
