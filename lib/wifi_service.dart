import 'dart:async';
import 'package:wifi_scan/wifi_scan.dart';
import 'constants.dart';

class WiFiService {
  // Map feature name to (BSSID Prefix, is5GHz)
  // This is a heuristic based on the feature names provided in the brief.
  final Map<String, (String, bool)> _featureMapping = {
    'Ap00Df24G': ('00:DF', false),
    'Ap00Df5G': ('00:DF', true),
    'Ap2436Da9D3C24G': ('24:36:DA:9D:3C', false),
    'Ap2436Da9Df124G': ('24:36:DA:9D:F1', false),
    'Ap2436DaA38924G': ('24:36:DA:A3:89', false),
    'Ap2436DaA3895G': ('24:36:DA:A3:89', true),
    'Ap40017A539724G': ('40:01:7A:53:97', false),
    'Ap40017A53975G': ('40:01:7A:53:97', true),
    'Ap6C310E56E124G': ('6C:31:0E:56:E1', false),
    'Ap6C310E56E15G': ('6C:31:0E:56:E1', true),
    'Ap7488Bb8Aaa24G': ('74:88:BB:8A:AA', false),
    'ApF80BCbF38824G': ('F8:0B:CB:F3:88', false),
  };

  Future<bool> requestPermissions() async {
    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan != CanStartScan.yes) {
      // In a real app, handle permissions specifically via permission_handler
      return false;
    }
    return true;
  }

  Future<List<double>> getFeatureVector() async {
    final results = await WiFiScan.instance.getScannedResults();
    List<double> vector = List.filled(
      AppConstants.frozenApFeatures.length,
      AppConstants.missingRssi,
    );

    // Grouping by feature and taking max RSSI
    Map<int, double> featureMaxRssi = {};

    for (var result in results) {
      int? index = _mapResultToFeatureIndex(result);
      if (index != null) {
        double currentRssi = result.level.toDouble();
        if (!featureMaxRssi.containsKey(index) ||
            currentRssi > featureMaxRssi[index]!) {
          featureMaxRssi[index] = currentRssi;
        }
      }
    }

    featureMaxRssi.forEach((index, rssi) {
      vector[index] = rssi;
    });

    return vector;
  }

  int? _mapResultToFeatureIndex(WiFiAccessPoint result) {
    String bssid = result.bssid.toUpperCase();
    bool is5G = result.frequency > 4000; // Simplified band check

    for (int i = 0; i < AppConstants.frozenApFeatures.length; i++) {
      String featureName = AppConstants.frozenApFeatures[i];
      var mapping = _featureMapping[featureName];
      if (mapping != null) {
        String prefix = mapping.$1;
        bool targetIs5G = mapping.$2;

        if (bssid.startsWith(prefix) && is5G == targetIs5G) {
          return i;
        }
      }
    }
    return null;
  }
}
