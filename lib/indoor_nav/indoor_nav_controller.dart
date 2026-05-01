import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'feature_extractor.dart';
import 'indoor_nav_engine.dart';
import 'models.dart';

const String defaultFingerprintAssetPath =
    'assets/indoor_nav/RunLevelFingerprints.csv';
const String defaultCheckpointGraphAssetPath =
    'assets/indoor_nav/CheckpointGraph.json';
const String defaultRoomMappingAssetPath = 'assets/indoor_nav/RoomMapping.json';
const String defaultCheckpointDefinitionsAssetPath =
    'assets/indoor_nav/CheckpointDefinitions.json';

Map<String, int> _emptyFeatureVector() {
  return Map<String, int>.unmodifiable({
    for (final feature in featureNames) feature: missingRssi,
  });
}

/// Flutter-facing state holder for the indoor navigation backend.
///
/// This class intentionally contains no UI logic. Screens can listen to it
/// through Provider, AnimatedBuilder, or direct ChangeNotifier usage.
class IndoorNavController extends ChangeNotifier {
  final bool useWeightedKnn;
  final int knnK;
  final int requiredConsecutive;
  final AssetBundle _assetBundle;
  final bool enableDebugLogging;
  final void Function(String message)? logger;

  IndoorNavEngine? _engine;

  Map<String, int> currentFeatureVector = _emptyFeatureVector();
  String rawPredictedCheckpoint = '';
  String stableCheckpoint = '';
  double predictionConfidence = 0.0;
  String? selectedDestinationRoom;
  String destinationCheckpoint = '';
  String finalRoomInstruction = '';
  List<String> currentRoute = const [];
  List<String> availableRooms = const [];
  List<String> availableCheckpoints = const [];

  IndoorNavController({
    this.useWeightedKnn = true,
    this.knnK = 3,
    this.requiredConsecutive = 3,
    AssetBundle? assetBundle,
    this.enableDebugLogging = false,
    this.logger,
  }) : _assetBundle = assetBundle ?? rootBundle {
    if (knnK <= 0) {
      throw ArgumentError.value(knnK, 'knnK', 'must be greater than zero');
    }
    if (requiredConsecutive <= 0) {
      throw ArgumentError.value(
        requiredConsecutive,
        'requiredConsecutive',
        'must be greater than zero',
      );
    }
  }

  bool get isLoaded => _engine != null;

  Future<void> loadAssets({
    String fingerprintAssetPath = defaultFingerprintAssetPath,
    String checkpointGraphAssetPath = defaultCheckpointGraphAssetPath,
    String roomMappingAssetPath = defaultRoomMappingAssetPath,
    String checkpointDefinitionsAssetPath =
        defaultCheckpointDefinitionsAssetPath,
  }) async {
    final fingerprintCsv = await _assetBundle.loadString(fingerprintAssetPath);
    final graphJson = await _assetBundle.loadString(checkpointGraphAssetPath);
    final roomJson = await _assetBundle.loadString(roomMappingAssetPath);
    final checkpointDefinitionsJson = await _assetBundle.loadString(
      checkpointDefinitionsAssetPath,
    );

    _engine = IndoorNavEngine.fromAssetStrings(
      fingerprintCsv: fingerprintCsv,
      checkpointGraphJson: graphJson,
      roomMappingJson: roomJson,
      checkpointDefinitionsJson: checkpointDefinitionsJson,
      requiredConsecutive: requiredConsecutive,
    );
    final engine = _requireEngine();
    final rooms = engine.roomMapping.keys.toList()..sort();
    final checkpoints = engine.checkpointDefinitions.isNotEmpty
        ? (engine.checkpointDefinitions.keys.toList()..sort())
        : engine.pathFinder.nodes;
    availableRooms = List<String>.unmodifiable(rooms);
    availableCheckpoints = List<String>.unmodifiable(checkpoints);

    _log('Loaded indoor navigation assets.');
    notifyListeners();
  }

  void updateFromWifiScan(List<WifiObservation> observations) {
    final engine = _requireEngine();
    final prediction = engine.predictCheckpoint(
      observations,
      useWeightedKnn: useWeightedKnn,
      k: knnK,
    );

    currentFeatureVector = Map<String, int>.unmodifiable(
      prediction.featureVector,
    );
    rawPredictedCheckpoint = prediction.rawPrediction.checkpointId;
    stableCheckpoint = prediction.stableCheckpointId;
    predictionConfidence = prediction.rawPrediction.confidence;
    _recomputeRouteIfPossible();

    _log(
      'Prediction raw=$rawPredictedCheckpoint stable=$stableCheckpoint '
      'confidence=${predictionConfidence.toStringAsFixed(3)}',
    );
    notifyListeners();
  }

  void selectDestinationRoom(String room) {
    final engine = _requireEngine();
    final normalizedRoom = normalizeRoomLabel(room);

    if (!engine.roomMapping.containsKey(normalizedRoom)) {
      throw ArgumentError('Room not supported: $room');
    }

    selectedDestinationRoom = normalizedRoom;
    _updateDestinationInfo();
    _recomputeRouteIfPossible();

    _log('Selected destination $normalizedRoom route=$currentRoute');
    notifyListeners();
  }

  void clearDestination() {
    selectedDestinationRoom = null;
    destinationCheckpoint = '';
    finalRoomInstruction = '';
    currentRoute = const [];

    _log('Cleared selected destination.');
    notifyListeners();
  }

  RoomInfo? getRoomInfo(String room) {
    final engine = _requireEngine();
    final normalizedRoom = normalizeRoomLabel(room);
    return engine.roomMapping[normalizedRoom];
  }

  CheckpointDefinition? getCheckpointInstruction(String checkpointId) {
    return _requireEngine().getCheckpointInstruction(checkpointId);
  }

  void reset() {
    _engine?.resetSmoothing();
    currentFeatureVector = _emptyFeatureVector();
    rawPredictedCheckpoint = '';
    stableCheckpoint = '';
    predictionConfidence = 0.0;
    selectedDestinationRoom = null;
    destinationCheckpoint = '';
    finalRoomInstruction = '';
    currentRoute = const [];

    _log('Reset indoor navigation controller state.');
    notifyListeners();
  }

  IndoorNavEngine _requireEngine() {
    final engine = _engine;
    if (engine == null) {
      throw StateError('IndoorNavController.loadAssets() must be called first.');
    }
    return engine;
  }

  void _recomputeRouteIfPossible() {
    final engine = _requireEngine();
    final room = selectedDestinationRoom;
    if (room == null || stableCheckpoint.isEmpty) {
      currentRoute = const [];
      return;
    }

    final route = engine.routeToRoom(
      currentCheckpointId: stableCheckpoint,
      destinationRoom: room,
    );
    destinationCheckpoint = route.destinationCheckpointId;
    finalRoomInstruction = route.finalInstruction;
    currentRoute = List<String>.unmodifiable(route.checkpointPath);
  }

  void _updateDestinationInfo() {
    final room = selectedDestinationRoom;
    if (room == null) {
      destinationCheckpoint = '';
      finalRoomInstruction = '';
      return;
    }

    final info = _requireEngine().getRoomInstruction(room);
    destinationCheckpoint = info.checkpointId;
    finalRoomInstruction = info.finalInstruction;
  }

  void _log(String message) {
    if (!enableDebugLogging) return;
    final sink = logger ?? debugPrint;
    sink('[IndoorNav] $message');
  }
}
