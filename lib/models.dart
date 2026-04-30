class Checkpoint {
  final String id;
  final String name;
  final double x; // Map coordinates (0.0 to 1.0)
  final double y;

  Checkpoint({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
  });
}

class Room {
  final String id;
  final String name;
  final String checkpointId; // Nearest checkpoint
  final double x; // Exact room coordinates for mapping
  final double y;

  Room({
    required this.id,
    required this.name,
    required this.checkpointId,
    required this.x,
    required this.y,
  });
}

class Fingerprint {
  final String sessionId;
  final String checkpointId;
  final List<double> rssiValues;

  Fingerprint({
    required this.sessionId,
    required this.checkpointId,
    required this.rssiValues,
  });

  factory Fingerprint.fromCsv(String csvLine) {
    final parts = csvLine.split(',');
    return Fingerprint(
      sessionId: parts[0],
      checkpointId: parts[1],
      rssiValues:
          parts.sublist(2).map((e) => double.tryParse(e) ?? -100.0).toList(),
    );
  }
}

class Edge {
  final String from;
  final String to;
  final double weight;

  Edge(this.from, this.to, [this.weight = 1.0]);
}
