import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.classInfo,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final ClassInfo classInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Siswa ${classInfo.name}')),
      body: AsyncView<List<StudentInfo>>(
        load: () => service.students(classInfo.id),
        onUnauthorized: onUnauthorized,
        builder: (context, students) {
          if (students.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 60),
                Text('Belum ada siswa aktif di kelas ini.',
                    textAlign: TextAlign.center),
              ],
            );
          }
          return ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = students[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(s.name),
                subtitle: s.nis == null ? null : Text('NIS ${s.nis}'),
              );
            },
          );
        },
      ),
    );
  }
}
