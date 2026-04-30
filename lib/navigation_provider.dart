import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'wifi_service.dart';
import 'localization_engine.dart';
import 'navigation_engine.dart';

class NavigationProvider extends ChangeNotifier {
  final WiFiService _wiFiService = WiFiService();
  final LocalizationEngine _localizationEngine = LocalizationEngine();
  final NavigationEngine _navigationEngine = NavigationEngine();

  List<double> currentVector = [];
  String currentCheckpointId = "Unknown";
  String? destinationRoomId;
  List<String> currentPath = [];

  final List<String> _predictionHistory = [];
  Timer? _scanTimer;

  // Normalized coordinates (0.0 to 1.0) for routers/checkpoints
  final List<Checkpoint> checkpoints = [
    Checkpoint(id: 'B5', name: 'B-Wing Services', x: 0.04, y: 0.67),
    Checkpoint(id: 'B4', name: 'Router B4', x: 0.11, y: 0.46),
    Checkpoint(id: 'B3', name: 'Router B3', x: 0.20, y: 0.46),
    Checkpoint(id: 'B2', name: 'Router B2', x: 0.26, y: 0.46),
    Checkpoint(id: 'B1', name: 'Router B1', x: 0.36, y: 0.46),
    Checkpoint(id: 'C0', name: 'Router C0', x: 0.46, y: 0.43),
    Checkpoint(id: 'C1', name: 'Router C1', x: 0.57, y: 0.16),
    Checkpoint(id: 'A1', name: 'Router A1', x: 0.64, y: 0.46),
    Checkpoint(id: 'A2', name: 'Router A2', x: 0.73, y: 0.46),
    Checkpoint(id: 'A3', name: 'Router A3', x: 0.80, y: 0.46),
    Checkpoint(id: 'A4', name: 'Router A4', x: 0.88, y: 0.46),
    Checkpoint(id: 'A5', name: 'A-Wing Services', x: 0.96, y: 0.68),
  ];

