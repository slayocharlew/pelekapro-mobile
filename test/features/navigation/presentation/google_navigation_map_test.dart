import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pelekapro_mobile/features/navigation/domain/google_maps_configuration.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/presentation/google_navigation_map.dart';

void main() {
  testWidgets('shows a safe state when the Android map key is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleNavigationMap(
            destinationLabel: 'Mikocheni',
            destination: const NavigationCoordinate(
              latitude: -6.769,
              longitude: 39.234,
            ),
            currentLocation: const NavigationCoordinate(
              latitude: -6.7924,
              longitude: 39.2083,
            ),
            route: null,
            heading: 90,
            loadGoogleMap: true,
            followDriver: true,
            followHeading: true,
            recenterRequest: 0,
            onInteractionStarted: _doNothing,
            mapsConfiguration: const _MissingMapsConfiguration(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMapUnavailableState), findsOneWidget);
    expect(find.text('Google Maps unavailable'), findsOneWidget);
    expect(find.textContaining('not configured'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
  });
}

void _doNothing() {}

class _MissingMapsConfiguration implements GoogleMapsConfiguration {
  const _MissingMapsConfiguration();

  @override
  Future<bool> isConfigured() async => false;
}
