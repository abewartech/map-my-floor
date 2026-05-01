import 'package:flutter_test/flutter_test.dart';
import 'package:map_my_floor/indoor_nav.dart';
import 'package:map_my_floor/navigation_provider.dart';
import 'package:map_my_floor/wifi_service.dart';

class FakeWifiSource implements WifiObservationSource {
  List<WifiObservation> observations;
  bool permissionResult;
  Object? scanError;

  FakeWifiSource({
    required this.observations,
    this.permissionResult = true,
    this.scanError,
  });

  @override
  Future<bool> requestPermissions() async => permissionResult;

  @override
  Future<List<WifiObservation>> scan() async {
    final error = scanError;
    if (error != null) throw error;
    return observations;
  }
}

List<WifiObservation> _c1Observations() {
  return const [
    WifiObservation(
      bssid: '00:df:1d:6a:9c:20',
      ssid: 'eduroam',
      rssi: -78,
      frequencyMHz: 2412,
    ),
    WifiObservation(
      bssid: '00:df:1d:6a:9c:2d',
      ssid: 'eduroam',
      rssi: -92,
      frequencyMHz: 5805,
    ),
    WifiObservation(
      bssid: '24:36:da:9d:3c:20',
      ssid: 'eduroam',
      rssi: -87,
      frequencyMHz: 2412,
    ),
    WifiObservation(
      bssid: '40:01:7a:53:97:20',
      ssid: 'eduroam',
      rssi: -95,
      frequencyMHz: 2412,
    ),
    WifiObservation(
      bssid: '6c:31:0e:56:e1:20',
      ssid: 'eduroam',
      rssi: -80,
      frequencyMHz: 2412,
    ),
    WifiObservation(
      bssid: '74:88:bb:8a:aa:20',
      ssid: 'eduroam',
      rssi: -96,
      frequencyMHz: 2412,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to fast live updates with sub-two-second smoothing', () {
    final provider = NavigationProvider(
      wifiSource: FakeWifiSource(observations: const <WifiObservation>[]),
    );
    addTearDown(provider.dispose);

    expect(provider.scanInterval, const Duration(seconds: 1));
    expect(provider.backend.requiredConsecutive, 3);
  });

  test('scan updates backend checkpoint, feature vector, and confidence', () async {
    final provider = NavigationProvider(
      wifiSource: FakeWifiSource(observations: _c1Observations()),
    );
    addTearDown(provider.dispose);

    await provider.initialize(startScanning: false);
    await provider.scanOnce();

    expect(provider.currentCheckpointId, 'C1');
    expect(provider.rawPredictedCheckpoint, 'C1');
    expect(provider.currentFeatureVector['Ap00Df24G'], -78);
    expect(provider.predictionConfidence, greaterThan(0));
  });

  test('destination selection normalizes room and computes backend route', () async {
    final provider = NavigationProvider(
      wifiSource: FakeWifiSource(observations: _c1Observations()),
    );
    addTearDown(provider.dispose);

    await provider.initialize(startScanning: false);
    await provider.scanOnce();

    provider.setDestination('b414');

    expect(provider.destinationRoomId, 'B-414');
    expect(provider.destinationCheckpoint, 'B6');
    expect(provider.currentPath, ['C1', 'C0', 'B1', 'B2', 'B3', 'B6']);
    expect(
      provider.finalRoomInstruction,
      contains('Your destination B-414 is in the middle.'),
    );
  });

  test('backend room list includes extended A and B wing destinations', () async {
    final provider = NavigationProvider(
      wifiSource: FakeWifiSource(observations: const <WifiObservation>[]),
    );
    addTearDown(provider.dispose);

    await provider.initialize(startScanning: false);

    expect(
      provider.availableRooms,
      containsAll(['A-420', 'B-419', 'A-417', 'B-414']),
    );
  });

  test('permission failure sets lastError without starting scans', () async {
    final provider = NavigationProvider(
      wifiSource: FakeWifiSource(
        observations: _c1Observations(),
        permissionResult: false,
      ),
    );
    addTearDown(provider.dispose);

    await provider.initialize();

    expect(provider.isReady, isTrue);
    expect(provider.isScanning, isFalse);
    expect(provider.lastError, contains('permissions are required'));
    expect(provider.currentCheckpointId, NavigationProvider.unknownCheckpoint);
  });

  test('scan failure keeps previous state and reports lastError', () async {
    final source = FakeWifiSource(observations: _c1Observations());
    final provider = NavigationProvider(wifiSource: source);
    addTearDown(provider.dispose);

    await provider.initialize(startScanning: false);
    await provider.scanOnce();
    expect(provider.currentCheckpointId, 'C1');

    source.scanError = StateError('temporary scanner failure');
    await provider.scanOnce();

    expect(provider.currentCheckpointId, 'C1');
    expect(provider.lastError, contains('temporary scanner failure'));
  });
}
