import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GlowLightingSpinner extends StatefulWidget {
  final double size;
  final List<Color>? colors;
  final double strokeWidth;

  const GlowLightingSpinner({
    super.key,
    this.size = 24,
    this.colors,
    this.strokeWidth = 2.2,
  });

  @override
  State<GlowLightingSpinner> createState() => _GlowLightingSpinnerState();
}

class _GlowLightingSpinnerState extends State<GlowLightingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ??
        const [
          Color(0xFFC084FC),
          Colors.white,
        ];

    final sizeW = widget.size.w;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: sizeW,
          height: sizeW,
          child: Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: CustomPaint(
              size: Size(sizeW, sizeW),
              painter: _ContinuousFullCircleSpinnerPainter(
                colors: colors,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContinuousFullCircleSpinnerPainter extends CustomPainter {
  final List<Color> colors;
  final double strokeWidth;

  _ContinuousFullCircleSpinnerPainter({
    required this.colors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;
    if (radius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final leadColor = colors.last;
    final tailColor = colors.first;

    // 1. Clean Background Circle Track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = leadColor.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Full 360-Degree Continuous Circle Sweep Gradient (No cut, No gap)
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        tailColor.withValues(alpha: 0.0),
        tailColor.withValues(alpha: 0.35),
        leadColor,
        leadColor,
      ],
      stops: const [0.0, 0.35, 0.95, 1.0],
    );

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = sweepGradient.createShader(rect);

    // Full circle with gradient - zero gap/cut
    canvas.drawCircle(center, radius, circlePaint);
  }

  @override
  bool shouldRepaint(covariant _ContinuousFullCircleSpinnerPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.strokeWidth != strokeWidth;
  }
}
