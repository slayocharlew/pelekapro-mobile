class NavigationRouteFailure implements Exception {
  const NavigationRouteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
