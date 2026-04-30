class RoomMapping {
  final String destinationRoom;
  final String checkpointId;
  final String localPosition;
  final String displayName;
  final String finalInstruction;

  const RoomMapping({
    required this.destinationRoom,
    required this.checkpointId,
    required this.localPosition,
    required this.displayName,
    required this.finalInstruction,
  });
}
