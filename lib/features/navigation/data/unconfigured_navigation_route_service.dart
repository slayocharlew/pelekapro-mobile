import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_failure.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';

class UnconfiguredNavigationRouteService implements NavigationRouteService {
  const UnconfiguredNavigationRouteService();

  @override
  bool get isConfigured => false;

  @override
  Future<NavigationRoute> route({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  }) {
    throw const NavigationRouteFailure(
      'Road guidance is not configured. Showing real map positions only.',
    );
  }

  @override
  void close() {}
}
