import 'models.dart';

const int missingRssi = -100;

const List<String> featureNames = [
  'Ap00Df24G',
  'Ap00Df5G',
  'Ap2436Da9D3C24G',
  'Ap2436Da9Df124G',
  'Ap2436DaA38924G',
  'Ap2436DaA3895G',
  'Ap40017A539724G',
  'Ap40017A53975G',
  'Ap6C310E56E124G',
  'Ap6C310E56E15G',
  'Ap7488Bb8Aaa24G',
  'ApF80BCbF38824G',
];

const List<ApFeatureRule> featureRules = [
  ApFeatureRule(name: 'Ap00Df24G', prefix: '00:df:1d:6a:9c:', band: '2.4'),
  ApFeatureRule(name: 'Ap00Df5G', prefix: '00:df:1d:6a:9c:', band: '5'),
  ApFeatureRule(name: 'Ap2436Da9D3C24G', prefix: '24:36:da:9d:3c:', band: '2.4'),
  ApFeatureRule(name: 'Ap2436Da9Df124G', prefix: '24:36:da:9d:f1:', band: '2.4'),
  ApFeatureRule(name: 'Ap2436DaA38924G', prefix: '24:36:da:a3:89:', band: '2.4'),
  ApFeatureRule(name: 'Ap2436DaA3895G', prefix: '24:36:da:a3:89:', band: '5'),
  ApFeatureRule(name: 'Ap40017A539724G', prefix: '40:01:7a:53:97:', band: '2.4'),
  ApFeatureRule(name: 'Ap40017A53975G', prefix: '40:01:7a:53:97:', band: '5'),
  ApFeatureRule(name: 'Ap6C310E56E124G', prefix: '6c:31:0e:56:e1:', band: '2.4'),
  ApFeatureRule(name: 'Ap6C310E56E15G', prefix: '6c:31:0e:56:e1:', band: '5'),
  ApFeatureRule(name: 'Ap7488Bb8Aaa24G', prefix: '74:88:bb:8a:aa:', band: '2.4'),
  ApFeatureRule(name: 'ApF80BCbF38824G', prefix: 'f8:0b:cb:f3:88:', band: '2.4'),
];

String? _bandForFrequency(int frequencyMHz) {
  if (frequencyMHz < 3000) return '2.4';
  if (frequencyMHz >= 5000) return '5';
  return null;
}

String? _matchingFeature(WifiObservation obs) {
  final bssid = obs.bssid.toLowerCase().trim();
  final band = _bandForFrequency(obs.frequencyMHz);
  for (final rule in featureRules) {
    if (bssid.startsWith(rule.prefix) && band == rule.band) return rule.name;
  }
  return null;
}

/// Converts raw scan results into the fixed 12-feature RSSI vector.
/// If multiple BSSIDs match a feature, max RSSI is used.
/// Missing features are filled with -100.
Map<String, int> extractFeatureVector(List<WifiObservation> observations) {
  final vector = {for (final name in featureNames) name: missingRssi};
  for (final obs in observations) {
    final feature = _matchingFeature(obs);
    if (feature == null) continue;
    final oldValue = vector[feature] ?? missingRssi;
    if (obs.rssi > oldValue) vector[feature] = obs.rssi;
  }
  return vector;
}

/// Counts features with RSSI > missingRssi (-100).
int matchedFeatureCount(Map<String, int> vector) {
  return vector.values.where((value) => value > missingRssi).length;
}
