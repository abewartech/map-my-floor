import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/checkpoint_definitions.dart';
import '../navigation_provider.dart';
import 'map_screen.dart';

const String kDemoFallbackCheckpointId = 'C1';

String effectiveCheckpointId(
  String checkpointId, {
  String fallback = kDemoFallbackCheckpointId,
}) {
  return checkpointId == 'Unknown' || checkpointId.trim().isEmpty
      ? fallback
      : checkpointId;
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  DateTime _lastUpdated = DateTime.now();
  String _lastCheckpointId = kDemoFallbackCheckpointId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerCheckpoint =
        context.watch<NavigationProvider>().currentCheckpointId;
    final checkpointId = effectiveCheckpointId(providerCheckpoint);
    final checkpoint =
        kCheckpointsById[checkpointId] ??
        kCheckpointsById[kDemoFallbackCheckpointId]!;

    if (checkpointId != _lastCheckpointId) {
      _lastCheckpointId = checkpointId;
      _lastUpdated = DateTime.now();
    }

    final timeLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(_lastUpdated));

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4th Floor Navigation'),
            Text(
              'IIIT Delhi',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.my_location,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'YOU ARE HERE',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: 0.4 + (_pulseController.value * 0.6),
                                  child: child,
                                );
                              },
                              child: Container(
                                key: const ValueKey('checkpointChip'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  checkpoint.id,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            checkpoint.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            checkpoint.instructionSummary,
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: Colors.blueGrey.shade700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _InfoRow(label: 'Wing', value: checkpoint.wing),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: 'Nearby Rooms',
                            value:
                                checkpoint.coveredRooms.isEmpty
                                    ? '-'
                                    : checkpoint.coveredRooms.join(', '),
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: 'Description',
                            value: checkpoint.description,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 10),
                          Text('Last updated: $timeLabel'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    key: const ValueKey('navigateToRoomButton'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) =>
                                  MapScreen(sourceCheckpointId: checkpoint.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.route),
                    label: const Text('Navigate to a Room'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.blueGrey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
