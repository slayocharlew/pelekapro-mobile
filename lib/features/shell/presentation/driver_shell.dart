import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/account/presentation/account_page.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_deliveries_page.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_navigation_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/assigned_deliveries_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/deliveries_page.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_details_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/features/navigation/domain/navigation_route_service.dart';
import 'package:pelekapro_mobile/features/tracking/domain/device_location_source.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({
    required this.user,
    required this.repository,
    required this.deliveryRepository,
    required this.onRefreshAccount,
    required this.onSessionExpired,
    required this.onLoggedOut,
    this.deviceLocationSource,
    this.navigationRouteService,
    this.loadMapTiles = true,
    super.key,
  });

  final AuthUser user;
  final AuthRepository repository;
  final DeliveryRepository deliveryRepository;
  final VoidCallback onRefreshAccount;
  final VoidCallback onSessionExpired;
  final VoidCallback onLoggedOut;
  final DeviceLocationSource? deviceLocationSource;
  final NavigationRouteService? navigationRouteService;
  final bool loadMapTiles;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  late final AssignedDeliveriesController _deliveriesController;
  late final DeliveryUiStore _deliveryStore;
  List<DriverDelivery>? _lastSyncedDeliveries;
  var _selectedIndex = 0;
  var _deliveryFilter = DeliveryFilter.all;

  @override
  void initState() {
    super.initState();
    _deliveryStore = DeliveryUiStore();
    _deliveriesController = AssignedDeliveriesController(
      widget.deliveryRepository,
      onUnauthorized: _handleSessionExpired,
    )..addListener(_syncDeliveries);
    unawaited(_deliveriesController.load());
  }

  @override
  void dispose() {
    _deliveriesController
      ..removeListener(_syncDeliveries)
      ..dispose();
    _deliveryStore.dispose();
    super.dispose();
  }

  void _syncDeliveries() {
    final status = _deliveriesController.status;
    if (status != AssignedDeliveriesStatus.ready &&
        status != AssignedDeliveriesStatus.empty) {
      return;
    }

    final deliveries = _deliveriesController.deliveries;
    if (identical(deliveries, _lastSyncedDeliveries)) {
      return;
    }

    _lastSyncedDeliveries = deliveries;
    _deliveryStore.replaceFromServer(deliveries);
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }

  void _handleSessionExpired() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onSessionExpired();
  }

  void _showHistory() {
    setState(() {
      _deliveryFilter = DeliveryFilter.done;
      _selectedIndex = 0;
    });
  }

  void _returnToDeliveries() {
    setState(() {
      _deliveryFilter = DeliveryFilter.all;
      _selectedIndex = 0;
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openDetails(DeliveryUiModel delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryDetailsScreen(
          deliveryId: delivery.id,
          store: _deliveryStore,
          repository: widget.deliveryRepository,
          onSessionExpired: _handleSessionExpired,
          onReturnToDeliveries: _returnToDeliveries,
          deviceLocationSource: widget.deviceLocationSource,
          navigationRouteService: widget.navigationRouteService,
          loadMapTiles: widget.loadMapTiles,
        ),
      ),
    );
  }

  void _openNavigation(DeliveryUiModel delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveNavigationScreen(
          deliveryId: delivery.id,
          store: _deliveryStore,
          repository: widget.deliveryRepository,
          onSessionExpired: _handleSessionExpired,
          onReturnToDeliveries: _returnToDeliveries,
          deviceLocationSource: widget.deviceLocationSource,
          navigationRouteService: widget.navigationRouteService,
          loadMapTiles: widget.loadMapTiles,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('driver-shell'),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DeliveriesPage(
            user: widget.user,
            controller: _deliveriesController,
            store: _deliveryStore,
            filter: _deliveryFilter,
            onFilterChanged: (filter) {
              setState(() => _deliveryFilter = filter);
            },
            onOpenDelivery: _openDetails,
          ),
          ActiveDeliveriesPage(
            controller: _deliveriesController,
            store: _deliveryStore,
            onOpenNavigation: _openNavigation,
          ),
          AccountPage(
            user: widget.user,
            repository: widget.repository,
            onRefresh: widget.onRefreshAccount,
            onOpenHistory: _showHistory,
            onLoggedOut: widget.onLoggedOut,
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectPage,
            destinations: const [
              NavigationDestination(
                key: ValueKey('nav-deliveries'),
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Deliveries',
              ),
              NavigationDestination(
                key: ValueKey('nav-active'),
                icon: Icon(Icons.two_wheeler_outlined),
                selectedIcon: Icon(Icons.two_wheeler_rounded),
                label: 'Active',
              ),
              NavigationDestination(
                key: ValueKey('nav-account'),
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
