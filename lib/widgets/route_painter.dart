import 'package:flutter/material.dart';

import 'floor_map_painter.dart';

class RoutePainter extends CustomPainter {
  final List<String> routePath;
  final double dashOffset;

  const RoutePainter({required this.routePath, required this.dashOffset});

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

    final paint =
        Paint()
          ..color = Colors.deepOrange
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    const dashLength = 12.0;
    const gapLength = 8.0;
    final step = dashLength + gapLength;
    final animatedOffset = dashOffset % step;

    for (final metric in path.computeMetrics()) {
      for (
        double distance = -animatedOffset;
        distance < metric.length;
        distance += step
      ) {
        final start = distance.clamp(0.0, metric.length);
        final end = (distance + dashLength).clamp(0.0, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.routePath != routePath ||
        oldDelegate.dashOffset != dashOffset;
  }
}
