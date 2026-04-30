import '../data/graph_data.dart';
import '../models/graph.dart';

List<String> findPath(String start, String end) {
  final adjacency = _buildAdjacency(kEdges);
  if (!adjacency.containsKey(start) || !adjacency.containsKey(end)) {
    return const [];
  }
  if (start == end) return [start];

  final distances = <String, double>{};
  final previous = <String, String?>{};
  final unvisited = adjacency.keys.toSet();

  for (final node in unvisited) {
    distances[node] = double.infinity;
    previous[node] = null;
  }
  distances[start] = 0.0;

  while (unvisited.isNotEmpty) {
    final current = _nearestUnvisited(unvisited, distances);

    if (current == end) break;
    if ((distances[current] ?? double.infinity) == double.infinity) break;

    unvisited.remove(current);
    for (final edge in adjacency[current] ?? const <GraphEdge>[]) {
      if (!unvisited.contains(edge.to)) continue;
      final alternative =
          (distances[current] ?? double.infinity) + edge.distance;
      if (alternative < (distances[edge.to] ?? double.infinity)) {
        distances[edge.to] = alternative;
        previous[edge.to] = current;
      }
    }
  }

  if (previous[end] == null) return const [];

  final path = <String>[];
  String? cursor = end;
  while (cursor != null) {
    path.add(cursor);
    cursor = previous[cursor];
  }
  return path.reversed.toList();
}

Map<String, List<GraphEdge>> _buildAdjacency(List<GraphEdge> edges) {
  final adjacency = <String, List<GraphEdge>>{};
  for (final edge in edges) {
    adjacency.putIfAbsent(edge.from, () => []).add(edge);
    adjacency
        .putIfAbsent(edge.to, () => [])
        .add(GraphEdge(from: edge.to, to: edge.from, distance: edge.distance));
  }
  return adjacency;
}

String _nearestUnvisited(Set<String> unvisited, Map<String, double> distances) {
  return unvisited.reduce((a, b) {
    final distanceA = distances[a] ?? double.infinity;
    final distanceB = distances[b] ?? double.infinity;
    if (distanceA != distanceB) return distanceA < distanceB ? a : b;
    return a.compareTo(b) <= 0 ? a : b;
  });
}
