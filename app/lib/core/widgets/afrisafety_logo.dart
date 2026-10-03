import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The AfriSafety mark, concept B "The Circle": you at the centre, your
/// people around you. Drawn in code (no SVG dependency) from the same
/// 240-unit geometry as `design/brand/icon-circle.svg`.
///
/// Below 48 px the simplified mark is used (one amber ring and a centre
/// dot), as in the design's small-size variant.
class AfriSafetyLogo extends StatelessWidget {
  const AfriSafetyLogo({super.key, this.size = 32, this.semanticLabel});

  final double size;

  /// Null hides the logo from screen readers (when a visible app name sits
  /// right next to it).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final logo = CustomPaint(
      size: Size.square(size),
      painter: _CirclePainter(simplified: size < 48),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: logo);
    return Semantics(label: semanticLabel, image: true, child: logo);
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter({required this.simplified});

  final bool simplified;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 240;
    canvas.scale(s);
    const centre = Offset(120, 120);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 240, 240),
        const Radius.circular(54),
      ),
      Paint()..color = AppColors.ink,
    );

    Paint ring(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final fill = Paint()..style = PaintingStyle.fill;

    if (simplified) {
      canvas.drawCircle(centre, 66, ring(AppColors.amber, 18));
      canvas.drawCircle(centre, 24, fill..color = AppColors.ground);
      return;
    }

    canvas.drawCircle(centre, 78, ring(AppColors.teal, 10));
    canvas.drawCircle(centre, 52, ring(AppColors.amber, 10));
    canvas.drawCircle(const Offset(120, 42), 12, fill..color = AppColors.amber);
    fill.color = AppColors.ground;
    canvas.drawCircle(const Offset(188, 159), 12, fill);
    canvas.drawCircle(const Offset(52, 159), 12, fill);
    canvas.drawCircle(centre, 20, fill);
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.simplified != simplified;
}
