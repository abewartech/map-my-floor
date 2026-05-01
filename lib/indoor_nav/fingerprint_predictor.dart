import 'dart:math';
import 'models.dart';
import 'feature_extractor.dart';

class FingerprintPredictor {
  final List<Fingerprint> fingerprints;

  const FingerprintPredictor(this.fingerprints);

  PredictionResult predictNearest(Map<String, int> liveVector) {
    if (fingerprints.isEmpty) {
      throw StateError('No fingerprints loaded.');
    }

    final ranked = fingerprints
        .map((fp) => PredictionResult(
              checkpointId: fp.checkpointId,
              distance: _wifiDistance(liveVector, fp.features),
              confidence: 0.0,
            ))
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));

    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1] : best;
    final margin = second.distance - best.distance;
    final confidence = second.distance <= 0 || second.distance.isInfinite
        ? (best.distance <= 0 ? 1.0 : 0.0)
        : (margin / second.distance).clamp(0.0, 1.0);

    return PredictionResult(
      checkpointId: best.checkpointId,
      distance: best.distance,
      confidence: confidence,
    );
  }

  PredictionResult predictWeightedKnn(Map<String, int> liveVector, {int k = 3}) {
    if (fingerprints.isEmpty) {
      throw StateError('No fingerprints loaded.');
    }

    final ranked = fingerprints
        .map((fp) => MapEntry(fp, _wifiDistance(liveVector, fp.features)))
        .where((entry) => !entry.value.isInfinite)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (ranked.isEmpty) {
      return const PredictionResult(
        checkpointId: 'Unknown',
        distance: double.infinity,
        confidence: 0.0,
      );
    }

    // Check for exact match (distance 0)
    if (ranked.first.value == 0) {
      return PredictionResult(
        checkpointId: ranked.first.key.checkpointId,
        distance: 0,
        confidence: 1.0,
      );
    }

    final votes = <String, double>{};
    for (final item in ranked.take(k)) {
      final weight = 1.0 / max(item.value, 1e-6);
      votes[item.key.checkpointId] =
          (votes[item.key.checkpointId] ?? 0.0) + weight;
    }

    final sortedVotes =
        votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final bestLabel = sortedVotes.first.key;
    final bestDistance = ranked.first.value;
    final total = sortedVotes.fold<double>(0.0, (acc, e) => acc + e.value);
    final confidence =
        total <= 0 ? 0.0 : (sortedVotes.first.value / total).clamp(0.0, 1.0);

    return PredictionResult(
      checkpointId: bestLabel,
      distance: bestDistance,
      confidence: confidence,
    );
  }

  double _wifiDistance(Map<String, int> live, Map<String, int> stored) {
    const double missingPenalty = 15.0;
    const int minOverlapFeatures = 1;

    var sum = 0.0;
    var overlap = 0;

    for (final feature in featureNames) {
      final liveValue = live[feature] ?? missingRssi;
      final storedValue = stored[feature] ?? missingRssi;

      final liveMissing = liveValue <= missingRssi;
      final storedMissing = storedValue <= missingRssi;

      if (liveMissing && storedMissing) {
        // Very important:
        // Do not reward two missing values as a similarity.
        continue;
      }

      if (liveMissing || storedMissing) {
        // Penalize one-sided missing values.
        sum += missingPenalty * missingPenalty;
        continue;
      }

      overlap++;
      final diff = (liveValue - storedValue).toDouble();
      sum += diff * diff;
    }

    if (overlap < minOverlapFeatures) {
      return double.infinity;
    }

    return sqrt(sum);
  }
}
