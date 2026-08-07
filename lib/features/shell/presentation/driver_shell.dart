import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/account/presentation/account_page.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_deliveries_page.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_navigation_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/deliveries_page.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_details_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({
    required this.user,
    required this.repository,
    required this.onRefreshAccount,
    required this.onLoggedOut,
    super.key,
  });

  final AuthUser user;
  final AuthRepository repository;
  final VoidCallback onRefreshAccount;
  final VoidCallback onLoggedOut;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  late final DemoDeliveryStore _demoStore;
  var _selectedIndex = 0;
  var _deliveryFilter = DeliveryFilter.all;

  @override
  void initState() {
    super.initState();
    _demoStore = DemoDeliveryStore();
  }

  @override
  void dispose() {
    _demoStore.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
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

  void _openDetails(DemoDelivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryDetailsScreen(
          deliveryId: delivery.id,
          store: _demoStore,
          onReturnToDeliveries: _returnToDeliveries,
        ),
      ),
    );
  }

  void _openNavigation(DemoDelivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveNavigationScreen(
          deliveryId: delivery.id,
          store: _demoStore,
          onReturnToDeliveries: _returnToDeliveries,
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
            store: _demoStore,
            filter: _deliveryFilter,
            onFilterChanged: (filter) {
              setState(() => _deliveryFilter = filter);
            },
            onOpenDelivery: _openDetails,
          ),
          ActiveDeliveriesPage(
            store: _demoStore,
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
