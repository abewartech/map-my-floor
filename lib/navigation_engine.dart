import 'models.dart';
import 'package:collection/collection.dart';

class NavigationEngine {
  final Map<String, List<Edge>> _graph = {};

  void buildGraph(List<Edge> edges) {
    _graph.clear();
    for (var edge in edges) {
      _graph.putIfAbsent(edge.from, () => []).add(edge);
      // Assuming undirected for navigation between checkpoints
      _graph
          .putIfAbsent(edge.to, () => [])
          .add(Edge(edge.to, edge.from, edge.weight));
    }
  }

  List<String> findPath(
    String startNode,
    String destinationRoomId,
    List<Room> rooms,
  ) {
    final room = rooms.firstWhereOrNull((r) => r.id == destinationRoomId);
    if (room == null) return [];

    String targetNode = room.checkpointId;

    // Dijkstra's algorithm
    Map<String, double> distances = {startNode: 0};
    Map<String, String?> previous = {};
    PriorityQueue<String> nodes = PriorityQueue(
      (a, b) => (distances[a] ?? double.infinity).compareTo(
        distances[b] ?? double.infinity,
      ),
    );

    nodes.add(startNode);

    while (nodes.isNotEmpty) {
      String current = nodes.removeFirst();

      if (current == targetNode) {
        List<String> path = [];
        String? step = current;
        while (step != null) {
          path.insert(0, step);
          step = previous[step];
        }
        // Add the exact room as the final destination
        path.add(destinationRoomId);
        return path;
      }

      if (distances[current] == null) break;

      for (var edge in _graph[current] ?? []) {
        double alt = distances[current]! + edge.weight;
        if (alt < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = alt;
          previous[edge.to] = current;
          nodes.add(edge.to);
        }
      }
    }

    return [];
  }
}
