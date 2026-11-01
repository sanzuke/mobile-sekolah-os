import 'package:flutter/material.dart';

/// A button label that shrinks to fit instead of breaking a word across lines.
///
/// Buttons share a row on a 360 dp phone (two in a bottom bar, three on a lesson card),
/// and people run the system text a little larger: a plain `Text` there turns
/// "Presensi" into "Presens" / "i". Scales down only when it must; otherwise it is the
/// normal label.
class OneLineLabel extends StatelessWidget {
  const OneLineLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(label, maxLines: 1, softWrap: false),
  );
}
