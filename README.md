# MapMyFloor

Indoor navigation Flutter app for Android using local Wi-Fi fingerprinting.

## Project Structure

- `lib/indoor_nav/` contains the UI-independent localization, smoothing, routing, and room-instruction backend.
- `assets/indoor_nav/` contains the bundled checkpoint graph, room mapping, and production fingerprint CSV.
- `tools/process_wifi_scans.py` regenerates fingerprint CSVs from `data/raw_scans/`.
- `data/processed/` contains local processing outputs used to refresh bundled assets.
- `assets/images/` contains floor-plan artwork used by the UI.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
