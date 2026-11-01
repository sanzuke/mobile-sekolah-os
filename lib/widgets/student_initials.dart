import 'package:flutter/material.dart';

/// Round avatar with the student's initials.
class StudentInitials extends StatelessWidget {
  const StudentInitials(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  String get _initials {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return (words.first[0] + (words.length > 1 ? words[1][0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFD5EDEA),
    ),
    child: Text(
      _initials,
      style: TextStyle(
        color: const Color(0xFF0F766E),
        fontWeight: FontWeight.w800,
        fontSize: size * 0.38,
      ),
    ),
  );
}
