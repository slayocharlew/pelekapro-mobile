import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/data/image_picker_delivery_proof_photo_picker.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_completion_request.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_proof_photo_picker.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/recorded_delivery_location.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_formatters.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_result_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/delivery_ui_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/mark_delivered_controller.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/models/delivery_ui_model.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';

class MarkDeliveredScreen extends StatefulWidget {
  const MarkDeliveredScreen({
    required this.deliveryId,
    required this.store,
    required this.repository,
    required this.onSessionExpired,
    required this.onReturnToDeliveries,
    this.lastRecordedLocation,
    this.proofPhotoPicker,
    super.key,
  });

  final int deliveryId;
  final DeliveryUiStore store;
  final DeliveryRepository repository;
  final VoidCallback onSessionExpired;
  final VoidCallback onReturnToDeliveries;
  final RecordedDeliveryLocation? lastRecordedLocation;
  final DeliveryProofPhotoPicker? proofPhotoPicker;

  @override
  State<MarkDeliveredScreen> createState() => _MarkDeliveredScreenState();
}

class _MarkDeliveredScreenState extends State<MarkDeliveredScreen> {
  final _pinController = TextEditingController();
  final _amountController = TextEditingController();
  late final MarkDeliveredController _controller;
  late final DeliveryProofPhotoPicker _photoPicker;
  DeliveryProofPhoto? _proofPhoto;
  Map<String, String> _localFieldErrors = const {};
  var _isPickingPhoto = false;

