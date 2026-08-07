import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_result_screen.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({
    required this.deliveryId,
    required this.store,
    required this.onReturnToDeliveries,
    super.key,
  });

  final String deliveryId;
  final DemoDeliveryStore store;
  final VoidCallback onReturnToDeliveries;

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _noteController = TextEditingController();
  String? _selectedReason;

  static const reasons = [
    'Customer unavailable',
    'Wrong address',
    'No answer',
    'Rescheduled',
    'Other',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showPhotoPreview() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Photo capture is not connected in this UI review.'),
        ),
      );
  }

  void _submitLocally(DemoDelivery delivery) {
    FocusScope.of(context).unfocus();
    widget.store.reportFailed(delivery.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryResultScreen(
          type: DeliveryResultType.failed,
          deliveryCode: delivery.code,
          onBackToDeliveries: widget.onReturnToDeliveries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.store.deliveryById(widget.deliveryId);
    return Scaffold(
      key: const ValueKey('report-issue-screen'),
      appBar: AppBar(title: const Text('Report issue')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          112,
        ),
        children: [
          _IssueSummary(delivery: delivery),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'What went wrong?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final reason in reasons)
            _ReasonRow(
              reason: reason,
              isSelected: _selectedReason == reason,
              onTap: () => setState(() => _selectedReason = reason),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Add a note (optional)',
            style: TextStyle(color: AppColors.mutedInk, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            key: const ValueKey('issue-note'),
            controller: _noteController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Add a note',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            onTap: _showPhotoPreview,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.postmanOrangeSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.postmanOrange,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add photo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Optional',
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedInk,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: PrimaryButton(
          key: const ValueKey('submit-issue-local'),
          label: 'Submit issue',
          onPressed: _selectedReason == null
              ? null
              : () => _submitLocally(delivery),
        ),
      ),
    );
  }
}

class _IssueSummary extends StatelessWidget {
  const _IssueSummary({required this.delivery});

  final DemoDelivery delivery;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                delivery.code,
                style: const TextStyle(
                  color: AppColors.postmanOrangeDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(status: delivery.status.apiValue),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              delivery.recipientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.postmanOrange,
                size: 19,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  delivery.dropoffArea,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  final String reason;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: reason,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey(
          'issue-reason-${reason.toLowerCase().replaceAll(' ', '-')}',
        ),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected
                    ? AppColors.postmanOrange
                    : AppColors.mutedInk,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(reason, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
