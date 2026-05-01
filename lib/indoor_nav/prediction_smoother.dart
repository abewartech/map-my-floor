class PredictionSmoother {
  final int requiredConsecutive;
  final double minConfidence;

  String _stable = '';
  String? _candidate;
  int _candidateCount = 0;

  PredictionSmoother({
    this.requiredConsecutive = 3,
    this.minConfidence = 0.45,
    // Ignored but kept for constructor compatibility if needed
    int? windowSize,
  });

  String update({
    required String checkpointId,
    required double confidence,
    int? requiredHitsOverride,
  }) {
    final normalizedCheckpoint = checkpointId.trim().toUpperCase();

    if (normalizedCheckpoint.isEmpty || normalizedCheckpoint == 'UNKNOWN') {
      return _stable;
    }

    if (confidence < minConfidence) {
      return _stable;
    }

    if (_stable.isEmpty) {
      _stable = normalizedCheckpoint;
      _candidate = null;
      _candidateCount = 0;
      return _stable;
    }

    final neededHits = requiredHitsOverride ?? requiredConsecutive;

    if (normalizedCheckpoint == _stable) {
      // Do not immediately erase candidate progress.
      // A single stable/current prediction may just be noise while the user is transitioning.
      if (_candidate != null && _candidateCount > 0) {
        _candidateCount -= 1;
        if (_candidateCount <= 0) {
          _candidate = null;
          _candidateCount = 0;
        }
      }
      return _stable;
    }

    if (_candidate == normalizedCheckpoint) {
      _candidateCount += 1;
    } else {
      // A different new checkpoint appeared.
      // If previous candidate had weak evidence, replace it.
      // If previous candidate had some evidence, decay first.
      if (_candidate == null || _candidateCount <= 1) {
        _candidate = normalizedCheckpoint;
        _candidateCount = 1;
      } else {
        _candidateCount -= 1;
      }
    }

    if (_candidate == normalizedCheckpoint && _candidateCount >= neededHits) {
      _stable = normalizedCheckpoint;
      _candidate = null;
      _candidateCount = 0;
    }

    return _stable;
  }

  String get current => _stable;

  // Add debug getters. These are useful for localization logs and tests.
  String? get candidateDebugLabel => _candidate;
  int get candidateDebugCount => _candidateCount;

  void reset() {
    _stable = '';
    _candidate = null;
    _candidateCount = 0;
  }
}