  @override
  void initState() {
    super.initState();
    _controller = MarkDeliveredController(
      widget.repository,
      onUnauthorized: widget.onSessionExpired,
    );
    _photoPicker =
        widget.proofPhotoPicker ?? ImagePickerDeliveryProofPhotoPicker();
    final delivery = widget.store.deliveryById(widget.deliveryId);
    if (delivery.paymentCollectionRequired) {
      _amountController.text = _editableAmount(
        delivery.expectedCollectionAmount,
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _amountController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<DeliveryProofPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('proof-photo-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () =>
                  Navigator.pop(context, DeliveryProofPhotoSource.camera),
            ),
            ListTile(
              key: const ValueKey('proof-photo-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.pop(context, DeliveryProofPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }

    setState(() {
      _isPickingPhoto = true;
      _localFieldErrors = {
        for (final entry in _localFieldErrors.entries)
          if (entry.key != 'proof_file') entry.key: entry.value,
      };
    });
    try {
      final photo = await _photoPicker.pick(source);
      if (mounted && photo != null) {
        setState(() => _proofPhoto = photo);
      }
    } on DeliveryProofPhotoFailure catch (failure) {
      if (mounted) {
        setState(() {
          _localFieldErrors = {
            ..._localFieldErrors,
            'proof_file': failure.message,
          };
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _localFieldErrors = {
            ..._localFieldErrors,
            'proof_file': 'The photo could not be selected. Try again.',
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _proofPhoto = null;
      _localFieldErrors = {
        for (final entry in _localFieldErrors.entries)
          if (entry.key != 'proof_file') entry.key: entry.value,
      };
    });
  }

  Future<void> _submit(DeliveryUiModel delivery) async {
    FocusScope.of(context).unfocus();
    final errors = <String, String>{};
    final pin = _pinController.text.trim();
    if (delivery.pinRequired && pin.isEmpty) {
      errors['delivery_pin'] = 'Enter the delivery PIN.';
    }

    double? collectedAmount;
    if (delivery.paymentCollectionRequired) {
      collectedAmount = double.tryParse(
        _amountController.text.replaceAll(',', '').trim(),
      );
      if (collectedAmount == null ||
          !collectedAmount.isFinite ||
          collectedAmount < 0) {
        errors['collected_amount'] = 'Enter a valid collected amount.';
      }
    }

    setState(() => _localFieldErrors = errors);
    if (errors.isNotEmpty) {
      return;
    }

    final location = widget.lastRecordedLocation;
    await _controller.complete(
      delivery.id,
      DeliveryCompletionRequest(
        deliveryPin: delivery.pinRequired ? pin : null,
        proofPhoto: _proofPhoto,
        collectedAmount: collectedAmount,
        deliveredLatitude: location?.latitude,
        deliveredLongitude: location?.longitude,
      ),
    );
    if (!mounted || _controller.isUnauthorized) {
      return;
    }

    if (_controller.status == MarkDeliveredStatus.success) {
      _openResult(_controller.completedDelivery!);
      return;
    }

    if (_controller.errorStatusCode == 404) {
      widget.onReturnToDeliveries();
      return;
    }

    if (_controller.shouldReconcile) {
      final completed = await _controller.reconcile(delivery.id);
      if (mounted && completed && _controller.completedDelivery != null) {
        _openResult(_controller.completedDelivery!);
      }
    }
  }

  void _openResult(DriverDelivery completedDelivery) {
    widget.store.replaceOneFromServer(completedDelivery);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DeliveryResultScreen(
          type: DeliveryResultType.delivered,
          deliveryCode: completedDelivery.deliveryNumber,
          onBackToDeliveries: widget.onReturnToDeliveries,
        ),
      ),
    );
  }

  String? _fieldError(String field) {
    return _localFieldErrors[field] ?? _controller.fieldError(field);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, widget.store]),
      builder: (context, _) {
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
              if (_controller.errorMessage case final message?) ...[
                const SizedBox(height: AppSpacing.md),
                _CompletionErrorBanner(message: message),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (delivery.photoProofSupported) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Proof of delivery',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _PhotoUploadArea(
                        photo: _proofPhoto,
                        isLoading: _isPickingPhoto,
                        onTap: _controller.isSubmitting
                            ? null
                            : () => unawaited(_choosePhoto()),
                        onRemove: _controller.isSubmitting
                            ? null
                            : _removePhoto,
                      ),
                      if (_fieldError('proof_file') case final error?) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          error,
                          key: const ValueKey('proof-photo-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        key: const ValueKey('delivery-pin-input'),
                        controller: _pinController,
                        enabled: !_controller.isSubmitting,
                        obscureText: true,
                        obscuringCharacter: '•',
                        keyboardType: TextInputType.visiblePassword,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Enter PIN',
                          errorText: _fieldError('delivery_pin'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 14,
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
                    if (delivery.paymentCollectionRequired)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: TextField(
                          key: const ValueKey('collected-amount-input'),
                          controller: _amountController,
                          enabled: !_controller.isSubmitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Collected amount',
                            prefixText: 'TZS ',
                            helperText:
                                'Expected ${formatTzs(delivery.expectedCollectionAmount)}',
                            errorText: _fieldError('collected_amount'),
                          ),
                        ),
                      )
                    else
                      const _PaymentRow(
                        label: 'Collected amount',
                        value: 'No collection required',
                      ),
                    const Divider(
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                    _PaymentRow(
                      label: 'Payment method',
                      value: delivery.collectionMethod,
                      badge: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery checklist',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _ChecklistRow(label: 'Right recipient'),
                    const _ChecklistRow(label: 'Package in good condition'),
                    _ChecklistRow(
                      label: delivery.paymentCollectionRequired
                          ? 'Amount confirmed'
                          : 'Delivery details confirmed',
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
              key: const ValueKey('confirm-delivered-api'),
              label: 'Confirm delivered',
              isLoading: _controller.isSubmitting,
              onPressed: _controller.isSubmitting || _isPickingPhoto
                  ? null
                  : () => unawaited(_submit(delivery)),
            ),
          ),
        );
      },
    );
  }

  static String _editableAmount(double amount) {
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }
}

class _CompletionErrorBanner extends StatelessWidget {
  const _CompletionErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mark-delivered-error'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.postmanOrangeSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.postmanOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              style: const TextStyle(
                color: AppColors.postmanOrangeDark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadArea extends StatelessWidget {
  const _PhotoUploadArea({
    required this.photo,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
  });

  final DeliveryProofPhoto? photo;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('upload-proof-photo'),
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: 112,
            child: switch ((isLoading, photo)) {
              (true, _) => const Center(
                child: SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
              (false, final selected?) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      selected.bytes,
                      fit: BoxFit.cover,
                      semanticLabel: 'Selected proof photo',
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Text(
                            selected.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const ValueKey('remove-proof-photo'),
                        onPressed: onRemove,
                        tooltip: 'Remove proof photo',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _ => const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.postmanOrange,
                    size: 30,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add photo (optional)',
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            },
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