  final List<Room> rooms = [
    // B-Wing Faculty Rooms (Top row, left side)
    Room(
      id: 'B-412',
      name: 'Faculty B-412',
      checkpointId: 'B4',
      x: 0.09,
      y: 0.25,
    ),
    Room(
      id: 'B-411',
      name: 'Faculty B-411',
      checkpointId: 'B4',
      x: 0.11,
      y: 0.25,
    ),
    Room(
      id: 'B-410',
      name: 'Faculty B-410',
      checkpointId: 'B4',
      x: 0.13,
      y: 0.25,
    ),
    Room(
      id: 'B-409',
      name: 'Faculty B-409',
      checkpointId: 'B3',
      x: 0.18,
      y: 0.25,
    ),
    Room(
      id: 'B-408',
      name: 'Faculty B-408',
      checkpointId: 'B3',
      x: 0.20,
      y: 0.25,
    ),
    Room(
      id: 'B-407',
      name: 'Faculty B-407',
      checkpointId: 'B3',
      x: 0.22,
      y: 0.25,
    ),
    Room(
      id: 'B-406',
      name: 'Faculty B-406',
      checkpointId: 'B2',
      x: 0.26,
      y: 0.25,
    ),
    Room(
      id: 'B-405',
      name: 'Faculty B-405',
      checkpointId: 'B2',
      x: 0.28,
      y: 0.25,
    ),
    Room(
      id: 'B-404',
      name: 'Faculty B-404',
      checkpointId: 'B2',
      x: 0.30,
      y: 0.25,
    ),
    Room(
      id: 'B-403',
      name: 'Faculty B-403',
      checkpointId: 'B1',
      x: 0.35,
      y: 0.25,
    ),
    Room(
      id: 'B-402',
      name: 'Faculty B-402',
      checkpointId: 'B1',
      x: 0.37,
      y: 0.25,
    ),
    Room(
      id: 'B-401',
      name: 'Faculty B-401',
      checkpointId: 'B1',
      x: 0.39,
      y: 0.25,
    ),

    // A-Wing Faculty Rooms (Top row, right side)
    Room(
      id: 'A-401',
      name: 'Faculty A-401',
      checkpointId: 'A1',
      x: 0.62,
      y: 0.25,
    ),
    Room(
      id: 'A-402',
      name: 'Faculty A-402',
      checkpointId: 'A1',
      x: 0.64,
      y: 0.25,
    ),
    Room(
      id: 'A-403',
      name: 'Faculty A-403',
      checkpointId: 'A1',
      x: 0.66,
      y: 0.25,
    ),
    Room(
      id: 'A-404',
      name: 'Faculty A-404',
      checkpointId: 'A2',
      x: 0.71,
      y: 0.25,
    ),
    Room(
      id: 'A-405',
      name: 'Faculty A-405',
      checkpointId: 'A2',
      x: 0.73,
      y: 0.25,
    ),
    Room(
      id: 'A-406',
      name: 'Faculty A-406',
      checkpointId: 'A2',
      x: 0.75,
      y: 0.25,
    ),
    Room(
      id: 'A-407',
      name: 'Faculty A-407',
      checkpointId: 'A3',
      x: 0.79,
      y: 0.25,
    ),
    Room(
      id: 'A-408',
      name: 'Faculty A-408',
      checkpointId: 'A3',
      x: 0.81,
      y: 0.25,
    ),
    Room(
      id: 'A-409',
      name: 'Faculty A-409',
      checkpointId: 'A3',
      x: 0.83,
      y: 0.25,
    ),
    Room(
      id: 'A-410',
      name: 'Faculty A-410',
      checkpointId: 'A4',
      x: 0.87,
      y: 0.25,
    ),
    Room(
      id: 'A-411',
      name: 'Faculty A-411',
      checkpointId: 'A4',
      x: 0.89,
      y: 0.25,
    ),
    Room(
      id: 'A-412',
      name: 'Faculty A-412',
      checkpointId: 'A4',
      x: 0.91,
      y: 0.25,
    ),

    // Labs (Bottom row)
    Room(id: 'B-413', name: 'Lab B-413', checkpointId: 'B4', x: 0.11, y: 0.65),
    Room(id: 'B-415', name: 'Lab B-415', checkpointId: 'B3', x: 0.20, y: 0.65),
    Room(id: 'B-416', name: 'Lab B-416', checkpointId: 'B2', x: 0.26, y: 0.65),
    Room(
      id: 'A-419-B',
      name: 'Lab A-419 (B-Side)',
      checkpointId: 'B1',
      x: 0.36,
      y: 0.65,
    ),
    Room(
      id: 'A-419-C',
      name: 'Lab A-419 (Central)',
      checkpointId: 'C0',
      x: 0.44,
      y: 0.65,
    ),
    Room(
      id: 'A-420',
      name: 'Meeting Room A-420',
      checkpointId: 'C0',
      x: 0.50,
      y: 0.65,
    ),
    Room(
      id: 'A-419-A',
      name: 'Lab A-419 (A-Side)',
      checkpointId: 'C0',
      x: 0.56,
      y: 0.65,
    ),
    Room(id: 'A-418', name: 'Lab A-418', checkpointId: 'A1', x: 0.64, y: 0.65),
    Room(id: 'A-416', name: 'Lab A-416', checkpointId: 'A2', x: 0.73, y: 0.65),
    Room(id: 'A-415', name: 'Lab A-415', checkpointId: 'A3', x: 0.80, y: 0.65),
    Room(id: 'A-413', name: 'Lab A-413', checkpointId: 'A4', x: 0.88, y: 0.65),
  ];

  NavigationProvider() {
    _navigationEngine.buildGraph([
      Edge('B5', 'B4', 0.5),
      Edge('B4', 'B3', 1.0),
      Edge('B3', 'B2', 1.0),
      Edge('B2', 'B1', 1.0),
      Edge('B1', 'C0', 1.0),
      Edge('C0', 'C1', 1.5),
      Edge('C0', 'A1', 1.0),
      Edge('A1', 'A2', 1.0),
      Edge('A2', 'A3', 1.0),
      Edge('A3', 'A4', 1.0),
      Edge('A4', 'A5', 0.5),
    ]);
  }

  void startLocalization() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      currentVector = await _wiFiService.getFeatureVector();
      String rawPrediction = _localizationEngine.predictCheckpoint(
        currentVector,
      );

      _predictionHistory.add(rawPrediction);
      if (_predictionHistory.length > 5) _predictionHistory.removeAt(0);

      currentCheckpointId = _localizationEngine.smoothPrediction(
        _predictionHistory,
      );

      if (destinationRoomId != null) {
        _updatePath();
      }

      notifyListeners();
    });
  }

  void stopLocalization() {
    _scanTimer?.cancel();
  }

  void setDestination(String? roomId) {
    destinationRoomId = roomId;
    _updatePath();
    notifyListeners();
  }

  void _updatePath() {
    if (destinationRoomId != null && currentCheckpointId != "Unknown") {
      currentPath = _navigationEngine.findPath(
        currentCheckpointId,
        destinationRoomId!,
        rooms,
      );
    } else {
      currentPath = [];
    }
  }
}
