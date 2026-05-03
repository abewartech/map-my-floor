class WifiObservation {
  final String bssid;
  final String ssid;
  final int rssi;
  final int frequencyMHz;

  const WifiObservation({
    required this.bssid,
    required this.ssid,
    required this.rssi,
    required this.frequencyMHz,
  });
}

/// Normalizes room labels such as "b-412", "B412", and " b 412 " to "B-412".
String normalizeRoomLabel(String room) {
  final compact = room.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final match = RegExp(r'^([AB])-?(\d{3})$').firstMatch(compact);
  if (match == null) return compact;
  return '${match.group(1)}-${match.group(2)}';
}

class ApFeatureRule {
  final String name;
  final String prefix;
  final String band; // "2.4" or "5"

  const ApFeatureRule({required this.name, required this.prefix, required this.band});
}

class Fingerprint {
  final String checkpointId;
  final String sessionId;
  final Map<String, int> features;

  const Fingerprint({
    required this.checkpointId,
    required this.sessionId,
    required this.features,
  });
}

class RoomInfo {
  final String destinationRoom;
  final String checkpointId;
  final String localPosition;
  final String displayName;
  final String finalInstruction;

  const RoomInfo({
    required this.destinationRoom,
    required this.checkpointId,
    required this.localPosition,
    required this.displayName,
    required this.finalInstruction,
  });
}

class CheckpointDefinition {
  final String id;
  final String name;
  final String wing;
  final String description;
  final List<String> coveredRooms;
  final String? leftRoom;
  final String? middleRoom;
  final String? rightRoom;

  const CheckpointDefinition({
    required this.id,
    required this.name,
    required this.wing,
    required this.description,
    required this.coveredRooms,
    this.leftRoom,
    this.middleRoom,
    this.rightRoom,
  });
}

/// A single neighbour returned by kNN, used for the debug overlay.
class KnnNeighbor {
  final String checkpointId;
  final double distance;
  final double weight;
  final bool isOutlier;

  const KnnNeighbor({
    required this.checkpointId,
    required this.distance,
    required this.weight,
    required this.isOutlier,
  });
}

class PredictionResult {
  final String checkpointId;
  final double distance;
  final double confidence;

  /// Non-empty only when predictWeightedKnn is used.
  final List<KnnNeighbor> knnNeighbors;

  const PredictionResult({
    required this.checkpointId,
    required this.distance,
    required this.confidence,
    this.knnNeighbors = const [],
  });
}

class GraphEdge {
  final String from;
  final String to;
  final double distance;

  const GraphEdge({required this.from, required this.to, required this.distance});
}
