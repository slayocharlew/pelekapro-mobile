import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/assigned_deliveries_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

enum DeliveryFilter { all, active, done }

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({
    required this.user,
    required this.controller,
    required this.store,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenDelivery,
    super.key,
  });

  final AuthUser user;
  final AssignedDeliveriesController controller;
  final DeliveryUiStore store;
  final DeliveryFilter filter;
  final ValueChanged<DeliveryFilter> onFilterChanged;
  final ValueChanged<DeliveryUiModel> onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([controller, store]),
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

          final isInitialLoading =
              store.deliveries.isEmpty &&
              (controller.status == AssignedDeliveriesStatus.initial ||
                  controller.status == AssignedDeliveriesStatus.loading);
          final hasBlockingError =
              store.deliveries.isEmpty &&
              controller.status == AssignedDeliveriesStatus.failure;

          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              key: const ValueKey('deliveries-page'),
              physics: const AlwaysScrollableScrollPhysics(),
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
                      _DriverHeader(
                        user: user,
                        isRefreshing:
                            controller.status ==
                            AssignedDeliveriesStatus.refreshing,
                        onRefresh: controller.refresh,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Assigned deliveries',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      const Text(
                        'Your deliveries for today',
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SummaryRow(store: store),
                      const SizedBox(height: AppSpacing.lg),
                      _FilterRow(selected: filter, onChanged: onFilterChanged),
                      const SizedBox(height: AppSpacing.md),
                      if (controller.status ==
                              AssignedDeliveriesStatus.failure &&
                          store.deliveries.isNotEmpty)
                        _InlineRefreshError(
                          message: controller.errorMessage!,
                          onRetry: controller.refresh,
                        ),
                    ],
                  ),
                ),
                if (isInitialLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LoadingDeliveries(),
                  )
                else if (hasBlockingError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DeliveryError(
                      message: controller.errorMessage!,
                      onRetry: controller.load,
                    ),
                  )
                else if (deliveries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyDeliveries(filter: filter),
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
            ),
          );
        },
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
    required this.user,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final AuthUser user;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showDriverName = constraints.maxWidth >= 400;
        return Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: PelekaProBrand(compact: true),
              ),
            ),
            if (showDriverName) ...[
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
            ],
            IconButton(
              key: const ValueKey('refresh-assigned-deliveries'),
              onPressed: isRefreshing ? null : onRefresh,
              tooltip: 'Refresh assigned deliveries',
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: isRefreshing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: user.name,
              child: _InitialsAvatar(name: user.name),
            ),
          ],
        );
      },
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

  final DeliveryUiStore store;

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

  final DeliveryUiModel delivery;
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppColors.mutedInk,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        formatDeliveryTime(context, delivery.assignedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
  const _EmptyDeliveries({required this.filter});

  final DeliveryFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      DeliveryFilter.all => 'No deliveries assigned',
      DeliveryFilter.active => 'No active delivery',
      DeliveryFilter.done => 'No completed deliveries',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 42,
              color: AppColors.mutedInk,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDeliveries extends StatelessWidget {
  const _LoadingDeliveries();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        key: ValueKey('assigned-deliveries-loading'),
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _DeliveryError extends StatelessWidget {
  const _DeliveryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: AppColors.mutedInk,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('retry-assigned-deliveries'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineRefreshError extends StatelessWidget {
  const _InlineRefreshError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.postmanOrangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.postmanOrangeDark,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
