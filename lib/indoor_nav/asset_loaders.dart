import 'dart:convert';

import 'models.dart';
import 'feature_extractor.dart';

List<String> _nonEmptyLines(String text) {
  return text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Parses the simple RunLevelFingerprints CSV bundled in assets.
/// Assumes feature values are integer RSSI dBm values and missing values are -100.
List<Fingerprint> parseFingerprintsCsv(String csvText) {
  final lines = _nonEmptyLines(csvText);
  if (lines.length < 2) return const [];

  final header = lines.first.split(',').map((v) => v.trim()).toList();
  final sessionIdx = header.indexOf('SessionId');
  final checkpointIdx = header.indexOf('CheckpointId');

  if (sessionIdx < 0 || checkpointIdx < 0) {
    throw FormatException('Fingerprint CSV must include SessionId and CheckpointId columns.');
  }

  final featureIndexes = <String, int>{};
  for (final feature in featureNames) {
    final idx = header.indexOf(feature);
    if (idx < 0) throw FormatException('Fingerprint CSV is missing feature column: $feature');
    featureIndexes[feature] = idx;
  }

  final fingerprints = <Fingerprint>[];
  for (final line in lines.skip(1)) {
    final cols = line.split(',').map((v) => v.trim()).toList();
    if (cols.length < header.length) continue;

    final features = <String, int>{};
    for (final feature in featureNames) {
      final raw = cols[featureIndexes[feature]!];
      features[feature] = int.tryParse(raw) ?? missingRssi;
    }

    fingerprints.add(Fingerprint(
      sessionId: cols[sessionIdx],
      checkpointId: cols[checkpointIdx],
      features: features,
    ));
  }

  return fingerprints;
}

/// Parses CheckpointGraph.json and returns graph edges for path finding.
List<GraphEdge> parseGraphEdgesJson(String jsonText) {
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  final edgeItems = decoded['edges'] as List<dynamic>? ?? const [];
  return edgeItems.map((item) {
    final map = item as Map<String, dynamic>;
    return GraphEdge(
      from: map['from'] as String,
      to: map['to'] as String,
      distance: (map['distance'] as num).toDouble(),
    );
  }).toList();
}

/// Parses RoomMapping.json.
///
/// Current schema maps room labels such as B-412 to rich room metadata. Legacy
/// string values are also accepted so older simple mappings do not crash.
Map<String, RoomInfo> parseRoomMappingJson(String jsonText) {
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  return decoded.map((key, value) {
    final roomKey = normalizeRoomLabel(key);
    if (value is String) {
      final checkpointId = value.trim();
      return MapEntry(
        roomKey,
        RoomInfo(
          destinationRoom: roomKey,
          checkpointId: checkpointId,
          localPosition: 'checkpoint',
          displayName: roomKey,
          finalInstruction: 'At checkpoint $checkpointId, you have reached $roomKey.',
        ),
      );
    }

    final map = value as Map<String, dynamic>;
    return MapEntry(
      roomKey,
      RoomInfo(
        destinationRoom: normalizeRoomLabel(
          (map['destinationRoom'] ?? roomKey).toString(),
        ),
        checkpointId: map['checkpointId'].toString().trim(),
        localPosition: map['localPosition'].toString().trim(),
        displayName: (map['displayName'] ?? roomKey).toString().trim(),
        finalInstruction: map['finalInstruction'].toString().trim(),
      ),
    );
  });
}

/// Parses CheckpointDefinitions.json and returns checkpoint metadata by ID.
Map<String, CheckpointDefinition> parseCheckpointDefinitionsJson(
  String jsonText,
) {
  final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
  final items = decoded['checkpoints'] as List<dynamic>? ?? const [];
  return {
    for (final item in items)
      (item as Map<String, dynamic>)['id'].toString().trim(): CheckpointDefinition(
        id: item['id'].toString().trim(),
        name: item['name'].toString().trim(),
        wing: item['wing'].toString().trim(),
        description: item['description'].toString().trim(),
        coveredRooms: (item['coveredRooms'] as List<dynamic>? ?? const [])
            .map((room) => normalizeRoomLabel(room.toString()))
            .toList(growable: false),
        leftRoom: item['leftRoom']?.toString().trim(),
        middleRoom: item['middleRoom']?.toString().trim(),
        rightRoom: item['rightRoom']?.toString().trim(),
      ),
  };
}
