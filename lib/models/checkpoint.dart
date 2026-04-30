class Checkpoint {
  final String id;
  final String name;
  final String wing;
  final String description;
  final List<String> coveredRooms;
  final String instructionSummary;

  const Checkpoint({
    required this.id,
    required this.name,
    required this.wing,
    required this.description,
    required this.coveredRooms,
    required this.instructionSummary,
  });
}
