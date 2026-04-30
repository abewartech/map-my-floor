import 'package:flutter_test/flutter_test.dart';
import 'package:localization/utils/dijkstra.dart';

void main() {
  test('returns same node route', () {
    expect(findPath('C1', 'C1'), ['C1']);
  });

  test('returns empty route for invalid nodes', () {
    expect(findPath('C1', 'Z9'), isEmpty);
    expect(findPath('Z9', 'C1'), isEmpty);
  });

  test('uses bidirectional edges', () {
    expect(findPath('A1', 'C1'), ['A1', 'C0', 'C1']);
  });

  test('routes C1 to B-412 destination checkpoint', () {
    expect(findPath('C1', 'B4'), ['C1', 'C0', 'B1', 'B2', 'B3', 'B4']);
  });

  test('routes through A7 and A6 lab-side checkpoints', () {
    expect(findPath('C1', 'A6'), ['C1', 'C0', 'A7', 'A6']);
  });

  test('routes through B7 and B6 lab-side checkpoints', () {
    expect(findPath('C1', 'B6'), ['C1', 'C0', 'B7', 'B6']);
  });
}
