import 'dart:async';

import 'package:flutter/foundation.dart';

import 'indoor_nav.dart';
import 'wifi_service.dart';

class NavigationProvider extends ChangeNotifier {
  static const String unknownCheckpoint = 'Unknown';
  static const Duration defaultScanInterval = Duration(seconds: 1);
  static const int defaultRequiredConsecutive = 3;

  final IndoorNavController _indoorNavController;
  final WifiObservationSource _wifiSource;
  final Duration scanInterval;
  final bool _ownsController;

  Timer? _scanTimer;
  bool _isInitializing = false;
  bool _isScanning = false;
  bool _scanInProgress = false;
  String? _lastError;

  NavigationProvider({
    IndoorNavController? indoorNavController,
    WifiObservationSource? wifiSource,
    this.scanInterval = defaultScanInterval,
  }) : _indoorNavController =
            indoorNavController ??
            IndoorNavController(
              requiredConsecutive: defaultRequiredConsecutive,
            ),
        _wifiSource = wifiSource ?? const WiFiService(),
        _ownsController = indoorNavController == null {
    _indoorNavController.addListener(notifyListeners);
  }

  IndoorNavController get backend => _indoorNavController;

  bool get isReady => _indoorNavController.isLoaded && !_isInitializing;
  bool get isScanning => _isScanning;
  String? get lastError => _lastError;

  Map<String, int> get currentFeatureVector =>
      _indoorNavController.currentFeatureVector;
  String get rawPredictedCheckpoint =>
      _indoorNavController.rawPredictedCheckpoint;
  String get currentCheckpointId =>
      _indoorNavController.stableCheckpoint.isEmpty
          ? unknownCheckpoint
          : _indoorNavController.stableCheckpoint;
  String get stableCheckpoint => currentCheckpointId;
  double get predictionConfidence =>
      _indoorNavController.predictionConfidence;
  String? get destinationRoomId =>
      _indoorNavController.selectedDestinationRoom;
  String get destinationCheckpoint =>
      _indoorNavController.destinationCheckpoint;
  List<String> get currentPath => _indoorNavController.currentRoute;
  String get finalRoomInstruction =>
      _indoorNavController.finalRoomInstruction;
  List<String> get availableRooms => _indoorNavController.availableRooms;
  List<String> get availableCheckpoints =>
      _indoorNavController.availableCheckpoints;

  RoomInfo? get selectedRoomInfo {
    final room = destinationRoomId;
    if (room == null) return null;
    return _indoorNavController.getRoomInfo(room);
  }

  CheckpointDefinition? get currentCheckpointDefinition {
    final id = currentCheckpointId;
    if (id == unknownCheckpoint) return null;
    return checkpointDefinitionFor(id);
  }

  CheckpointDefinition? checkpointDefinitionFor(String checkpointId) {
    if (!_indoorNavController.isLoaded) return null;
    return _indoorNavController.getCheckpointInstruction(checkpointId);
  }

  RoomInfo? roomInfoFor(String room) {
    if (!_indoorNavController.isLoaded) return null;
    return _indoorNavController.getRoomInfo(room);
  }

  Future<void> initialize({bool startScanning = true}) async {
    if (_isInitializing) return;
    if (_indoorNavController.isLoaded) {
      if (startScanning && !_isScanning) {
        await startLocalization();
      }
      return;
    }

    _isInitializing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _indoorNavController.loadAssets();
      if (startScanning) {
        await startLocalization();
      }
    } catch (error) {
      _lastError = 'Indoor navigation setup failed: $error';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> startLocalization() async {
    stopLocalization();

    final hasPermission = await _wifiSource.requestPermissions();
    if (!hasPermission) {
      _lastError =
          'Wi-Fi and location permissions are required for indoor navigation.';
      _isScanning = false;
      notifyListeners();
      return;
    }

    _lastError = null;
    _isScanning = true;
    notifyListeners();

    await scanOnce();
    _scanTimer = Timer.periodic(
      scanInterval,
      (_) => unawaited(scanOnce()),
    );
  }

  void stopLocalization() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (_isScanning) {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> scanOnce() async {
    if (!_indoorNavController.isLoaded || _scanInProgress) return;

    _scanInProgress = true;
    try {
      final observations = await _wifiSource.scan();
      final hadError = _lastError != null;
      _lastError = null;
      _indoorNavController.updateFromWifiScan(observations);
      if (hadError) notifyListeners();
    } catch (error) {
      _lastError = 'Wi-Fi scan failed: $error';
      notifyListeners();
    } finally {
      _scanInProgress = false;
    }
  }

  void setDestination(String? roomId) {
    try {
      _lastError = null;
      if (roomId == null || roomId.trim().isEmpty) {
        _indoorNavController.clearDestination();
      } else {
        _indoorNavController.selectDestinationRoom(roomId);
      }
    } catch (error) {
      _lastError = '$error';
      notifyListeners();
    }
  }

  void reset() {
    stopLocalization();
    _lastError = null;
    _indoorNavController.reset();
  }

  @override
  void dispose() {
    stopLocalization();
    _indoorNavController.removeListener(notifyListeners);
    if (_ownsController) {
      _indoorNavController.dispose();
    }
    super.dispose();
  }
}
