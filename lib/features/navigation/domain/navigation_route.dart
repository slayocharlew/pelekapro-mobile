import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';

class NavigationRoute {
  NavigationRoute({
    required List<NavigationCoordinate> geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.guidance,
  }) : geometry = List<NavigationCoordinate>.unmodifiable(geometry),
       assert(distanceMeters >= 0),
       assert(durationSeconds >= 0),
       assert(geometry.length >= 2);

  final List<NavigationCoordinate> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final NavigationGuidance guidance;
}

class NavigationGuidance {
  const NavigationGuidance({
    required this.instruction,
    required this.roadName,
    required this.distanceMeters,
    required this.maneuver,
  }) : assert(distanceMeters >= 0);

  final String instruction;
  final String roadName;
  final double distanceMeters;
  final NavigationManeuver maneuver;
}

enum NavigationManeuver {
  depart,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  merge,
  fork,
  roundabout,
  arrive,
}
