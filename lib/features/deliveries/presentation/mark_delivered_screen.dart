import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_result_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';

class MarkDeliveredScreen extends StatefulWidget {
  const MarkDeliveredScreen({
    required this.deliveryId,
    required this.store,
    required this.onReturnToDeliveries,
    super.key,
  });

  final int deliveryId;
  final DeliveryUiStore store;
  final VoidCallback onReturnToDeliveries;

  @override
  State<MarkDeliveredScreen> createState() => _MarkDeliveredScreenState();
}

class _MarkDeliveredScreenState extends State<MarkDeliveredScreen> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
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

  void _confirmLocally(DeliveryUiModel delivery) {
    FocusScope.of(context).unfocus();
    widget.store.previewMarkDelivered(delivery.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryResultScreen(
          type: DeliveryResultType.delivered,
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
      key: const ValueKey('mark-delivered-screen'),
      appBar: AppBar(title: const Text('Mark delivered')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          112,
        ),
        children: [
          const Text(
            'Complete this delivery',
            style: TextStyle(color: AppColors.mutedInk, fontSize: 15),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (delivery.proofSupported) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proof of delivery',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PhotoUploadArea(onTap: _showPhotoPreview),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (delivery.pinRequired) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery PIN',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      key: const ValueKey('delivery-pin-input'),
                      controller: _pinController,
                      obscureText: true,
                      obscuringCharacter: '•',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 18,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PaymentRow(
                  label: 'Collected amount',
                  value: formatTzs(delivery.amountToCollect),
                ),
                const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
                _PaymentRow(
                  label: 'Payment method',
                  value: delivery.paymentMethod,
                  badge: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery checklist',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: AppSpacing.sm),
                _ChecklistRow(label: 'Right recipient'),
                _ChecklistRow(label: 'Package in good condition'),
                _ChecklistRow(label: 'Amount confirmed'),
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
          key: const ValueKey('confirm-delivered-local'),
          label: 'Confirm delivered',
          onPressed: () => _confirmLocally(delivery),
        ),
      ),
    );
  }
}

class _PhotoUploadArea extends StatelessWidget {
  const _PhotoUploadArea({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('upload-proof-photo'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: double.infinity,
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.postmanOrange,
                  size: 30,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Upload photo',
                  style: TextStyle(
                    color: AppColors.mutedInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = const Color(0xFFB7BABE)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    var distance = 0.0;
    while (distance < metric.length) {
      canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
      distance += 12;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    this.badge = false,
  });

  final String label;
  final String value;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
            ),
          ),
          Flexible(
            child: Container(
              padding: badge
                  ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
                  : EdgeInsets.zero,
              decoration: badge
                  ? BoxDecoration(
                      color: AppColors.postmanOrangeSoft,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: badge ? AppColors.postmanOrangeDark : AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
