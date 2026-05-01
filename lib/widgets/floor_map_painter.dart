import 'package:flutter/material.dart';

import '../map_state.dart';

const Map<String, Offset> kCheckpointPositions = {
  'C0': Offset(0.5072, 0.3869),
  'C1': Offset(0.5696, 0.1519),
  'A1': Offset(0.6394, 0.3767),
  'A2': Offset(0.7240, 0.3767),
  'A3': Offset(0.7946, 0.3767),
  'A4': Offset(0.8686, 0.3767),
  'A5': Offset(0.9050, 0.7200),
  'A6': Offset(0.8297, 0.5056),
  'A7': Offset(0.6833, 0.5059),
  'B1': Offset(0.3758, 0.3771),
  'B2': Offset(0.2953, 0.3769),
  'B3': Offset(0.2235, 0.3769),
  'B4': Offset(0.1350, 0.3769),
  'B5': Offset(0.0908, 0.7203),
  'B6': Offset(0.1778, 0.5055),
  'B7': Offset(0.3330, 0.5053),
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
