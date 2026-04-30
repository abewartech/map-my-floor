import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localization/navigation_provider.dart';
import 'package:localization/screens/location_screen.dart';
import 'package:localization/screens/map_screen.dart';
import 'package:provider/provider.dart';

Widget _withProvider(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => NavigationProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('LocationScreen renders C1 fallback when provider is Unknown', (
    tester,
  ) async {
    await tester.pumpWidget(_withProvider(const LocationScreen()));
    await tester.pump();

    expect(find.text('C1'), findsOneWidget);
    expect(find.text('LiftLobby'), findsOneWidget);
    expect(find.text('Proceed toward C0 for room navigation.'), findsOneWidget);
  });

  testWidgets('MapScreen routes to a selected destination and clears overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _withProvider(const MapScreen(sourceCheckpointId: 'C1')),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('destinationSearchField')),
      'B-412',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('destinationDropdown')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('B-412').last);
    await tester.pump();

    expect(find.text('B-412'), findsWidgets);
    expect(find.text('Current'), findsOneWidget);
    expect(find.textContaining('C1'), findsWidgets);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('C0'), findsWidgets);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Heading to B-412'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dismissWalkingOverlay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Not selected'), findsOneWidget);
  });
}
