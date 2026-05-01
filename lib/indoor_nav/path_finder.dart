import 'models.dart';

class GraphPathFinder {
  final Map<String, List<GraphEdge>> adjacency = {};

  GraphPathFinder(List<GraphEdge> edges) {
    for (final edge in edges) {
      adjacency.putIfAbsent(edge.from, () => []).add(edge);
      adjacency
          .putIfAbsent(edge.to, () => [])
          .add(GraphEdge(from: edge.to, to: edge.from, distance: edge.distance));
    }
    for (final edges in adjacency.values) {
      edges.sort((a, b) => a.to.compareTo(b.to));
    }
  }

  List<String> get nodes => adjacency.keys.toList(growable: false)..sort();

  bool containsNode(String nodeId) => adjacency.containsKey(nodeId);

  bool areNeighbors(String a, String b) {
    if (a == b) return true;
    final edges = adjacency[a];
    if (edges == null) return false;
    return edges.any((edge) => edge.to == b);
  }

  List<String> shortestPath(String start, String target) {
    if (!containsNode(start) || !containsNode(target)) return const [];
    if (start == target) return [start];

    final distances = <String, double>{};
    final previous = <String, String?>{};
    final unvisited = <String>{...adjacency.keys};

    for (final node in unvisited) {
      distances[node] = double.infinity;
      previous[node] = null;
    }
    distances[start] = 0.0;

    while (unvisited.isNotEmpty) {
      final orderedUnvisited = unvisited.toList()
        ..sort((a, b) {
          final distanceCompare = (distances[a] ?? double.infinity).compareTo(
            distances[b] ?? double.infinity,
          );
          if (distanceCompare != 0) return distanceCompare;
          return a.compareTo(b);
        });
      final current = orderedUnvisited.first;
      if (current == target) break;
      if ((distances[current] ?? double.infinity) == double.infinity) break;
      unvisited.remove(current);

      for (final edge in adjacency[current] ?? const []) {
        if (!unvisited.contains(edge.to)) continue;
        final alt = (distances[current] ?? double.infinity) + edge.distance;
        if (alt < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = alt;
          previous[edge.to] = current;
        }
      }
    }

    if (previous[target] == null && start != target) return [];

    final path = <String>[];
    String? cursor = target;
    while (cursor != null) {
      path.add(cursor);
      cursor = previous[cursor];
    }
    return path.reversed.toList();
  }
}
