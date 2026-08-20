import 'package:pelekapro_mobile/core/config/app_config.dart';
import 'package:pelekapro_mobile/features/navigation/data/osrm_navigation_route_service.dart';
import 'package:pelekapro_mobile/features/navigation/data/unconfigured_navigation_route_service.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';

abstract final class NavigationComposition {
  static NavigationRouteService createRouteService() {
    final baseUri = AppConfig.routingBaseUri;
    return baseUri == null
        ? const UnconfiguredNavigationRouteService()
        : OsrmNavigationRouteService(baseUri: baseUri);
  }
}
