import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_my_floor/indoor_nav.dart';

class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> strings;

  FakeAssetBundle(this.strings);

  @override
  Future<ByteData> load(String key) async {
    final value = strings[key];
    if (value == null) {
      throw FlutterError('Missing fake asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

Map<String, int> _featuresWith(Map<String, int> overrides) {
  return {
    for (final feature in featureNames) feature: missingRssi,
    ...overrides,
  };
}

String _fingerprintCsv() {
  final header = [
    'SessionId',
    'CheckpointId',
    'RunId',
    'ScanCount',
    'MeanMatchedFeatureCount',
    ...featureNames,
  ];

  String row(String sessionId, String checkpointId, Map<String, int> features) {
    return [
      sessionId,
      checkpointId,
      '1',
      '15',
      '1.0',
      ...featureNames.map((feature) => '${features[feature] ?? missingRssi}'),
    ].join(',');
  }

  return [
    header.join(','),
    row('A2_R1', 'A2', _featuresWith({'Ap00Df24G': -65})),
    row('C0_R1', 'C0', _featuresWith({'Ap00Df24G': -90})),
    row('B4_R1', 'B4', _featuresWith({'Ap00Df24G': -45})),
  ].join('\n');
}

String _singleFeatureFingerprintCsv(Map<String, int> checkpointRssi) {
  final header = [
    'SessionId',
    'CheckpointId',
    'RunId',
    'ScanCount',
    'MeanMatchedFeatureCount',
    ...featureNames,
  ];

  String row(String checkpointId, int rssi) {
    final features = _featuresWith({'Ap00Df24G': rssi});
    return [
      '${checkpointId}_R1',
      checkpointId,
      '1',
      '15',
      '1.0',
      ...featureNames.map((feature) => '${features[feature] ?? missingRssi}'),
    ].join(',');
  }

  return [
    header.join(','),
    ...checkpointRssi.entries.map((entry) => row(entry.key, entry.value)),
  ].join('\n');
}

const _graphJson = '''
{
  "edges": [
    {"from":"C1","to":"C0","distance":1.0},
    {"from":"C1","to":"A1","distance":1.0},
    {"from":"C0","to":"A1","distance":1.0},
    {"from":"A1","to":"A2","distance":1.0},
    {"from":"A1","to":"A7","distance":1.0},
    {"from":"A7","to":"A2","distance":1.0},
    {"from":"A2","to":"A3","distance":1.0},
    {"from":"A3","to":"A4","distance":1.0},
    {"from":"A3","to":"A6","distance":1.0},
    {"from":"A6","to":"A4","distance":1.0},
    {"from":"A4","to":"A5","distance":1.0},
    {"from":"C0","to":"B1","distance":1.0},
    {"from":"B1","to":"B2","distance":1.0},
    {"from":"B1","to":"B7","distance":1.0},
    {"from":"B7","to":"B2","distance":1.0},
    {"from":"B2","to":"B3","distance":1.0},
    {"from":"B3","to":"B4","distance":1.0},
    {"from":"B3","to":"B6","distance":1.0},
    {"from":"B6","to":"B4","distance":1.0},
    {"from":"B4","to":"B5","distance":1.0}
  ]
}
''';

const _roomMappingJson = '''
{
  "B-412": {
    "destinationRoom": "B-412",
    "checkpointId": "B4",
    "localPosition": "left",
    "displayName": "B-412",
    "finalInstruction": "At checkpoint B4, B-412 is on the left, B-411 is in the middle, and B-410 is on the right. Your destination B-412 is on the left."
  },
  "B-413": {
    "destinationRoom": "B-413",
    "checkpointId": "B6",
    "localPosition": "right",
    "displayName": "B-413",
    "finalInstruction": "At checkpoint B6, B-415 is on the left, B-414 is in the middle, and B-413 is on the right. Your destination B-413 is on the right."
  },
  "B-414": {
    "destinationRoom": "B-414",
    "checkpointId": "B6",
    "localPosition": "middle",
    "displayName": "B-414",
    "finalInstruction": "At checkpoint B6, B-415 is on the left, B-414 is in the middle, and B-413 is on the right. Your destination B-414 is in the middle."
  },
  "B-415": {
    "destinationRoom": "B-415",
    "checkpointId": "B6",
    "localPosition": "left",
    "displayName": "B-415",
    "finalInstruction": "At checkpoint B6, B-415 is on the left, B-414 is in the middle, and B-413 is on the right. Your destination B-415 is on the left."
  },
  "A-413": {
    "destinationRoom": "A-413",
    "checkpointId": "A6",
    "localPosition": "left",
    "displayName": "A-413",
    "finalInstruction": "At checkpoint A6, A-413 is on the left, A-414 is in the middle, and A-415 is on the right. Your destination A-413 is on the left."
  },
  "A-415": {
    "destinationRoom": "A-415",
    "checkpointId": "A6",
    "localPosition": "right",
    "displayName": "A-415",
    "finalInstruction": "At checkpoint A6, A-413 is on the left, A-414 is in the middle, and A-415 is on the right. Your destination A-415 is on the right."
  },
  "A-401": {
    "destinationRoom": "A-401",
    "checkpointId": "A1",
    "localPosition": "left",
    "displayName": "A-401",
    "finalInstruction": "At checkpoint A1, A-401 is on the left, A-402 is in the middle, and A-403 is on the right. Your destination A-401 is on the left."
  },
  "A-403": {
    "destinationRoom": "A-403",
    "checkpointId": "A1",
    "localPosition": "right",
    "displayName": "A-403",
    "finalInstruction": "At checkpoint A1, A-401 is on the left, A-402 is in the middle, and A-403 is on the right. Your destination A-403 is on the right."
  },
  "A-404": {
    "destinationRoom": "A-404",
    "checkpointId": "A2",
    "localPosition": "left",
    "displayName": "A-404",
    "finalInstruction": "At checkpoint A2, A-404 is on the left, A-405 is in the middle, and A-406 is on the right. Your destination A-404 is on the left."
  },
  "A-406": {
    "destinationRoom": "A-406",
    "checkpointId": "A2",
    "localPosition": "right",
    "displayName": "A-406",
    "finalInstruction": "At checkpoint A2, A-404 is on the left, A-405 is in the middle, and A-406 is on the right. Your destination A-406 is on the right."
  },
  "A-407": {
    "destinationRoom": "A-407",
    "checkpointId": "A3",
    "localPosition": "left",
    "displayName": "A-407",
    "finalInstruction": "At checkpoint A3, A-407 is on the left, A-408 is in the middle, and A-409 is on the right. Your destination A-407 is on the left."
  },
  "A-409": {
    "destinationRoom": "A-409",
    "checkpointId": "A3",
    "localPosition": "right",
    "displayName": "A-409",
    "finalInstruction": "At checkpoint A3, A-407 is on the left, A-408 is in the middle, and A-409 is on the right. Your destination A-409 is on the right."
  },
  "A-410": {
    "destinationRoom": "A-410",
    "checkpointId": "A4",
    "localPosition": "left",
    "displayName": "A-410",
    "finalInstruction": "At checkpoint A4, A-410 is on the left, A-411 is in the middle, and A-412 is on the right. Your destination A-410 is on the left."
  },
  "A-412": {
    "destinationRoom": "A-412",
    "checkpointId": "A4",
    "localPosition": "right",
    "displayName": "A-412",
    "finalInstruction": "At checkpoint A4, A-410 is on the left, A-411 is in the middle, and A-412 is on the right. Your destination A-412 is on the right."
  },
  "A-417": {
    "destinationRoom": "A-417",
    "checkpointId": "A7",
    "localPosition": "middle",
    "displayName": "A-417",
    "finalInstruction": "At checkpoint A7, A-416 is on the left, A-417 is in the middle, and A-418 is on the right. Your destination A-417 is in the middle."
  },
  "A-416": {
    "destinationRoom": "A-416",
    "checkpointId": "A7",
    "localPosition": "left",
    "displayName": "A-416",
    "finalInstruction": "At checkpoint A7, A-416 is on the left, A-417 is in the middle, and A-418 is on the right. Your destination A-416 is on the left."
  },
  "A-418": {
    "destinationRoom": "A-418",
    "checkpointId": "A7",
    "localPosition": "right",
    "displayName": "A-418",
    "finalInstruction": "At checkpoint A7, A-416 is on the left, A-417 is in the middle, and A-418 is on the right. Your destination A-418 is on the right."
  },
  "A-419": {
    "destinationRoom": "A-419",
    "checkpointId": "C0",
    "localPosition": "left",
    "displayName": "A-419",
    "finalInstruction": "At checkpoint C0, A-419 is on the left, A-420 is in the middle, and B-419 is on the right. Your destination A-419 is on the left."
  },
  "A-420": {
    "destinationRoom": "A-420",
    "checkpointId": "C0",
    "localPosition": "middle",
    "displayName": "A-420",
    "finalInstruction": "At checkpoint C0, A-419 is on the left, A-420 is in the middle, and B-419 is on the right. Your destination A-420 is in the middle."
  },
  "B-419": {
    "destinationRoom": "B-419",
    "checkpointId": "C0",
    "localPosition": "right",
    "displayName": "B-419",
    "finalInstruction": "At checkpoint C0, A-419 is on the left, A-420 is in the middle, and B-419 is on the right. Your destination B-419 is on the right."
  }
}
''';

const _checkpointDefinitionsJson = '''
{
  "checkpoints": [
    {
      "id": "C0",
      "name": "CentralCore_B419_A420_A419",
      "wing": "Core",
      "description": "Central core checkpoint.",
      "coveredRooms": ["A-419", "A-420", "B-419"]
    },
    {
      "id": "B6",
      "name": "B413_B415",
      "wing": "B",
      "description": "B-wing lab/common-room side checkpoint.",
      "coveredRooms": ["B-413", "B-414", "B-415"],
      "leftRoom": "B-415",
      "middleRoom": "B-414",
      "rightRoom": "B-413"
    }
  ]
}
''';

List<WifiObservation> _a2Observations() {
  return const [
    WifiObservation(
      bssid: '00:df:1d:6a:9c:22',
      ssid: 'eduroam',
      rssi: -65,
      frequencyMHz: 2412,
    ),
  ];
}

List<WifiObservation> _singleFeatureObservations(int rssi) {
  return [
    WifiObservation(
      bssid: '00:df:1d:6a:9c:22',
      ssid: 'eduroam',
      rssi: rssi,
      frequencyMHz: 2412,
    ),
  ];
}

void main() {
  test('room labels normalize to supported display form', () {
    expect(normalizeRoomLabel('b-412'), 'B-412');
    expect(normalizeRoomLabel('B412'), 'B-412');
    expect(normalizeRoomLabel('a420'), 'A-420');
  });

  test('matchedFeatureCount correctly counts values above -100', () {
    expect(matchedFeatureCount(_featuresWith({})), 0);
    expect(
      matchedFeatureCount(
        _featuresWith({'Ap00Df24G': -65, 'Ap2436DaA3895G': -80}),
      ),
      2,
    );
    expect(matchedFeatureCount({}), 0);
  });

  test('feature extraction keeps frozen features and strongest matching RSSI', () {
    final vector = extractFeatureVector(const [
      WifiObservation(
        bssid: '00:df:1d:6a:9c:20',
        ssid: 'GUEST-N',
        rssi: -72,
        frequencyMHz: 2412,
      ),
      WifiObservation(
        bssid: '00:df:1d:6a:9c:22',
        ssid: 'eduroam',
        rssi: -61,
        frequencyMHz: 2412,
      ),
      WifiObservation(
        bssid: '00:df:1d:6a:9c:2d',
        ssid: 'eduroam',
        rssi: -58,
        frequencyMHz: 5805,
      ),
      WifiObservation(
        bssid: 'de:ad:be:ef:00:01',
        ssid: 'Ignored',
        rssi: -20,
        frequencyMHz: 2412,
      ),
    ]);

    expect(vector.keys, containsAll(featureNames));
    expect(vector.length, featureNames.length);
    expect(vector['Ap00Df24G'], -61);
    expect(vector['Ap00Df5G'], -58);
    expect(vector['Ap40017A539724G'], missingRssi);
  });

  test('nearest and weighted kNN predictions use fingerprint distances', () {
    final predictor = FingerprintPredictor([
      Fingerprint(
        checkpointId: 'A2',
        sessionId: 'A2_R1',
        features: _featuresWith({'Ap00Df24G': -65}),
      ),
      Fingerprint(
        checkpointId: 'C0',
        sessionId: 'C0_R1',
        features: _featuresWith({'Ap00Df24G': -90}),
      ),
      Fingerprint(
        checkpointId: 'B4',
        sessionId: 'B4_R1',
        features: _featuresWith({'Ap00Df24G': -45}),
      ),
    ]);

    final live = _featuresWith({'Ap00Df24G': -66});

    expect(predictor.predictNearest(live).checkpointId, 'A2');
    expect(predictor.predictWeightedKnn(live, k: 3).checkpointId, 'A2');
  });

  test('missing-aware distance penalizes one-sided missing and ignores double-missing', () {
    final predictor = FingerprintPredictor([
      Fingerprint(
        checkpointId: 'A1',
        sessionId: 'S1',
        // Sparse fingerprint: only 1 feature
        features: _featuresWith({'Ap00Df24G': -70}),
      ),
    ]);

    // 1. Exact match
    final live1 = _featuresWith({'Ap00Df24G': -70});
    final res1 = predictor.predictNearest(live1);
    expect(res1.checkpointId, 'A1');
    expect(res1.distance, 0.0);
    expect(res1.confidence, 1.0);

    // 2. Double missing (no overlap)
    // live has Ap00Df5G, fingerprint has Ap00Df24G.
    final live2 = _featuresWith({'Ap00Df5G': -70});
    final res2 = predictor.predictNearest(live2);
    // Overlap is 0, so distance should be infinity
    expect(res2.distance, double.infinity);
    expect(res2.confidence, 0.0);

    // 3. One-sided missing penalty
    // Fingerprint has Ap00Df24G: -70.
    // Live has Ap00Df24G: -70 AND Ap00Df5G: -70.
    // Ap00Df5G is missing in fingerprint -> penalty 15.
    final live3 = _featuresWith({'Ap00Df24G': -70, 'Ap00Df5G': -70});
    final res3 = predictor.predictNearest(live3);
    expect(res3.checkpointId, 'A1');
    expect(res3.distance, 15.0); // sqrt(0^2 + 15^2) = 15
  });

  test('fingerprint parser accepts available rows without requiring 16 checkpoints', () {
    final fingerprints = parseFingerprintsCsv(_fingerprintCsv());

    expect(fingerprints, hasLength(3));
    expect(fingerprints.map((fp) => fp.checkpointId), ['A2', 'C0', 'B4']);
  });

  test('room mapping exposes checkpoint, local position, and instructions', () {
    final rooms = parseRoomMappingJson(_roomMappingJson);

    expect(rooms['B-414']!.checkpointId, 'B6');
    expect(rooms['B-414']!.localPosition, 'middle');
    expect(rooms['B-415']!.checkpointId, 'B6');
    expect(rooms['B-415']!.localPosition, 'left');
    expect(rooms['B-413']!.checkpointId, 'B6');
    expect(rooms['B-413']!.localPosition, 'right');
    expect(rooms['A-401']!.checkpointId, 'A1');
    expect(rooms['A-401']!.localPosition, 'left');
    expect(rooms['A-403']!.checkpointId, 'A1');
    expect(rooms['A-403']!.localPosition, 'right');
    expect(rooms['A-404']!.checkpointId, 'A2');
    expect(rooms['A-404']!.localPosition, 'left');
    expect(rooms['A-406']!.checkpointId, 'A2');
    expect(rooms['A-406']!.localPosition, 'right');
    expect(rooms['A-407']!.checkpointId, 'A3');
    expect(rooms['A-407']!.localPosition, 'left');
    expect(rooms['A-409']!.checkpointId, 'A3');
    expect(rooms['A-409']!.localPosition, 'right');
    expect(rooms['A-410']!.checkpointId, 'A4');
    expect(rooms['A-410']!.localPosition, 'left');
    expect(rooms['A-412']!.checkpointId, 'A4');
    expect(rooms['A-412']!.localPosition, 'right');
    expect(rooms['A-413']!.checkpointId, 'A6');
    expect(rooms['A-413']!.localPosition, 'left');
    expect(rooms['A-415']!.checkpointId, 'A6');
    expect(rooms['A-415']!.localPosition, 'right');
    expect(rooms['A-417']!.checkpointId, 'A7');
    expect(rooms['A-417']!.localPosition, 'middle');
    expect(rooms['A-416']!.checkpointId, 'A7');
    expect(rooms['A-416']!.localPosition, 'left');
    expect(rooms['A-418']!.checkpointId, 'A7');
    expect(rooms['A-418']!.localPosition, 'right');
    expect(rooms['A-419']!.checkpointId, 'C0');
    expect(rooms['A-419']!.localPosition, 'left');
    expect(rooms['A-420']!.checkpointId, 'C0');
    expect(rooms['A-420']!.localPosition, 'middle');
    expect(rooms['B-419']!.checkpointId, 'C0');
    expect(rooms['B-419']!.localPosition, 'right');
  });

  test('smoother returns stable checkpoint and can reset', () {
    final smoother = PredictionSmoother(requiredConsecutive: 3, minConfidence: 0.5);

    // Initial stabilization
    expect(smoother.update(checkpointId: 'A2', confidence: 0.6), 'A2');
    
    // Low confidence prediction doesn't change stable (stays A2)
    expect(smoother.update(checkpointId: 'B4', confidence: 0.4), 'A2');
    
    // New checkpoint needs 3 hits
    expect(smoother.update(checkpointId: 'B4', confidence: 0.6), 'A2'); // candidate count 1
    expect(smoother.update(checkpointId: 'B4', confidence: 0.6), 'A2'); // candidate count 2
    expect(smoother.update(checkpointId: 'B4', confidence: 0.6), 'B4'); // stabilized to B4

    smoother.reset();
    expect(smoother.current, '');
  });

  test('smoother handles noise with decayed candidate evidence', () {
    final smoother = PredictionSmoother(
      requiredConsecutive: 3,
      minConfidence: 0.45,
    );

    // 1. Initial stable checkpoint
    expect(smoother.update(checkpointId: 'B1', confidence: 0.9), 'B1');

    // 2. Start candidate B2
    expect(smoother.update(checkpointId: 'B2', confidence: 0.7), 'B1');
    expect(smoother.candidateDebugLabel, 'B2');
    expect(smoother.candidateDebugCount, 1);

    expect(smoother.update(checkpointId: 'B2', confidence: 0.7), 'B1');
    expect(smoother.candidateDebugCount, 2);

    // 3. Noisy B1 (the current stable) should decay B2 count, not reset it.
    expect(smoother.update(checkpointId: 'B1', confidence: 0.7), 'B1');
    expect(smoother.candidateDebugLabel, 'B2');
    expect(smoother.candidateDebugCount, 1);

    // 4. B2 recovers
    expect(smoother.update(checkpointId: 'B2', confidence: 0.7), 'B1');
    expect(smoother.candidateDebugCount, 2);

    expect(smoother.update(checkpointId: 'B2', confidence: 0.7), 'B2');
    expect(smoother.candidateDebugLabel, isNull);
    expect(smoother.candidateDebugCount, 0);
  });

  test('smoother low confidence and unknown should not decay or change stable', () {
    final smoother = PredictionSmoother(requiredConsecutive: 3, minConfidence: 0.5);
    
    // Set stable B1 and candidate B2 with count 1
    smoother.update(checkpointId: 'B1', confidence: 0.9);
    smoother.update(checkpointId: 'B2', confidence: 0.7);
    expect(smoother.candidateDebugCount, 1);

    // Low confidence should not change anything
    smoother.update(checkpointId: 'B2', confidence: 0.2);
    expect(smoother.current, 'B1');
    expect(smoother.candidateDebugCount, 1);

    // Unknown should not change anything
    smoother.update(checkpointId: 'Unknown', confidence: 0.0);
    expect(smoother.current, 'B1');
    expect(smoother.candidateDebugCount, 1);
  });

  test('smoother noisy different candidate should decay previous candidate', () {
    final smoother = PredictionSmoother(requiredConsecutive: 3, minConfidence: 0.5);
    
    smoother.update(checkpointId: 'B1', confidence: 0.9);
    smoother.update(checkpointId: 'B2', confidence: 0.7);
    smoother.update(checkpointId: 'B2', confidence: 0.7);
    expect(smoother.candidateDebugCount, 2);

    // B3 appears once, should decay B2 count
    smoother.update(checkpointId: 'B3', confidence: 0.7);
    expect(smoother.candidateDebugLabel, 'B2');
    expect(smoother.candidateDebugCount, 1);

    // B2 recovers
    smoother.update(checkpointId: 'B2', confidence: 0.7);
    smoother.update(checkpointId: 'B2', confidence: 0.7);
    expect(smoother.current, 'B2');
  });

  test('path finder routes across wings through central core', () {
    final pathFinder = GraphPathFinder(const [
      GraphEdge(from: 'C1', to: 'C0', distance: 1),
      GraphEdge(from: 'C1', to: 'A1', distance: 1),
      GraphEdge(from: 'C0', to: 'A1', distance: 1),
      GraphEdge(from: 'A1', to: 'A2', distance: 1),
      GraphEdge(from: 'A1', to: 'A7', distance: 1),
      GraphEdge(from: 'A7', to: 'A2', distance: 1),
      GraphEdge(from: 'A2', to: 'A3', distance: 1),
      GraphEdge(from: 'A3', to: 'A4', distance: 1),
      GraphEdge(from: 'A3', to: 'A6', distance: 1),
      GraphEdge(from: 'A6', to: 'A4', distance: 1),
      GraphEdge(from: 'A4', to: 'A5', distance: 1),
      GraphEdge(from: 'C0', to: 'B1', distance: 1),
      GraphEdge(from: 'B1', to: 'B2', distance: 1),
      GraphEdge(from: 'B1', to: 'B7', distance: 1),
      GraphEdge(from: 'B7', to: 'B2', distance: 1),
      GraphEdge(from: 'B2', to: 'B3', distance: 1),
      GraphEdge(from: 'B3', to: 'B4', distance: 1),
      GraphEdge(from: 'B3', to: 'B6', distance: 1),
      GraphEdge(from: 'B6', to: 'B4', distance: 1),
      GraphEdge(from: 'B4', to: 'B5', distance: 1),
    ]);

    expect(
      pathFinder.shortestPath('C1', 'B6'),
      ['C1', 'C0', 'B1', 'B2', 'B3', 'B6'],
    );
    expect(
      pathFinder.shortestPath('A2', 'B4'),
      ['A2', 'A1', 'C0', 'B1', 'B2', 'B3', 'B4'],
    );
    expect(pathFinder.shortestPath('C1', 'A7'), ['C1', 'A1', 'A7']);
    expect(pathFinder.shortestPath('A7', 'A6'), ['A7', 'A2', 'A3', 'A6']);
    expect(pathFinder.shortestPath('A6', 'A5'), ['A6', 'A4', 'A5']);
    expect(pathFinder.shortestPath('B7', 'B6'), ['B7', 'B2', 'B3', 'B6']);
    expect(pathFinder.shortestPath('B6', 'B5'), ['B6', 'B4', 'B5']);
    expect(pathFinder.shortestPath('B4', 'B4'), ['B4']);
  });

  test('engine routes to room metadata and final instruction', () {
    final engine = IndoorNavEngine.fromAssetStrings(
      fingerprintCsv: _fingerprintCsv(),
      checkpointGraphJson: _graphJson,
      roomMappingJson: _roomMappingJson,
      checkpointDefinitionsJson: _checkpointDefinitionsJson,
    );

    final route = engine.routeToRoom(
      currentCheckpointId: 'C1',
      destinationRoom: 'b414',
    );

    expect(route.destinationRoom, 'B-414');
    expect(route.destinationCheckpointId, 'B6');
    expect(route.localPosition, 'middle');
    expect(route.checkpointPath, ['C1', 'C0', 'B1', 'B2', 'B3', 'B6']);
    expect(
      route.finalInstruction,
      'At checkpoint B6, B-415 is on the left, B-414 is in the middle, and B-413 is on the right. Your destination B-414 is in the middle.',
    );

    final aWingRoute = engine.routeToRoom(
      currentCheckpointId: 'C1',
      destinationRoom: 'A-417',
    );
    expect(aWingRoute.destinationCheckpointId, 'A7');
    expect(aWingRoute.checkpointPath, ['C1', 'A1', 'A7']);

    expect(
      engine.routeToRoom(
        currentCheckpointId: 'B4',
        destinationRoom: 'B-412',
      ).checkpointPath,
      ['B4'],
    );
  });

  test('engine rejects empty scans and maintains stable checkpoint', () {
    final engine = IndoorNavEngine.fromAssetStrings(
      fingerprintCsv: _fingerprintCsv(),
      checkpointGraphJson: _graphJson,
      roomMappingJson: _roomMappingJson,
      checkpointDefinitionsJson: _checkpointDefinitionsJson,
      requiredConsecutive: 1, // Fast stabilization for test
    );

    // First, stabilize to A2
    final p1 = engine.predictCheckpoint(_a2Observations());
    expect(p1.stableCheckpointId, 'A2');

    // Then, send empty scan
    final p2 = engine.predictCheckpoint(const []);
    expect(p2.rawPrediction.checkpointId, 'Unknown');
    expect(p2.stableCheckpointId, 'A2');
  });

  test('engine projects skipped raw predictions onto next graph checkpoint', () {
    final engine = IndoorNavEngine.fromAssetStrings(
      fingerprintCsv: _singleFeatureFingerprintCsv({
        'A2': -80,
        'A4': -55,
        'B2': -70,
        'B4': -45,
      }),
      checkpointGraphJson: _graphJson,
      roomMappingJson: _roomMappingJson,
      checkpointDefinitionsJson: _checkpointDefinitionsJson,
      requiredConsecutive: 3,
    );

    engine.predictCheckpoint(_singleFeatureObservations(-70));
    expect(engine.smoother.current, 'B2');

    var prediction = engine.predictCheckpoint(_singleFeatureObservations(-45));
    expect(prediction.rawPrediction.checkpointId, 'B4');
    expect(prediction.stableCheckpointId, 'B2'); // Call 2 (Hit 1): needs 4 (B2 visible)

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-45));
    expect(prediction.rawPrediction.checkpointId, 'B4');
    expect(prediction.stableCheckpointId, 'B2'); // Call 3 (Hit 2): needs 3 (B2 not visible in [B4, B4])

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-45));
    expect(prediction.rawPrediction.checkpointId, 'B4');
    expect(prediction.stableCheckpointId, 'B3'); // Call 4 (Hit 3): stable becomes B3 (count 3 >= needed 3)

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-45));
    expect(prediction.stableCheckpointId, 'B4'); // Call 5: moves to B4 immediately (B3 not in raw history)

    engine.resetSmoothing();
    engine.predictCheckpoint(_singleFeatureObservations(-80));
    expect(engine.smoother.current, 'A2');

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-55));
    expect(prediction.rawPrediction.checkpointId, 'A4');
    expect(prediction.stableCheckpointId, 'A2'); // Call 2 (Hit 1)

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-55));
    expect(prediction.rawPrediction.checkpointId, 'A4');
    expect(prediction.stableCheckpointId, 'A2'); // Call 3 (Hit 2)

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-55));
    expect(prediction.rawPrediction.checkpointId, 'A4');
    expect(prediction.stableCheckpointId, 'A3'); // Call 4 (Hit 3)

    prediction = engine.predictCheckpoint(_singleFeatureObservations(-55));
    expect(prediction.stableCheckpointId, 'A4'); // Call 5: moves to A4 immediately
  });

  test('engine applies early arrival fix with central core guard', () {
    final engine = IndoorNavEngine.fromAssetStrings(
      fingerprintCsv: _singleFeatureFingerprintCsv({
        'C0': -90,
        'A1': -75,
        'A5': -40,
        'B1': -80,
        'B3': -50,
      }),
      checkpointGraphJson: _graphJson,
      roomMappingJson: _roomMappingJson,
      checkpointDefinitionsJson: _checkpointDefinitionsJson,
      requiredConsecutive: 3,
    );

    // 1. Stabilize to C0
    engine.predictCheckpoint(_singleFeatureObservations(-90));
    expect(engine.smoother.current, 'C0');

    // 2. Far prediction A5 while at C0 should NOT project to A1
    var p = engine.predictCheckpoint(_singleFeatureObservations(-40));
    expect(p.rawPrediction.checkpointId, 'A5');
    expect(p.stableCheckpointId, 'C0'); // Blocked by core guard

    // 3. Direct neighbor A1 can move to A1
    engine.predictCheckpoint(_singleFeatureObservations(-75));
    expect(engine.smoother.current, 'C0'); // Hit 1: needs 3 (C0 visible)
    
    engine.predictCheckpoint(_singleFeatureObservations(-75));
    expect(engine.smoother.current, 'A1'); // Hit 2: needs 2 (C0 not visible)

    // 4. Far prediction B3 while at B1 should project to B2
    engine.resetSmoothing();
    engine.predictCheckpoint(_singleFeatureObservations(-80));
    expect(engine.smoother.current, 'B1');

    p = engine.predictCheckpoint(_singleFeatureObservations(-50));
    expect(p.rawPrediction.checkpointId, 'B3');
    // B1 to B3 path: [B1, B2, B3]. Length 3.
    // Projected target: B2.
    // Confidence reduction: 1.0 * 0.6 = 0.6.
    // B1 visible in [B1, B3]? Yes. Required hits = 4.
    expect(p.stableCheckpointId, 'B1'); // Call 2 (Hit 1)

    engine.predictCheckpoint(_singleFeatureObservations(-50));
    expect(engine.smoother.current, 'B1'); // Call 3 (Hit 2): needs 3 (B1 not visible)

    engine.predictCheckpoint(_singleFeatureObservations(-50));
    expect(engine.smoother.current, 'B2'); // Call 4 (Hit 3): count 3 >= needed 3.
  });

  test('engine verifies specific precision and stability scenarios', () {
    final engine = IndoorNavEngine.fromAssetStrings(
      fingerprintCsv: _singleFeatureFingerprintCsv({
        'C0': -90,
        'A1': -75,
        'B1': -80,
        'B2': -70,
        'B3': -60,
        'B4': -50,
      }),
      checkpointGraphJson: _graphJson,
      roomMappingJson: _roomMappingJson,
      checkpointDefinitionsJson: _checkpointDefinitionsJson,
      requiredConsecutive: 3,
    );

    // 1. Central flicker should not switch early
    engine.predictCheckpoint(_singleFeatureObservations(-90));
    expect(engine.smoother.current, 'C0');

    // Sequence: A1, C0, A1, C0
    engine.predictCheckpoint(_singleFeatureObservations(-75)); // raw=A1, target=A1
    expect(engine.smoother.current, 'C0');
    engine.predictCheckpoint(_singleFeatureObservations(-90)); // raw=C0, target=C0
    expect(engine.smoother.current, 'C0');
    engine.predictCheckpoint(_singleFeatureObservations(-75)); // raw=A1, target=A1
    expect(engine.smoother.current, 'C0');
    engine.predictCheckpoint(_singleFeatureObservations(-90)); // raw=C0, target=C0
    expect(engine.smoother.current, 'C0');

    // 2. Corridor should not switch early if old stable is still visible
    engine.resetSmoothing();
    engine.predictCheckpoint(_singleFeatureObservations(-80)); // Stable B1
    expect(engine.smoother.current, 'B1');

    // Sequence: B3, B1, B3
    engine.predictCheckpoint(_singleFeatureObservations(-60)); // raw=B3, target=B2. needed=4 (B1 visible)
    expect(engine.smoother.current, 'B1');
    engine.predictCheckpoint(_singleFeatureObservations(-80)); // raw=B1, target=B1. decays B2 candidate
    expect(engine.smoother.current, 'B1');
    engine.predictCheckpoint(_singleFeatureObservations(-60)); // raw=B3, target=B2. needed=4 (B1 visible)
    expect(engine.smoother.current, 'B1');

    // 3. High-confidence direct neighbor can update after one hit only if old stable not visible
    engine.resetSmoothing();
    engine.predictCheckpoint(_singleFeatureObservations(-80)); // stable B1
    // Fill history with B2 to push B1 out (history size 4)
    engine.predictCheckpoint(_singleFeatureObservations(-70));
    engine.predictCheckpoint(_singleFeatureObservations(-70));
    engine.predictCheckpoint(_singleFeatureObservations(-70));
    engine.predictCheckpoint(_singleFeatureObservations(-70));
    expect(engine.smoother.current, 'B2'); // Stable became B2 after evidence
    
    // Now from B2, if we see B1 with high confidence and B2 is gone from history
    // History is [B2, B2, B2, B2]. B2 is visible.
    // We need 4 more calls with no B2 to push it out.
    engine.predictCheckpoint(_singleFeatureObservations(-80)); // raw=B1, target=B1. needed=3 (B2 visible)
    expect(engine.smoother.current, 'B2');

    // 4. Graph-projected confidence reduction
    engine.resetSmoothing();
    engine.predictCheckpoint(_singleFeatureObservations(-80)); // Stable B1
    
    // raw = B3 (-60). Path [B1, B2, B3]. Length 3.
    // target = B2 (projected).
    // raw confidence is 1.0 (exact match).
    // effective confidence should be 0.60.
    final p = engine.predictCheckpoint(_singleFeatureObservations(-60));
    expect(p.rawPrediction.checkpointId, 'B3');
    expect(p.rawPrediction.confidence, 1.0);
    // There's no public way to see effectiveConfidence passed to smoother,
    // but we can verify it indirectly if it falls below threshold.
    // If we used a raw prediction with confidence 0.7, 0.7 * 0.6 = 0.42.
    // 0.42 < 0.45 (minConfidence), so it would be ignored.
  });

  test('controller exposes destination and final instruction state', () async {
    final controller = IndoorNavController(
      assetBundle: FakeAssetBundle({
        defaultFingerprintAssetPath: _fingerprintCsv(),
        defaultCheckpointGraphAssetPath: _graphJson,
        defaultRoomMappingAssetPath: _roomMappingJson,
        defaultCheckpointDefinitionsAssetPath: _checkpointDefinitionsJson,
      }),
    );

    await controller.loadAssets();

    controller.selectDestinationRoom(' b 412 ');
    expect(controller.selectedDestinationRoom, 'B-412');
    expect(controller.destinationCheckpoint, 'B4');
    expect(controller.finalRoomInstruction, contains('Your destination B-412'));
    expect(controller.currentRoute, isEmpty);

    controller.updateFromWifiScan(_a2Observations());
    expect(controller.currentFeatureVector['Ap00Df24G'], -65);
    expect(controller.rawPredictedCheckpoint, 'A2');
    expect(controller.stableCheckpoint, 'A2');
    expect(
      controller.currentRoute,
      ['A2', 'A1', 'C0', 'B1', 'B2', 'B3', 'B4'],
    );
    expect(controller.availableRooms, containsAll(['A-417', 'B-414']));
    expect(controller.availableCheckpoints, containsAll(['C0', 'B6']));

    expect(() => controller.selectDestinationRoom('Z-999'), throwsArgumentError);
  });
}
