import '../models/checkpoint.dart';

const List<Checkpoint> kCheckpoints = [
  Checkpoint(
    id: 'C0',
    name: 'CentralCore_B419_A420_A419',
    wing: 'Core',
    description: 'Central core checkpoint near A-419, A-420, and B-419.',
    coveredRooms: ['A-419', 'A-420', 'B-419'],
    instructionSummary:
        'A-419 is on the left, A-420 is in the middle, and B-419 is on the right.',
  ),
  Checkpoint(
    id: 'C1',
    name: 'LiftLobby',
    wing: 'Core',
    description: 'Lift lobby checkpoint connected to the central core.',
    coveredRooms: [],
    instructionSummary: 'Proceed toward C0 for room navigation.',
  ),
  Checkpoint(
    id: 'A1',
    name: 'A401_A403',
    wing: 'A',
    description: 'A-wing faculty-room checkpoint for A-401 to A-403.',
    coveredRooms: ['A-401', 'A-402', 'A-403'],
    instructionSummary:
        'A-403 is on the left, A-402 is in the middle, and A-401 is on the right.',
  ),
  Checkpoint(
    id: 'A2',
    name: 'A404_A406',
    wing: 'A',
    description: 'A-wing faculty-room checkpoint for A-404 to A-406.',
    coveredRooms: ['A-404', 'A-405', 'A-406'],
    instructionSummary:
        'A-406 is on the left, A-405 is in the middle, and A-404 is on the right.',
  ),
  Checkpoint(
    id: 'A3',
    name: 'A407_A409',
    wing: 'A',
    description: 'A-wing faculty-room checkpoint for A-407 to A-409.',
    coveredRooms: ['A-407', 'A-408', 'A-409'],
    instructionSummary:
        'A-409 is on the left, A-408 is in the middle, and A-407 is on the right.',
  ),
  Checkpoint(
    id: 'A4',
    name: 'A410_A412',
    wing: 'A',
    description: 'A-wing faculty-room checkpoint for A-410 to A-412.',
    coveredRooms: ['A-410', 'A-411', 'A-412'],
    instructionSummary:
        'A-412 is on the left, A-411 is in the middle, and A-410 is on the right.',
  ),
  Checkpoint(
    id: 'A5',
    name: 'AEnd_Services',
    wing: 'A',
    description: 'A-wing end, staircase and services.',
    coveredRooms: [],
    instructionSummary: 'Service-side endpoint checkpoint for the A-wing.',
  ),
  Checkpoint(
    id: 'A6',
    name: 'A413_A415',
    wing: 'A',
    description: 'A-wing lab-side checkpoint for A-413 to A-415.',
    coveredRooms: ['A-413', 'A-414', 'A-415'],
    instructionSummary:
        'A-413 is on the left, A-414 is in the middle, and A-415 is on the right.',
  ),
  Checkpoint(
    id: 'A7',
    name: 'A416_A418',
    wing: 'A',
    description: 'A-wing lab-side checkpoint for A-416 to A-418.',
    coveredRooms: ['A-416', 'A-417', 'A-418'],
    instructionSummary:
        'A-416 is on the left, A-417 is in the middle, and A-418 is on the right.',
  ),
  Checkpoint(
    id: 'B1',
    name: 'B401_B403',
    wing: 'B',
    description: 'B-wing faculty-room checkpoint for B-401 to B-403.',
    coveredRooms: ['B-401', 'B-402', 'B-403'],
    instructionSummary:
        'B-403 is on the left, B-402 is in the middle, and B-401 is on the right.',
  ),
  Checkpoint(
    id: 'B2',
    name: 'B404_B406',
    wing: 'B',
    description: 'B-wing faculty-room checkpoint for B-404 to B-406.',
    coveredRooms: ['B-404', 'B-405', 'B-406'],
    instructionSummary:
        'B-406 is on the left, B-405 is in the middle, and B-404 is on the right.',
  ),
  Checkpoint(
    id: 'B3',
    name: 'B407_B409',
    wing: 'B',
    description: 'B-wing faculty-room checkpoint for B-407 to B-409.',
    coveredRooms: ['B-407', 'B-408', 'B-409'],
    instructionSummary:
        'B-409 is on the left, B-408 is in the middle, and B-407 is on the right.',
  ),
  Checkpoint(
    id: 'B4',
    name: 'B410_B412',
    wing: 'B',
    description: 'B-wing faculty-room checkpoint for B-410 to B-412.',
    coveredRooms: ['B-410', 'B-411', 'B-412'],
    instructionSummary:
        'B-412 is on the left, B-411 is in the middle, and B-410 is on the right.',
  ),
  Checkpoint(
    id: 'B5',
    name: 'BEnd_Services',
    wing: 'B',
    description: 'B-wing end, staircase and services.',
    coveredRooms: [],
    instructionSummary: 'Service-side endpoint checkpoint for the B-wing.',
  ),
  Checkpoint(
    id: 'B6',
    name: 'B413_B415',
    wing: 'B',
    description: 'B-wing lab-side checkpoint for B-413 to B-415.',
    coveredRooms: ['B-413', 'B-414', 'B-415'],
    instructionSummary:
        'B-415 is on the left, B-414 is in the middle, and B-413 is on the right.',
  ),
  Checkpoint(
    id: 'B7',
    name: 'B416_B418',
    wing: 'B',
    description: 'B-wing lab-side checkpoint for B-416 to B-418.',
    coveredRooms: ['B-416', 'B-417', 'B-418'],
    instructionSummary:
        'B-418 is on the left, B-417 is in the middle, and B-416 is on the right.',
  ),
];

Map<String, Checkpoint> get kCheckpointsById => {
  for (final checkpoint in kCheckpoints) checkpoint.id: checkpoint,
};
