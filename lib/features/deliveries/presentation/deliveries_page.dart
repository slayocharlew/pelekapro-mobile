import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

enum DeliveryFilter { all, active, done }

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({
    required this.user,
    required this.store,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenDelivery,
    super.key,
  });

  final AuthUser user;
  final DemoDeliveryStore store;
  final DeliveryFilter filter;
  final ValueChanged<DeliveryFilter> onFilterChanged;
  final ValueChanged<DemoDelivery> onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final deliveries = switch (filter) {
            DeliveryFilter.all => store.deliveries,
            DeliveryFilter.active =>
              store.deliveries
                  .where((delivery) => delivery.status.isActive)
                  .toList(),
            DeliveryFilter.done =>
              store.deliveries
                  .where((delivery) => delivery.status.isDone)
                  .toList(),
          };

          return CustomScrollView(
            key: const ValueKey('deliveries-page'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    _DriverHeader(user: user),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Assigned deliveries',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your deliveries for today',
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'UI DEMO',
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SummaryRow(store: store),
                    const SizedBox(height: AppSpacing.lg),
                    _FilterRow(selected: filter, onChanged: onFilterChanged),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
              if (deliveries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyDeliveries(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: deliveries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final delivery = deliveries[index];
                      return _DeliveryCard(
                        delivery: delivery,
                        onOpen: () => onOpenDelivery(delivery),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const PelekaProBrand(compact: true),
        const Spacer(),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Driver',
                style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _InitialsAvatar(name: user.name),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.postmanOrangeSoft,
      foregroundColor: AppColors.postmanOrangeDark,
      child: Text(
        initials.isEmpty ? 'D' : initials,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.store});

  final DemoDeliveryStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Today',
            value: store.todayCount,
            icon: Icons.calendar_today_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryCard(
            label: 'Active',
            value: store.activeCount,
            icon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SummaryCard(
            label: 'Done',
            value: store.doneCount,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.postmanOrange),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final DeliveryFilter selected;
  final ValueChanged<DeliveryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: [
        _FilterChip(
          label: 'All',
          value: DeliveryFilter.all,
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Active',
          value: DeliveryFilter.active,
          selected: selected,
          onChanged: onChanged,
        ),
        _FilterChip(
          label: 'Done',
          value: DeliveryFilter.done,
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final DeliveryFilter value;
  final DeliveryFilter selected;
  final ValueChanged<DeliveryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return ChoiceChip(
      key: ValueKey('delivery-filter-${value.name}'),
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => onChanged(value),
      backgroundColor: AppColors.white,
      selectedColor: AppColors.postmanOrange,
      side: BorderSide(
        color: isSelected ? AppColors.postmanOrange : AppColors.border,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.mutedInk,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.onOpen});

  final DemoDelivery delivery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.postmanOrangeSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  delivery.code,
                  style: const TextStyle(
                    color: AppColors.postmanOrangeDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(status: delivery.status.apiValue),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            delivery.recipientName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _RouteLine(
            label: 'From',
            value: delivery.pickupArea,
            icon: Icons.circle,
          ),
          const SizedBox(height: AppSpacing.xs),
          _RouteLine(
            label: 'To',
            value: delivery.dropoffArea,
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppColors.mutedInk,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                delivery.scheduledTime,
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                key: ValueKey('view-delivery-${delivery.id}'),
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  minimumSize: const Size(60, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('View'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.postmanOrange),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 38,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.ink, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EmptyDeliveries extends StatelessWidget {
  const _EmptyDeliveries();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AppColors.mutedInk,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'No deliveries assigned',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
