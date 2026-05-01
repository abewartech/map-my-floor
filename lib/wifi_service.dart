import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'indoor_nav.dart';

abstract class WifiObservationSource {
  Future<bool> requestPermissions();
  Future<List<WifiObservation>> scan();
}

class WiFiService implements WifiObservationSource {
  const WiFiService();

  @override
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;

    final locationStatus = await Permission.locationWhenInUse.request();
    final wifiStatus = await Permission.nearbyWifiDevices.request();

    if (!locationStatus.isGranted) {
      return false;
    }

    if (!wifiStatus.isGranted) {
      return false;
    }

    final canRead = await WiFiScan.instance.canGetScannedResults(
      askPermissions: false,
    );

    return canRead == CanGetScannedResults.yes;
  }

  @override
  Future<List<WifiObservation>> scan() async {
    final canStart = await WiFiScan.instance.canStartScan(
      askPermissions: false,
    );

    if (canStart == CanStartScan.yes) {
      final started = await WiFiScan.instance.startScan();
      if (!started) {
        debugPrint(
          'Wi-Fi scan request was rejected; using available cached results.',
        );
      }
    } else {
      debugPrint(
        'Cannot start fresh Wi-Fi scan: $canStart; using available cached results.',
      );
    }

    final canRead = await WiFiScan.instance.canGetScannedResults(
      askPermissions: false,
    );
    if (canRead != CanGetScannedResults.yes) {
      // Still throwing if we can't even read cached results,
      // as that indicates a deeper permission/state issue.
      throw StateError('Wi-Fi scan results are not available: $canRead');
    }

    final results = await WiFiScan.instance.getScannedResults();
    return results
        .map(
          (accessPoint) => WifiObservation(
            bssid: accessPoint.bssid,
            ssid: accessPoint.ssid,
            rssi: accessPoint.level,
            frequencyMHz: accessPoint.frequency,
          ),
        )
        .toList(growable: false);
  }
}
