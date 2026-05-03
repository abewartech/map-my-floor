import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../indoor_nav.dart';
import '../map_state.dart';
import '../navigation_provider.dart';
import '../widgets/floor_map_painter.dart';
import '../widgets/route_painter.dart';
import '../widgets/walking_overlay.dart';
import 'location_screen.dart';

const double _floorPlanViewAspectRatio = 3.4;
const String _floorPlanAsset = 'assets/images/final_floorplan.png';

class MapScreen extends StatefulWidget {
  final String sourceCheckpointId;

  const MapScreen({super.key, required this.sourceCheckpointId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final AnimationController _nodeRingController;
  late final AnimationController _dashController;
  late final TextEditingController _searchController;
  Timer? _routeTimer;
  String? _selectedRoomId;
  String _query = '';
  MapState _mapState = MapState.idle;

  @override
  void initState() {
    super.initState();
    _nodeRingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _dashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _nodeRingController.dispose();
    _dashController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectDestination(String? roomId) {
    _routeTimer?.cancel();
    context.read<NavigationProvider>().setDestination(roomId);
    setState(() {
      _selectedRoomId = roomId;
      _mapState = roomId == null ? MapState.idle : MapState.routing;
    });

    if (roomId != null) {
      _routeTimer = Timer(const Duration(seconds: 25), () {
        if (!mounted || _selectedRoomId != roomId) return;
        setState(() => _mapState = MapState.walking);
      });
    }
  }

  void _dismissOverlay() {
    _routeTimer?.cancel();
    setState(() => _mapState = MapState.routing);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NavigationProvider>();
    final providerCheckpoint = provider.currentCheckpointId;
    final sourceCheckpointId = effectiveCheckpointId(
      providerCheckpoint,
      fallback: effectiveCheckpointId(widget.sourceCheckpointId),
    );
    final selectedRoom = provider.selectedRoomInfo;
    final selectedRoomId = provider.destinationRoomId ?? _selectedRoomId;
    final routePath = provider.currentPath;

    return Scaffold(
      appBar: AppBar(title: const Text('Floor Map - 4th Floor')),
      body: Stack(
        children: [
          Column(
            children: [
              _DestinationSelector(
                query: _query,
                controller: _searchController,
                selectedRoomId: selectedRoomId,
                availableRooms: provider.availableRooms,
                onQueryChanged: (value) => setState(() => _query = value),
                onSelected: _selectDestination,
                onClear: () => _selectDestination(null),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: _MapCanvas(
                    sourceCheckpointId: sourceCheckpointId,
                    destinationCheckpointId: provider.destinationCheckpoint,
                    routePath: routePath,
                    mapState: _mapState,
                    nodeRingController: _nodeRingController,
                    dashController: _dashController,
                  ),
                ),
              ),
              _NavigationStatusPanel(
                sourceCheckpointId: sourceCheckpointId,
                selectedRoom: selectedRoom,
                routePath: routePath,
                checkpoint: provider.checkpointDefinitionFor(
                  sourceCheckpointId,
                ),
                errorText: provider.lastError,
              ),
            ],
          ),
          WalkingOverlay(
            visible: _mapState == MapState.walking && selectedRoom != null,
            destinationName: selectedRoom?.displayName ?? '',
            finalInstruction: provider.finalRoomInstruction,
            onDismiss: _dismissOverlay,
          ),
        ],
      ),
    );
  }
}

class _DestinationSelector extends StatelessWidget {
  final String query;
  final TextEditingController controller;
  final String? selectedRoomId;
  final List<String> availableRooms;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onSelected;
  final VoidCallback onClear;

  const _DestinationSelector({
    required this.query,
    required this.controller,
    required this.selectedRoomId,
    required this.availableRooms,
    required this.onQueryChanged,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = normalizeRoomLabel(query);
    final rooms = availableRooms.toList()..sort();
    final visibleRooms =
        rooms
            .where(
              (room) =>
                  normalizedQuery.isEmpty || room.contains(normalizedQuery),
            )
            .toList();
    final aWingRooms =
        visibleRooms.where((room) => room.startsWith('A-')).toList();
    final bWingRooms =
        visibleRooms.where((room) => room.startsWith('B-')).toList();
    final hasSelectedVisible =
        selectedRoomId == null || visibleRooms.contains(selectedRoomId);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('destinationSearchField'),
              controller: controller,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Search or select room',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const ValueKey('destinationDropdown'),
                      isExpanded: true,
                      value: hasSelectedVisible ? selectedRoomId : null,
                      hint: const Text('Select destination'),
                      items: [
                        if (aWingRooms.isNotEmpty)
                          const DropdownMenuItem<String>(
                            value: '__A_WING__',
                            enabled: false,
                            child: Text('A-Wing'),
                          ),
                        ...aWingRooms.map(
                          (room) => DropdownMenuItem<String>(
                            value: room,
                            child: Text(room),
                          ),
                        ),
                        if (bWingRooms.isNotEmpty)
                          const DropdownMenuItem<String>(
                            value: '__B_WING__',
                            enabled: false,
                            child: Text('B-Wing'),
                          ),
                        ...bWingRooms.map(
                          (room) => DropdownMenuItem<String>(
                            value: room,
                            child: Text(room),
                          ),
                        ),
                      ],
                      onChanged: onSelected,
                    ),
                  ),
                ),
                if (selectedRoomId != null)
                  IconButton(
                    key: const ValueKey('clearDestinationButton'),
                    tooltip: 'Clear destination',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCanvas extends StatefulWidget {
  final String sourceCheckpointId;
  final String? destinationCheckpointId;
  final List<String> routePath;
  final MapState mapState;
  final AnimationController nodeRingController;
  final AnimationController dashController;

  const _MapCanvas({
    required this.sourceCheckpointId,
    required this.destinationCheckpointId,
    required this.routePath,
    required this.mapState,
    required this.nodeRingController,
    required this.dashController,
  });

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  final TransformationController _transformationController =
      TransformationController();
  Size? _lastViewportSize;
  Size? _lastCanvasSize;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final canvasHeight = math.max(520.0, constraints.maxHeight);
        final canvasWidth = canvasHeight * _floorPlanViewAspectRatio;
        final canvasSize = Size(canvasWidth, canvasHeight);
        _centerMapWhenSizeChanges(viewportSize, canvasSize);

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Colors.white,
            child: InteractiveViewer(
              minScale: 0.75,
              maxScale: 2.8,
              constrained: false,
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(80),
              child: SizedBox(
                width: canvasWidth,
                height: canvasHeight,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    widget.nodeRingController,
                    widget.dashController,
                  ]),
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          _floorPlanAsset,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                        if (widget.routePath.length > 1 &&
                            widget.mapState == MapState.routing)
                          CustomPaint(
                            painter: RoutePainter(
                              routePath: widget.routePath,
                              animationValue: widget.dashController.value,
                            ),
                          ),
                        CustomPaint(
                          painter: FloorMapPainter(
                            sourceCheckpointId: widget.sourceCheckpointId,
                            destinationCheckpointId:
                                widget.destinationCheckpointId,
                            routePath: widget.routePath,
                            mapState: widget.mapState,
                            pulseValue: widget.nodeRingController.value,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _centerMapWhenSizeChanges(Size viewportSize, Size canvasSize) {
    if (_lastViewportSize == viewportSize && _lastCanvasSize == canvasSize) {
      return;
    }
    _lastViewportSize = viewportSize;
    _lastCanvasSize = canvasSize;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dx = math.min(0.0, (viewportSize.width - canvasSize.width) / 2);
      final dy = math.min(0.0, (viewportSize.height - canvasSize.height) / 2);
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0.0, 1.0);
    });
  }
}

class _NavigationStatusPanel extends StatelessWidget {
  final String sourceCheckpointId;
  final RoomInfo? selectedRoom;
  final List<String> routePath;
  final CheckpointDefinition? checkpoint;
  final String? errorText;

  const _NavigationStatusPanel({
    required this.sourceCheckpointId,
    required this.selectedRoom,
    required this.routePath,
    required this.checkpoint,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final currentCheckpoint = checkpoint;
    final currentText =
        currentCheckpoint == null
            ? sourceCheckpointId
            : '$sourceCheckpointId - ${currentCheckpoint.name}';
    final nextStep = routePath.length > 1 ? routePath[1] : '-';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Navigation Status',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _StatusRow(label: 'Current', value: currentText),
            const SizedBox(height: 6),
            _StatusRow(
              label: 'Destination',
              value: selectedRoom?.displayName ?? 'Not selected',
            ),
            const SizedBox(height: 6),
            _StatusRow(label: 'Next step', value: nextStep),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
