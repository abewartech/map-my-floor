import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../indoor_nav.dart';
import '../navigation_provider.dart';

// ─── Public entry-point ─────────────────────────────────────────────────────

/// A toggleable floating debug panel.
///
/// Wrap your screen body in a [Stack] and place this widget on top.
/// It renders a semi-transparent FAB-like button; tapping expands the full
/// panel.  The panel floats over content so the map / location UI remains
/// fully usable while debugging.
class DebugOverlay extends StatefulWidget {
  const DebugOverlay({super.key});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _fadeCtrl.forward() : _fadeCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Expanded panel ──────────────────────────────────────────────
          if (_expanded)
            FadeTransition(
              opacity: _fadeAnim,
              child: _DebugPanel(onClose: _toggle),
            ),
          const SizedBox(height: 8),
          // ── Toggle FAB ──────────────────────────────────────────────────
          FloatingActionButton.small(
            heroTag: 'debugOverlayFab',
            tooltip: _expanded ? 'Hide debug panel' : 'Show debug panel',
            backgroundColor: _expanded
                ? const Color(0xFF1A237E)
                : const Color(0xFF37474F),
            onPressed: _toggle,
            child: Icon(
              _expanded ? Icons.bug_report : Icons.bug_report_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main panel ─────────────────────────────────────────────────────────────

class _DebugPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _DebugPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NavigationProvider>();

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xF0101820), // near-black, slightly transparent
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 520),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelHeader(onClose: onClose),
                const SizedBox(height: 10),
                _SmootherSection(
                  stable: p.currentCheckpointId,
                  rawCheckpoint: p.rawPredictedCheckpoint,
                  candidate: p.smootherCandidate,
                  candidateCount: p.smootherCandidateCount,
                  requiredConsecutive: p.requiredConsecutive,
                  confidence: p.predictionConfidence,
                ),
                const _Divider(),
                _RssiSection(featureVector: p.currentFeatureVector),
                if (p.knnNeighbors.isNotEmpty) ...[
                  const _Divider(),
                  _KnnSection(neighbors: p.knnNeighbors),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Panel header ────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bug_report, color: Color(0xFF80CBC4), size: 18),
        const SizedBox(width: 6),
        const Text(
          'DEBUG OVERLAY',
          style: TextStyle(
            color: Color(0xFF80CBC4),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onClose,
          child: const Icon(Icons.close, color: Color(0xFF78909C), size: 18),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(
        color: Color(0xFF263238),
        height: 16,
        thickness: 1,
      );
}

// ─── Smoother / Hysteresis section ───────────────────────────────────────────

class _SmootherSection extends StatelessWidget {
  final String stable;
  final String rawCheckpoint;
  final String? candidate;
  final int candidateCount;
  final int requiredConsecutive;
  final double confidence;

  const _SmootherSection({
    required this.stable,
    required this.rawCheckpoint,
    required this.candidate,
    required this.candidateCount,
    required this.requiredConsecutive,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final hasCandidate =
        candidate != null && candidate!.isNotEmpty && candidate != 'UNKNOWN';
    final progress = hasCandidate
        ? (candidateCount / requiredConsecutive).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('HYSTERESIS  (need $requiredConsecutive)'),
        const SizedBox(height: 6),
        _DebugRow('Stable', stable, _colorForCheckpoint(stable)),
        const SizedBox(height: 3),
        _DebugRow('Raw', rawCheckpoint, const Color(0xFFB0BEC5)),
        if (hasCandidate) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const SizedBox(width: 80),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.trending_flat,
                        size: 13, color: Color(0xFFFFB74D)),
                    const SizedBox(width: 4),
                    Text(
                      '$candidate  ($candidateCount / $requiredConsecutive)',
                      style: const TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFF263238),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFFB74D)),
            ),
          ),
        ],
        const SizedBox(height: 6),
        _ConfidenceBar(confidence: confidence),
      ],
    );
  }

  Color _colorForCheckpoint(String id) {
    if (id == 'Unknown' || id.isEmpty) return const Color(0xFF546E7A);
    if (id.startsWith('A')) return const Color(0xFF4FC3F7);
    if (id.startsWith('B')) return const Color(0xFF81C784);
    if (id.startsWith('C')) return const Color(0xFFCE93D8);
    return const Color(0xFFB0BEC5);
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  const _ConfidenceBar({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final barColor = confidence >= 0.7
        ? const Color(0xFF66BB6A)
        : confidence >= 0.45
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Confidence',
                style: TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$pct%',
                style: TextStyle(
                    color: barColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFF263238),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ─── RSSI section ────────────────────────────────────────────────────────────

class _RssiSection extends StatelessWidget {
  final Map<String, int> featureVector;
  const _RssiSection({required this.featureVector});

  // Short human-readable label from the AP feature name.
  static String _shortLabel(String name) {
    // e.g. 'Ap2436Da9D3C24G' → '9D3C·2.4'
    final band = name.endsWith('5G') ? '5G' : '2.4';
    // Extract the last 4 chars of the hex portion before the band suffix
    final stripped = name
        .replaceAll('Ap', '')
        .replaceAll('24G', '')
        .replaceAll('5G', '');
    final short = stripped.length > 4
        ? stripped.substring(stripped.length - 4)
        : stripped;
    return '$short·$band';
  }

  @override
  Widget build(BuildContext context) {
    final entries = featureNames
        .map((name) => MapEntry(name, featureVector[name] ?? missingRssi))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('LIVE RSSI  (12 APs)'),
        const SizedBox(height: 6),
        ...entries.map((e) => _RssiRow(label: _shortLabel(e.key), rssi: e.value)),
      ],
    );
  }
}

class _RssiRow extends StatelessWidget {
  final String label;
  final int rssi;
  const _RssiRow({required this.label, required this.rssi});

  static const int _minRssi = -100;
  static const int _maxRssi = -30;

  Color get _barColor {
    if (rssi <= missingRssi) return const Color(0xFF37474F);
    if (rssi >= -55) return const Color(0xFF66BB6A);
    if (rssi >= -70) return const Color(0xFFFFA726);
    return const Color(0xFFEF5350);
  }

  double get _fraction {
    if (rssi <= _minRssi) return 0.0;
    return ((rssi - _minRssi) / (_maxRssi - _minRssi)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final missing = rssi <= missingRssi;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                color: missing
                    ? const Color(0xFF37474F)
                    : const Color(0xFF90A4AE),
                fontSize: 9.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _fraction,
                minHeight: 7,
                backgroundColor: const Color(0xFF1C2B35),
                valueColor: AlwaysStoppedAnimation<Color>(_barColor),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              missing ? 'MISS' : '$rssi',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: missing
                    ? const Color(0xFF546E7A)
                    : const Color(0xFF90A4AE),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── kNN section ─────────────────────────────────────────────────────────────

class _KnnSection extends StatelessWidget {
  final List<KnnNeighbor> neighbors;
  const _KnnSection({required this.neighbors});

  @override
  Widget build(BuildContext context) {
    final maxDist = neighbors
        .map((n) => n.distance)
        .fold<double>(1.0, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('kNN NEIGHBOURS  (k=${neighbors.length})'),
        const SizedBox(height: 6),
        // Header
        const Row(
          children: [
            SizedBox(
                width: 22,
                child: Text('#',
                    style: TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 9,
                        fontWeight: FontWeight.w700))),
            SizedBox(
                width: 38,
                child: Text('CP',
                    style: TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 9,
                        fontWeight: FontWeight.w700))),
            Expanded(
                child: Text('distance',
                    style: TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 9,
                        fontWeight: FontWeight.w700))),
            SizedBox(
                width: 32,
                child: Text('wt',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Color(0xFF546E7A),
                        fontSize: 9,
                        fontWeight: FontWeight.w700))),
          ],
        ),
        const SizedBox(height: 3),
        ...neighbors.asMap().entries.map(
              (entry) => _KnnRow(
                rank: entry.key + 1,
                neighbor: entry.value,
                maxDist: maxDist,
              ),
            ),
      ],
    );
  }
}

