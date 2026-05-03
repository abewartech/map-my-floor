import 'package:flutter/foundation.dart';

import 'asset_loaders.dart';
import 'feature_extractor.dart';
import 'fingerprint_predictor.dart';
import 'models.dart';
import 'path_finder.dart';
import 'prediction_smoother.dart';

class IndoorNavPrediction {
  final Map<String, int> featureVector;
  final PredictionResult rawPrediction;
  final String stableCheckpointId;

  /// Current smoother candidate (the checkpoint being accumulated toward).
  final String? smootherCandidate;

  /// How many consecutive hits the candidate has accumulated.
  final int smootherCandidateCount;

  const IndoorNavPrediction({
    required this.featureVector,
    required this.rawPrediction,
    required this.stableCheckpointId,
    this.smootherCandidate,
    this.smootherCandidateCount = 0,
  });
}

class IndoorNavRoute {
  final String startCheckpointId;
  final String destinationRoom;
  final String destinationCheckpointId;
  final String localPosition;
  final String finalInstruction;
  final List<String> checkpointPath;

  const IndoorNavRoute({
    required this.startCheckpointId,
    required this.destinationRoom,
    required this.destinationCheckpointId,
    required this.localPosition,
    required this.finalInstruction,
    required this.checkpointPath,
  });

  bool get isReachable => checkpointPath.isNotEmpty;
}

class _SmoothingTarget {
  final String checkpointId;
  final String rawCheckpointId;
  final bool isRawDirect;
  final bool isGraphProjected;
  final List<String> graphPath;

  const _SmoothingTarget({
    required this.checkpointId,
    required this.rawCheckpointId,
    required this.isRawDirect,
    required this.isGraphProjected,
    required this.graphPath,
  });
}

/// UI-independent indoor navigation backend.
///
/// Flutter UI should:
/// 1. Load asset strings.
/// 2. Create IndoorNavEngine.fromAssetStrings(...).
/// 3. Convert live Wi-Fi plugin results into WifiObservation.
/// 4. Call predictCheckpoint(...).
/// 5. Call routeToRoom(...).
class IndoorNavEngine {
  static const bool debugLocalization = false;

  final FingerprintPredictor predictor;
  final PredictionSmoother smoother;
  final GraphPathFinder pathFinder;
  final Map<String, RoomInfo> roomMapping;
  final Map<String, CheckpointDefinition> checkpointDefinitions;
  final List<String> _recentRawCheckpoints = <String>[];

  IndoorNavEngine({
    required this.predictor,
    required this.smoother,
    required this.pathFinder,
    required this.roomMapping,
    required this.checkpointDefinitions,
  });

  factory IndoorNavEngine.fromAssetStrings({
    required String fingerprintCsv,
    required String checkpointGraphJson,
    required String roomMappingJson,
    String? checkpointDefinitionsJson,
    int requiredConsecutive = 3,
  }) {
    final fingerprints = parseFingerprintsCsv(fingerprintCsv);
    final graphEdges = parseGraphEdgesJson(checkpointGraphJson);
    final rooms = parseRoomMappingJson(roomMappingJson);
    final checkpoints = checkpointDefinitionsJson == null
        ? <String, CheckpointDefinition>{}
        : parseCheckpointDefinitionsJson(checkpointDefinitionsJson);

    return IndoorNavEngine(
      predictor: FingerprintPredictor(fingerprints),
      smoother: PredictionSmoother(requiredConsecutive: requiredConsecutive),
      pathFinder: GraphPathFinder(graphEdges),
      roomMapping: rooms,
      checkpointDefinitions: checkpoints,
    );
  }

  IndoorNavPrediction predictCheckpoint(
    List<WifiObservation> observations, {
    bool useWeightedKnn = true,
    int k = 3,
  }) {
    final vector = extractFeatureVector(observations);
    final matchedCount = matchedFeatureCount(vector);

    if (matchedCount == 0) {
      return IndoorNavPrediction(
        featureVector: vector,
        rawPrediction: const PredictionResult(
          checkpointId: 'Unknown',
          distance: double.infinity,
          confidence: 0.0,
        ),
        stableCheckpointId: smoother.current,
      );
    }

    final raw = useWeightedKnn
        ? predictor.predictWeightedKnn(vector, k: k)
        : predictor.predictNearest(vector);

    _recordRawCheckpoint(raw.checkpointId);

    final currentStable = smoother.current;
    final target = _targetForSmoothing(
      currentStable: currentStable,
      rawCheckpoint: raw.checkpointId,
    );

    final effectiveConfidence =
        target.isGraphProjected ? raw.confidence * 0.60 : raw.confidence;

    final requiredHits = _requiredHitsForTransition(
      currentStable: currentStable,
      target: target,
      rawConfidence: raw.confidence,
    );

    // Block central graph projection from updating stable.
    String stable;
    if (_isCentralCore(currentStable) && target.isGraphProjected) {
      stable = currentStable;
    } else {
      stable = smoother.update(
        checkpointId: target.checkpointId,
        confidence: effectiveConfidence,
        requiredHitsOverride: requiredHits,
      );
    }

    if (debugLocalization) {
      final history = _recentRawCheckpoints.join(',');
      debugPrint(
        '[IndoorNav] matched=$matchedCount raw=${raw.checkpointId} '
        'target=${target.checkpointId} direct=${target.isRawDirect} '
        'projected=${target.isGraphProjected} rawConf=${raw.confidence.toStringAsFixed(2)} '
        'effConf=${effectiveConfidence.toStringAsFixed(2)} stableBefore=$currentStable '
        'stableAfter=$stable recent=[$history] requiredHits=$requiredHits',
      );
    }

    return IndoorNavPrediction(
      featureVector: vector,
      rawPrediction: raw,
      stableCheckpointId: stable,
      smootherCandidate: smoother.candidateDebugLabel,
      smootherCandidateCount: smoother.candidateDebugCount,
    );
  }

