class GraphEdge {
  final String from;
  final String to;
  final double distance;

  const GraphEdge({
    required this.from,
    required this.to,
    required this.distance,
  });
}

enum MapState { idle, routing, walking }
