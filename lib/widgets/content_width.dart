import 'package:flutter/material.dart';

/// Widest the app content gets; phones are narrower so they are unaffected.
const double kMaxContentWidth = 720;

/// Keeps the whole app (pages, bottom bar, dialogs, toasts) in a centred
/// column on tablets instead of stretching every card edge to edge.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: child,
        ),
      ),
    );
  }
}
