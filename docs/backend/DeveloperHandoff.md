# Indoor Navigation Backend Handoff

## Core app loop

1. Android Wi-Fi scan returns raw access point observations.
2. Convert plugin/native scan rows into `WifiObservation`.
3. Call `IndoorNavController.updateFromWifiScan(observations)`.
4. Read `stableCheckpoint`, `predictionConfidence`, and `currentFeatureVector`.
5. When user selects a room, call `IndoorNavController.selectDestinationRoom(...)`.
6. Draw `currentRoute` on the floor map and show `finalRoomInstruction`.

## Data assumptions

- Current dataset is Run 1 only.
- Production prediction loads `CheckpointLevelFingerprints.csv` by default.
- `RunLevelFingerprints.csv` is kept as the 48-row run-level debug/tuning dataset.
- The graph and room mapping support 16 checkpoints immediately.
- The predictor uses whichever fingerprint rows are present in the CSV.
- The controller uses weighted kNN with `knnK = 3` by default.
- Current routing routes to the room's destination checkpoint, then shows a final local room-position instruction.

## Files to copy into Flutter

- `lib/indoor_nav/*.dart` -> Flutter `lib/indoor_nav/`
- `assets/*` -> Flutter `assets/`

## Required live scan fields

The Android scan layer must provide:

- `bssid`: String
- `ssid`: String
- `rssi`: int dBm
- `frequencyMHz`: int

## Flutter asset loading sketch

```dart
final controller = IndoorNavController();
await controller.loadAssets();

controller.updateFromWifiScan(observations);
controller.selectDestinationRoom('B-412');

final stableCheckpoint = controller.stableCheckpoint;
final destinationCheckpoint = controller.destinationCheckpoint;
final route = controller.currentRoute;
final finalInstruction = controller.finalRoomInstruction;
```

Use `IndoorNavEngine.fromAssetStrings(...)` directly only if the app does not want
a `ChangeNotifier` state wrapper.
