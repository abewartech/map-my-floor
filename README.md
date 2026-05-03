# MapMyFloor

MapMyFloor is an Android-focused Flutter app for 4th-floor indoor navigation. It runs fully on-device: live Wi-Fi scans are converted into a fixed fingerprint vector, the current checkpoint is predicted locally, and the route to a selected room is computed from bundled graph and room-mapping assets.

The app does not use GPS, a backend server, coordinate regression, neural networks, or dynamic access-point discovery.

## What It Does

- Predicts the user's current checkpoint from Wi-Fi RSSI fingerprints.
- Supports the 16-checkpoint floor model: `C0`, `C1`, `A1`-`A7`, and `B1`-`B7`.
- Routes from the stable checkpoint to the checkpoint associated with the destination room.
- Shows final room-position instructions such as left, middle, or right once the user reaches the destination checkpoint.
- Uses weighted kNN with `k = 3` and local smoothing for checkpoint stabilization.

## Project Structure

- `lib/indoor_nav/` contains the UI-independent backend: feature extraction, fingerprint prediction, smoothing, graph routing, room normalization, and final instructions.
- `lib/navigation_provider.dart` adapts the backend for the Flutter UI and live Wi-Fi scanner.
- `lib/screens/` contains the current-location and map screens.
- `lib/widgets/` contains the floor map, route drawing, and walking overlay widgets.
- `assets/indoor_nav/` contains the production local navigation assets.
- `assets/images/final_floorplan.png` is the floor-plan image used by the map UI.
- `tools/process_wifi_scans.py` regenerates fingerprint CSVs from raw Wi-Fi analyzer exports.
- `test/` contains backend, provider, and widget tests.

## Runtime Assets

The app currently bundles:

- `assets/indoor_nav/RunLevelFingerprints.csv`
- `assets/indoor_nav/CheckpointGraph.json`
- `assets/indoor_nav/CheckpointDefinitions.json`
- `assets/indoor_nav/RoomMapping.json`
- `assets/images/final_floorplan.png`

Generated analysis files and raw scan files should stay outside the app bundle unless the UI explicitly needs them.

## Wi-Fi Fingerprint Rules

The frozen 12-feature AP set is defined in `lib/indoor_nav/feature_extractor.dart`.

Important rules:

- Missing AP feature values are filled with `-100`.
- If multiple scan rows match the same AP feature, the strongest RSSI is used.
- Matching is based on BSSID prefix and frequency band, not SSID alone.
- Extra visible Wi-Fi access points are ignored.

## Regenerating Fingerprints

Put raw scan exports in `data/raw_scans/`, then run:

```powershell
python tools/process_wifi_scans.py --input-dir data/raw_scans --output-dir data/processed
```

Copy the refreshed production fingerprint CSV into:

```text
assets/indoor_nav/RunLevelFingerprints.csv
```

## Running The App

Install dependencies:

```powershell
flutter pub get
```

Run on a connected Android device:

```powershell
flutter run
```

Useful checks:

```powershell
flutter analyze
flutter test
```
