import 'package:flutter/material.dart';

import '../models/graph.dart';

const Map<String, Offset> kCheckpointPositions = {
  'C0': Offset(0.461, 0.448),
  'C1': Offset(0.575, 0.188),
  'A1': Offset(0.641, 0.461),
  'A2': Offset(0.733, 0.461),
  'A3': Offset(0.800, 0.461),
  'A4': Offset(0.895, 0.461),
  'A5': Offset(0.925, 0.688),
  'A6': Offset(0.854, 0.630),
  'A7': Offset(0.689, 0.630),
  'B1': Offset(0.362, 0.461),
  'B2': Offset(0.268, 0.461),
  'B3': Offset(0.201, 0.461),
  'B4': Offset(0.110, 0.461),
  'B5': Offset(0.073, 0.696),
  'B6': Offset(0.156, 0.630),
  'B7': Offset(0.316, 0.630),
};

Offset checkpointOffset(String checkpointId, Size size) {
  final normalized = kCheckpointPositions[checkpointId];
  if (normalized == null) return Offset.zero;
  return Offset(normalized.dx * size.width, normalized.dy * size.height);
}

class FloorMapPainter extends CustomPainter {
  final String sourceCheckpointId;
  final String? destinationCheckpointId;
  final List<String> routePath;
  final MapState mapState;
  final double pulseValue;

  const FloorMapPainter({
    required this.sourceCheckpointId,
    required this.destinationCheckpointId,
    required this.routePath,
    required this.mapState,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawNodes(canvas, size);
  }

  void _drawNodes(Canvas canvas, Size size) {
    final routeSet = routePath.toSet();

    for (final entry in kCheckpointPositions.entries) {
      final id = entry.key;
      final center = checkpointOffset(id, size);
      final isSource = id == sourceCheckpointId;
      final isDestination = id == destinationCheckpointId;
      final isIntermediate =
          routeSet.contains(id) && !isSource && !isDestination;
      if (!isSource &&
          !isDestination &&
          !(isIntermediate && mapState == MapState.routing)) {
        continue;
      }

      if (isSource) {
        final ringOpacity = (1.0 - pulseValue).clamp(0.0, 1.0);
        final ringRadius = 14 + (pulseValue * 10);
        final ringPaint =
            Paint()
              ..color = Colors.blue.withValues(alpha: ringOpacity * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3;
        canvas.drawCircle(center, ringRadius, ringPaint);
      }

      final radius =
          isSource || isDestination ? 12.0 : (isIntermediate ? 10.0 : 8.0);
      final color =
          isSource
              ? Colors.blue
              : isDestination
              ? Colors.red
              : Colors.orange;

      canvas.drawCircle(center, radius + 2, Paint()..color = Colors.white);
      canvas.drawCircle(center, radius, Paint()..color = color);
      _drawText(
        canvas,
        id,
        center,
        size: 10,
        color: Colors.white,
        weight: FontWeight.w700,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant FloorMapPainter oldDelegate) {
    return oldDelegate.sourceCheckpointId != sourceCheckpointId ||
        oldDelegate.destinationCheckpointId != destinationCheckpointId ||
        oldDelegate.routePath != routePath ||
        oldDelegate.mapState != mapState ||
        oldDelegate.pulseValue != pulseValue;
  }
}
