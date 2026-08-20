import 'package:pelekapro_mobile/features/navigation/domain/navigation_coordinate.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route.dart';

abstract interface class NavigationRouteService {
  bool get isConfigured;

  Future<NavigationRoute> route({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
  });

  void close();
}
