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

  /// Weighted kNN with outlier rejection via IQR / z-score gate.
  ///
  /// Algorithm:
  ///   1. Rank all fingerprints by RSSI distance, drop infinite distances.
  ///   2. Take the top [k] candidates.
  ///   3. Compute mean & std-dev of those [k] distances.
  ///   4. Flag any candidate as an outlier when its distance exceeds
  ///      mean + [outlierSigma] × std-dev (and std-dev is non-trivial).
  ///   5. Outliers contribute a tiny sentinel weight (1e-9) so they appear
  ///      in the debug overlay but do not meaningfully affect voting.
  ///   6. Confidence = winner-vote-share among non-outlier weights.
  PredictionResult predictWeightedKnn(
    Map<String, int> liveVector, {
    int k = 3,
    double outlierSigma = 1.5,
  }) {
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

    // Exact match short-circuit.
    if (ranked.first.value == 0) {
      return PredictionResult(
        checkpointId: ranked.first.key.checkpointId,
        distance: 0,
        confidence: 1.0,
        knnNeighbors: [
          KnnNeighbor(
            checkpointId: ranked.first.key.checkpointId,
            distance: 0,
            weight: 1.0,
            isOutlier: false,
          ),
        ],
      );
    }

    final topK = ranked.take(k).toList();

    // ── Outlier detection ─────────────────────────────────────────────────
    final distances = topK.map((e) => e.value).toList();
    final mean = distances.fold(0.0, (a, b) => a + b) / distances.length;
    final variance =
        distances.map((d) => (d - mean) * (d - mean)).fold(0.0, (a, b) => a + b) /
            distances.length;
    final std = sqrt(variance);
    final outlierThreshold =
        (std > 1e-6) ? mean + outlierSigma * std : double.infinity;

    // ── Vote accumulation ─────────────────────────────────────────────────
    final votes = <String, double>{};
    final neighbors = <KnnNeighbor>[];

    for (final item in topK) {
      final isOutlier = item.value > outlierThreshold;
      final effectiveWeight =
          isOutlier ? 1e-9 : 1.0 / max(item.value, 1e-6);

      if (!isOutlier) {
        votes[item.key.checkpointId] =
            (votes[item.key.checkpointId] ?? 0.0) + effectiveWeight;
      }

      neighbors.add(KnnNeighbor(
        checkpointId: item.key.checkpointId,
        distance: item.value,
        weight: effectiveWeight,
        isOutlier: isOutlier,
      ));
    }

    // Fallback: if everything got rejected as outlier, use raw nearest.
    if (votes.isEmpty) {
      for (final nb in neighbors) {
        final w = 1.0 / max(nb.distance, 1e-6);
        votes[nb.checkpointId] = (votes[nb.checkpointId] ?? 0.0) + w;
      }
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
      knnNeighbors: neighbors,
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
        // Do not reward two missing values as similarity.
        continue;
      }

      if (liveMissing || storedMissing) {
        // Penalize one-sided missing.
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
