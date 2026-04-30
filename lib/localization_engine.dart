import 'dart:math';
import 'models.dart';

class LocalizationEngine {
  final List<Fingerprint> _fingerprints = [];

  void loadFingerprints(List<Fingerprint> data) {
    _fingerprints.clear();
    _fingerprints.addAll(data);
  }

  String predictCheckpoint(List<double> liveVector) {
    if (_fingerprints.isEmpty) return "Unknown";

    Fingerprint? bestMatch;
    double minDistance = double.infinity;

    for (var fingerprint in _fingerprints) {
      double distance = _calculateEuclideanDistance(
        liveVector,
        fingerprint.rssiValues,
      );
      if (distance < minDistance) {
        minDistance = distance;
        bestMatch = fingerprint;
      }
    }

    return bestMatch?.checkpointId ?? "Unknown";
  }

  double _calculateEuclideanDistance(List<double> v1, List<double> v2) {
    double sum = 0;
    for (int i = 0; i < v1.length; i++) {
      double diff = v1[i] - v2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  // Smoothing logic: Majority vote over last N predictions
  String smoothPrediction(List<String> lastPredictions) {
    if (lastPredictions.isEmpty) return "Unknown";

    Map<String, int> counts = {};
    for (var pred in lastPredictions) {
      counts[pred] = (counts[pred] ?? 0) + 1;
    }

    var sortedEntries =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.first.key;
  }
}
