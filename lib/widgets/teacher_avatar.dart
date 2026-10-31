import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Round avatar: the teacher's photo, or two initials when there is none (or it
/// fails to load). [background] / [foreground] colour the initials fallback.
class TeacherAvatar extends StatelessWidget {
  const TeacherAvatar({
    super.key,
    required this.teacher,
    this.size = 60,
    this.background,
    this.foreground = Colors.white,
  });

  final AuthenticatedTeacher teacher;
  final double size;
  final Color? background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      color: background ?? Theme.of(context).colorScheme.primary,
      alignment: Alignment.center,
      child: Text(teacher.initials,
          style: TextStyle(
              color: foreground,
              fontSize: size / 3,
              fontWeight: FontWeight.w800)),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: teacher.photoUrl == null
            ? initials
            : Image.network(teacher.photoUrl!,
                fit: BoxFit.cover, errorBuilder: (_, _, _) => initials),
      ),
    );
  }
}
