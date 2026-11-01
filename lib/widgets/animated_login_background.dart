import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A slow, soft backdrop for the login screen: a pale teal gradient with a few
/// blurred colour blobs drifting over it. Painted on one canvas (no per-blob
/// widgets) and wrapped in a [RepaintBoundary], so it stays cheap.
///
/// Stands still when [animate] is false or the device asks to reduce motion
/// (system "remove animations"): the first frame is the same picture, frozen.
class AnimatedLoginBackground extends StatefulWidget {
  const AnimatedLoginBackground({super.key, this.animate = true, this.child});

  final bool animate;
  final Widget? child;

  /// One full drift; every blob moves a whole number of loops in it, so it never jumps.
  static const loop = Duration(seconds: 28);

  @override
  State<AnimatedLoginBackground> createState() =>
      _AnimatedLoginBackgroundState();
}

class _AnimatedLoginBackgroundState extends State<AnimatedLoginBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AnimatedLoginBackground.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedLoginBackground old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final moving = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (moving && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!moving && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) =>
                CustomPaint(painter: _BlobPainter(_controller.value)),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Blob {
  const _Blob(
    this.color,
    this.radius,
    this.cx,
    this.cy,
    this.dx,
    this.dy,
    this.loops,
    this.phase,
  );

  final Color color;

  /// Fractions of the shorter screen side / of width and height.
  final double radius, cx, cy, dx, dy;

  /// Whole number of orbits per [AnimatedLoginBackground.loop].
  final int loops;
  final double phase;
}

const _blobs = [
  _Blob(
    Color(0x400F766E),
    0.62,
    0.15,
    0.12,
    0.16,
    0.10,
    1,
    0.0,
  ), // teal, top left
  _Blob(
    Color(0x3314B8A6),
    0.52,
    0.90,
    0.30,
    0.14,
    0.12,
    2,
    1.7,
  ), // light teal, right
  _Blob(
    Color(0x30F59E0B),
    0.40,
    0.10,
    0.62,
    0.12,
    0.14,
    1,
    3.4,
  ), // warm amber (the logo's orange)
  _Blob(
    Color(0x380F766E),
    0.58,
    0.82,
    0.92,
    0.16,
    0.08,
    2,
    5.1,
  ), // teal, bottom right
];

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t);

  /// 0..1 through one loop.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0FDFA), Color(0xFFF8FAFC)],
        ).createShader(rect),
    );

    final base = math.min(size.width, size.height);
    for (final b in _blobs) {
      final angle = 2 * math.pi * b.loops * t + b.phase;
      final center = Offset(
        size.width * (b.cx + b.dx * math.cos(angle)),
        size.height * (b.cy + b.dy * math.sin(angle)),
      );
      final radius = base * b.radius;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [b.color, b.color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}
