import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:map_my_floor/indoor_nav.dart';
import 'package:map_my_floor/navigation_provider.dart';
import 'package:map_my_floor/screens/location_screen.dart';
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

Future<NavigationProvider> _readyProvider() async {
  final provider = NavigationProvider(
    wifiSource: FakeWifiSource(
      observations: const <WifiObservation>[],
    ),
  );
  await provider.initialize(startScanning: false);
  return provider;
}

Widget _withProvider(NavigationProvider provider, Widget child) {
  return ChangeNotifierProvider<NavigationProvider>.value(
    value: provider,
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LocationScreen renders C1 fallback before first scan', (
    tester,
  ) async {
    final provider = await _readyProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_withProvider(provider, const LocationScreen()));
    await tester.pump();

    expect(find.text('C1'), findsOneWidget);
    expect(find.text('Lift Lobby'), findsOneWidget);
  });
}