  _SmoothingTarget _targetForSmoothing({
    required String currentStable,
    required String rawCheckpoint,
  }) {
    final normalizedStable = currentStable.trim().toUpperCase();
    final normalizedRaw = rawCheckpoint.trim().toUpperCase();

    if (normalizedStable.isEmpty ||
        normalizedRaw.isEmpty ||
        normalizedRaw == 'UNKNOWN' ||
        normalizedRaw == normalizedStable) {
      return _SmoothingTarget(
        checkpointId: normalizedRaw,
        rawCheckpointId: normalizedRaw,
        isRawDirect: true,
        isGraphProjected: false,
        graphPath: const [],
      );
    }

    final path = pathFinder.shortestPath(normalizedStable, normalizedRaw);

    // Central Core Guard
    if (_isCentralCore(normalizedStable) && path.length >= 3) {
      return _SmoothingTarget(
        checkpointId: normalizedStable,
        rawCheckpointId: normalizedRaw,
        isRawDirect: false,
        isGraphProjected: true,
        graphPath: path,
      );
    }

    if (path.length >= 3) {
      return _SmoothingTarget(
        checkpointId: path[1],
        rawCheckpointId: normalizedRaw,
        isRawDirect: false,
        isGraphProjected: true,
        graphPath: path,
      );
    }

    return _SmoothingTarget(
      checkpointId: normalizedRaw,
      rawCheckpointId: normalizedRaw,
      isRawDirect: true,
      isGraphProjected: false,
      graphPath: path,
    );
  }

  int _requiredHitsForTransition({
    required String currentStable,
    required _SmoothingTarget target,
    required double rawConfidence,
  }) {
    final stable = currentStable.trim().toUpperCase();
    final next = target.checkpointId.trim().toUpperCase();

    if (stable.isEmpty || next.isEmpty || next == 'UNKNOWN' || next == stable) {
      return 1;
    }

    final oldVisible = _oldStableStillVisible(stable);
    final centralExit = _isCentralCore(stable);

    if (centralExit) {
      // Be stricter at branch split.
      // Only direct raw A1/B1 should be allowed quickly.
      if (!target.isRawDirect) return 999;
      return oldVisible ? 3 : 2;
    }

    if (target.isGraphProjected) {
      return oldVisible ? 4 : 3;
    }

    final isNeighbor = pathFinder.areNeighbors(stable, next);
    if (isNeighbor && rawConfidence >= 0.70 && !oldVisible) {
      return 1;
    }

    if (isNeighbor) {
      return oldVisible ? 3 : 2;
    }

    return oldVisible ? 5 : 4;
  }

  bool _isCentralCore(String id) {
    final normalized = id.trim().toUpperCase();
    return normalized == 'C0' || normalized == 'C1';
  }

  void _recordRawCheckpoint(String checkpointId) {
    final normalized = checkpointId.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'UNKNOWN') return;
    _recentRawCheckpoints.add(normalized);
    if (_recentRawCheckpoints.length > 4) {
      _recentRawCheckpoints.removeAt(0);
    }
  }

  int _recentRawCount(String checkpointId, {int last = 4}) {
    final normalized = checkpointId.trim().toUpperCase();
    final start =
        (_recentRawCheckpoints.length - last).clamp(
          0,
          _recentRawCheckpoints.length,
        );
    return _recentRawCheckpoints
        .sublist(start)
        .where((id) => id == normalized)
        .length;
  }

  bool _oldStableStillVisible(String currentStable) {
    if (currentStable.trim().isEmpty) return false;
    return _recentRawCount(currentStable, last: 2) > 0;
  }

  IndoorNavRoute routeToRoom({
    required String currentCheckpointId,
    required String destinationRoom,
  }) {
    final room = getRoomInstruction(destinationRoom);
    final destinationCheckpoint = room.checkpointId;

    if (!pathFinder.containsNode(currentCheckpointId)) {
      throw StateError('Current checkpoint is not in graph: $currentCheckpointId');
    }
    if (!pathFinder.containsNode(destinationCheckpoint)) {
      throw StateError('Destination checkpoint is not in graph: $destinationCheckpoint');
    }

    final path = pathFinder.shortestPath(currentCheckpointId, destinationCheckpoint);
    if (path.isEmpty) {
      throw StateError(
        'No route from $currentCheckpointId to $destinationCheckpoint.',
      );
    }

    return IndoorNavRoute(
      startCheckpointId: currentCheckpointId,
      destinationRoom: room.destinationRoom,
      destinationCheckpointId: destinationCheckpoint,
      localPosition: room.localPosition,
      finalInstruction: room.finalInstruction,
      checkpointPath: path,
    );
  }

  RoomInfo getRoomInstruction(String room) {
    final roomKey = normalizeRoomLabel(room);
    final info = roomMapping[roomKey];
    if (info == null) {
      throw ArgumentError('Room not supported: $room');
    }
    return info;
  }

  CheckpointDefinition? getCheckpointInstruction(String checkpointId) {
    return checkpointDefinitions[checkpointId.trim().toUpperCase()];
  }

  void resetSmoothing() => smoother.reset();
}
