You are working inside a Flutter/Dart Android app for a 4th-floor indoor navigation project.

Goal:
Build the backend logic layer for checkpoint-based indoor navigation using Wi-Fi fingerprinting. The UI is being built separately. Do not build a backend server. Everything should run locally on-device.

Context:
- The user has 16 fixed localization checkpoints: C0, C1, A1-A7, B1-B7.
- The user has frozen 12 Wi-Fi AP features. Do not add arbitrary APs at runtime.
- The app receives live Wi-Fi scan observations containing BSSID, SSID, RSSI, and frequencyMHz.
- The app must convert live scan observations into the same 12-feature vector used by the training CSV.
- The initial localization model is weighted kNN with k = 3 over CheckpointLevelFingerprints.csv.
- The destination room maps to a checkpoint and final local instruction using RoomMapping.json.
- Routing is checkpoint-to-checkpoint using CheckpointGraph.json and Dijkstra.

Tasks:
1. Copy lib/indoor_nav into the Flutter project under lib/indoor_nav.
2. Copy all files from assets into the Flutter app's assets folder.
3. Add the assets to pubspec.yaml using docs/PubspecAssetsSnippet.yaml as reference.
4. Implement/verify a loader that reads:
   - assets/indoor_nav/CheckpointLevelFingerprints.csv
   - assets/indoor_nav/RunLevelFingerprints.csv
   - assets/indoor_nav/CheckpointGraph.json
   - assets/indoor_nav/CheckpointDefinitions.json
   - assets/indoor_nav/RoomMapping.json
5. Create an IndoorNavEngine object from these asset strings.
6. Add a backend service/state class that exposes:
   - currentFeatureVector: Map<String, int>
   - rawPredictedCheckpoint: String
   - stableCheckpoint: String
   - predictionConfidence: double
   - selectedDestinationRoom: String?
   - destinationCheckpoint: String
   - currentRoute: List<String>
   - finalRoomInstruction: String
   - availableRooms: List<String>
   - availableCheckpoints: List<String>
7. Add a method that accepts List<WifiObservation> from the Android Wi-Fi scan layer and updates prediction.
8. Add a method selectDestinationRoom(String room) that maps the room to a destination checkpoint, computes the route from the stable checkpoint, and exposes final room-position instructions.
9. Keep all logic UI-independent. The frontend should only consume the state fields and call methods.
10. Do not use GPS, internet, backend APIs, or dynamic AP discovery for the core algorithm.

Important implementation rules:
- Missing AP feature value must be -100.
- If multiple raw BSSIDs match the same AP feature, use max RSSI.
- Feature matching uses BSSID prefix + frequency band.
- Use the frozen 12 features in feature_extractor.dart exactly as given.
- Do not change the current algorithm to neural networks or coordinate regression.
- Use weighted kNN with k = 3 by default. Nearest fingerprint can remain available as an explicit fallback/debug option.
- Apply majority-vote smoothing over the last 3-5 predictions.

Integration expectation:
The frontend developer should be able to call something like:

final observations = <WifiObservation>[...];
final prediction = engine.predictCheckpoint(observations);
final route = engine.routeToRoom(
  currentCheckpointId: prediction.stableCheckpointId,
  destinationRoom: 'B-412',
);

Deliverable:
A compiling Flutter/Dart logic layer with simple debug logging and no UI coupling. If the app already has state management, wrap IndoorNavEngine in whatever provider/controller pattern the app uses, but keep the pure logic classes unchanged.
