import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'floor_map_painter.dart';

class RoutePainter extends CustomPainter {
  final List<String> routePath;
  final double animationValue;

  const RoutePainter({required this.routePath, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (routePath.length < 2) return;

    final path = Path();
    for (var i = 0; i < routePath.length; i++) {
      final point = checkpointOffset(routePath[i], size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    // Use animationValue for blinking opacity
    final opacity = 0.3 + (animationValue * 0.7);

    final dashPaint =
        Paint()
          ..color = Colors.deepOrange.withValues(alpha: opacity)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    const dashLength = 12.0;
    const gapLength = 8.0;
    final step = dashLength + gapLength;

    final metrics = path.computeMetrics().toList();

    // 1. Draw Dotted Path (Static position, blinking opacity)
    for (final metric in metrics) {
      for (double distance = 0; distance < metric.length; distance += step) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dashLength).clamp(0.0, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), dashPaint);
        }
      }
    }

    // 2. Draw Directional Arrows (Blinking opacity)
    final arrowPaint =
        Paint()
          ..color = Colors.deepOrange.shade800.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

    const arrowSpacing = 40.0; // Distance between arrows
    const arrowSize = 6.0;

    for (final metric in metrics) {
      // Offset arrows slightly from the start to avoid overlapping nodes
      for (
        double distance = arrowSpacing / 2;
        distance < metric.length;
        distance += arrowSpacing
      ) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final center = tangent.position;
          final angle = math.atan2(tangent.vector.dy, tangent.vector.dx);

          _drawArrowHead(canvas, center, angle, arrowSize, arrowPaint);
        }
      }
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset center,
    double angle,
    double size,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final path =
        Path()
          ..moveTo(size * 1.2, 0)
          ..lineTo(-size, -size)
          ..lineTo(-size * 0.5, 0)
          ..lineTo(-size, size)
          ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.routePath != routePath ||
        oldDelegate.animationValue != animationValue;
  }
}