class _KnnRow extends StatelessWidget {
  final int rank;
  final KnnNeighbor neighbor;
  final double maxDist;

  const _KnnRow({
    required this.rank,
    required this.neighbor,
    required this.maxDist,
  });

  @override
  Widget build(BuildContext context) {
    final isOutlier = neighbor.isOutlier;
    final barFraction = maxDist > 0
        ? (neighbor.distance / maxDist).clamp(0.0, 1.0)
        : 0.0;
    final barColor =
        isOutlier ? const Color(0xFF4E342E) : const Color(0xFF1565C0);
    final textColor = isOutlier
        ? const Color(0xFFBF360C)
        : const Color(0xFF90A4AE);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          // rank
          SizedBox(
            width: 22,
            child: Text(
              '#$rank',
              style: TextStyle(
                  color: textColor,
                  fontSize: 9,
                  fontFamily: 'monospace'),
            ),
          ),
          // checkpoint id
          SizedBox(
            width: 38,
            child: Text(
              neighbor.checkpointId,
              style: TextStyle(
                color: isOutlier
                    ? const Color(0xFFFF7043)
                    : const Color(0xFF80DEEA),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // distance bar
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: barFraction,
                    minHeight: 14,
                    backgroundColor: const Color(0xFF1C2B35),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    neighbor.distance.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // weight / outlier badge
          SizedBox(
            width: 32,
            child: isOutlier
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF360C),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'OUT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800),
                    ),
                  )
                : Text(
                    neighbor.weight > 1e-3
                        ? neighbor.weight.toStringAsFixed(3)
                        : neighbor.weight.toStringAsExponential(1),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Color(0xFF78909C),
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF546E7A),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _DebugRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    final display = value.isEmpty || value == 'Unknown' ? '–' : value;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                color: Color(0xFF546E7A),
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          display,
          style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
