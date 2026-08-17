import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure_reason.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_result_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({
    required this.deliveryId,
    required this.store,
    required this.failureReasons,
    required this.onReturnToDeliveries,
    super.key,
  });

  final int deliveryId;
  final DeliveryUiStore store;
  final List<DeliveryFailureReason> failureReasons;
  final VoidCallback onReturnToDeliveries;

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _noteController = TextEditingController();
  int? _selectedReasonId;

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

  void _submitLocally(DeliveryUiModel delivery) {
    FocusScope.of(context).unfocus();
    widget.store.previewReportFailed(delivery.id);
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
          for (final reason in widget.failureReasons)
            _ReasonRow(
              reason: reason,
              isSelected: _selectedReasonId == reason.id,
              onTap: () => setState(() => _selectedReasonId = reason.id),
            ),
          if (widget.failureReasons.isEmpty)
            const Text(
              'No issue reasons are currently available.',
              key: ValueKey('no-report-issue-reasons'),
              style: TextStyle(color: AppColors.mutedInk),
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
          onPressed: _selectedReasonId == null
              ? null
              : () => _submitLocally(delivery),
        ),
      ),
    );
  }
}

class _IssueSummary extends StatelessWidget {
  const _IssueSummary({required this.delivery});

  final DeliveryUiModel delivery;

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

  final DeliveryFailureReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: reason.name,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey(
          'issue-reason-${reason.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}',
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
                child: Text(reason.name, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
