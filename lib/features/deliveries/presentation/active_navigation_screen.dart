import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/demo/demo_delivery_store.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/mark_delivered_screen.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/report_issue_screen.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';
import 'package:pelekapro_mobile/shared/widgets/status_badge.dart';

class ActiveNavigationScreen extends StatefulWidget {
  const ActiveNavigationScreen({
    required this.deliveryId,
    required this.store,
    required this.onReturnToDeliveries,
    super.key,
  });

  final String deliveryId;
  final DemoDeliveryStore store;
  final VoidCallback onReturnToDeliveries;

  @override
  State<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends State<ActiveNavigationScreen> {
  var _isMuted = false;

  void _openDelivered(DemoDelivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarkDeliveredScreen(
          deliveryId: delivery.id,
          store: widget.store,
          onReturnToDeliveries: widget.onReturnToDeliveries,
        ),
      ),
    );
  }

  void _openIssue(DemoDelivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportIssueScreen(
          deliveryId: delivery.id,
          store: widget.store,
          onReturnToDeliveries: widget.onReturnToDeliveries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.store.deliveryById(widget.deliveryId);
    return Scaffold(
      key: const ValueKey('active-navigation-screen'),
      body: Stack(
        children: [
          Positioned.fill(
            child: _NavigationMap(
              destination: delivery.dropoffArea.split(',').first,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                0,
              ),
              child: Column(
                children: [
                  _NavigationTopBar(
                    onBack: () => Navigator.of(context).pop(),
                    onCall: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Calling will use the live customer number later.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _TurnInstruction(),
                ],
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.sm,
            top: MediaQuery.paddingOf(context).top + 190,
            child: Column(
              children: [
                _MapControl(
                  icon: _isMuted
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  label: _isMuted ? 'Unmute guidance' : 'Mute guidance',
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _MapControl(
                  icon: Icons.explore_outlined,
                  label: 'Compass',
                ),
                const SizedBox(height: AppSpacing.xs),
                const _MapControl(
                  icon: Icons.my_location_rounded,
                  label: 'Recenter',
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.sm,
            bottom: MediaQuery.sizeOf(context).height * 0.45,
            child: const _MapAttribution(),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.38,
            maxChildSize: 0.72,
            snap: true,
            builder: (context, scrollController) {
              return _DeliveryNavigationSheet(
                delivery: delivery,
                scrollController: scrollController,
                onDelivered: () => _openDelivered(delivery),
                onIssue: () => _openIssue(delivery),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NavigationTopBar extends StatelessWidget {
  const _NavigationTopBar({required this.onBack, required this.onCall});

  final VoidCallback onBack;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: PelekaProBrand(compact: true, showMobile: false),
            ),
          ),
          IconButton(
            onPressed: onCall,
            tooltip: 'Call customer',
            icon: const Icon(
              Icons.phone_outlined,
              color: AppColors.postmanOrange,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnInstruction extends StatelessWidget {
  const _TurnInstruction();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.turn_right_rounded,
            color: AppColors.postmanOrange,
            size: 34,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn right',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ali Hassan Mwinyi Rd',
                  style: TextStyle(color: AppColors.mutedInk, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '150 m',
            style: TextStyle(
              color: AppColors.postmanOrangeDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationMap extends StatelessWidget {
  const _NavigationMap({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'OpenStreetMap style navigation preview in $destination, Dar es Salaam',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _DarMapPainter()),
              Positioned(
                left: width * 0.52,
                top: height * 0.29,
                child: const _RoadLabel('Ali Hassan Mwinyi Rd'),
              ),
              Positioned(
                left: width * 0.05,
                top: height * 0.37,
                child: const _RoadLabel('Mwai Kibaki Rd'),
              ),
              Positioned(
                left: width * 0.10,
                top: height * 0.31,
                child: Text(
                  destination.toUpperCase(),
                  style: TextStyle(
                    color: Color(0xFF6B7780),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Positioned(
                left: width * 0.56,
                top: height * 0.22,
                child: _DestinationMarker(destination: destination),
              ),
              Positioned(
                left: width * 0.47,
                top: height * 0.43,
                child: const MotorcycleMarker(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DarMapPainter extends CustomPainter {
  const _DarMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF1F2EF),
    );

    final parkPaint = Paint()..color = const Color(0xFFDCEEDB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.18, 150, 105),
        const Radius.circular(28),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.28, 100, 70),
        const Radius.circular(20),
      ),
      parkPaint,
    );

    final minorRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadEdge = Paint()
      ..color = const Color(0xFFE0E2DE)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roads = <Path>[
      Path()
        ..moveTo(-20, size.height * 0.24)
        ..quadraticBezierTo(
          size.width * 0.45,
          size.height * 0.30,
          size.width + 20,
          size.height * 0.20,
        ),
      Path()
        ..moveTo(-20, size.height * 0.40)
        ..quadraticBezierTo(
          size.width * 0.46,
          size.height * 0.36,
          size.width + 20,
          size.height * 0.43,
        ),
      Path()
        ..moveTo(size.width * 0.20, 0)
        ..lineTo(size.width * 0.34, size.height * 0.62),
      Path()
        ..moveTo(size.width * 0.76, 0)
        ..lineTo(size.width * 0.62, size.height * 0.64),
      Path()
        ..moveTo(size.width * 0.08, 0)
        ..lineTo(size.width * 0.87, size.height * 0.60),
    ];

    for (final road in roads) {
      canvas.drawPath(road, roadEdge);
      canvas.drawPath(road, minorRoad);
    }

    final route = Path()
      ..moveTo(size.width * 0.50, size.height * 0.52)
      ..lineTo(size.width * 0.49, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.49,
        size.height * 0.31,
        size.width * 0.54,
        size.height * 0.31,
      )
      ..lineTo(size.width * 0.63, size.height * 0.24);
    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.postmanOrange
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MotorcycleMarker extends StatelessWidget {
  const MotorcycleMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Driver motorcycle position',
      excludeSemantics: true,
      child: Container(
        width: 44,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const CustomPaint(painter: _MotorcyclePainter()),
      ),
    );
  }
}

class _MotorcyclePainter extends CustomPainter {
  const _MotorcyclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF343638);
    final orange = Paint()..color = AppColors.postmanOrange;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, 10),
        width: 12,
        height: 15,
      ),
      dark,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 9),
        width: 13,
        height: 17,
      ),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 17,
          height: 28,
        ),
        const Radius.circular(7),
      ),
      orange,
    );
    canvas.drawCircle(Offset(size.width / 2, 22), 6, dark);
    canvas.drawLine(
      Offset(size.width * 0.25, 17),
      Offset(size.width * 0.75, 17),
      Paint()
        ..color = dark.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker({required this.destination});

  final String destination;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_rounded,
          color: AppColors.postmanOrange,
          size: 38,
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Drop off',
                style: TextStyle(
                  color: AppColors.postmanOrangeDark,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadLabel extends StatelessWidget {
  const _RoadLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5F666C),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: IconButton(
        onPressed: onPressed ?? () {},
        tooltip: label,
        icon: Icon(icon, size: 21),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'OpenStreetMap • UI preview',
        style: TextStyle(color: AppColors.mutedInk, fontSize: 9),
      ),
    );
  }
}

class _DeliveryNavigationSheet extends StatelessWidget {
  const _DeliveryNavigationSheet({
    required this.delivery,
    required this.scrollController,
    required this.onDelivered,
    required this.onIssue,
  });

  final DemoDelivery delivery;
  final ScrollController scrollController;
  final VoidCallback onDelivered;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        key: const ValueKey('active-navigation-sheet-list'),
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          AppSpacing.md + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.code,
                      style: const TextStyle(
                        color: AppColors.postmanOrangeDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      delivery.recipientName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: delivery.status.apiValue),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SheetRouteRow(
            icon: Icons.circle,
            label: 'Pickup',
            value: _shortArea(delivery.pickupArea),
          ),
          const SizedBox(height: AppSpacing.xs),
          _SheetRouteRow(
            icon: Icons.location_on_rounded,
            label: 'Drop off',
            value: _shortArea(delivery.dropoffArea),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _SheetMetric(
                  label: 'Last update',
                  value: delivery.lastUpdate,
                ),
              ),
              Expanded(
                child: _SheetMetric(
                  label: 'ETA',
                  value: '${delivery.eta} • ${delivery.distance}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _DeliveryProgress(),
          const SizedBox(height: AppSpacing.md),
          _NavigationActions(onDelivered: onDelivered, onIssue: onIssue),
        ],
      ),
    );
  }

  static String _shortArea(String value) => value.split(',').first;
}

class _NavigationActions extends StatelessWidget {
  const _NavigationActions({required this.onDelivered, required this.onIssue});

  final VoidCallback onDelivered;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    final deliveredButton = FilledButton(
      key: const ValueKey('mark-delivered-local'),
      onPressed: onDelivered,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.successSoft,
        foregroundColor: AppColors.success,
      ),
      child: const _FlexibleButtonLabel(
        icon: Icons.check_circle_outline_rounded,
        label: 'Mark delivered',
      ),
    );
    final issueButton = OutlinedButton(
      key: const ValueKey('report-issue-local'),
      onPressed: onIssue,
      child: const _FlexibleButtonLabel(
        icon: Icons.report_gmailerrorred_outlined,
        label: 'Report issue',
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final usesLargerText =
            MediaQuery.textScalerOf(context).scale(14) > 15.5;
        if (constraints.maxWidth < 340 || usesLargerText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              deliveredButton,
              const SizedBox(height: AppSpacing.xs),
              issueButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: deliveredButton),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: issueButton),
          ],
        );
      },
    );
  }
}

class _FlexibleButtonLabel extends StatelessWidget {
  const _FlexibleButtonLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SheetRouteRow extends StatelessWidget {
  const _SheetRouteRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.postmanOrange, size: 17),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _SheetMetric extends StatelessWidget {
  const _SheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.whiteSmoke,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress();

  @override
  Widget build(BuildContext context) {
    const labels = ['Assigned', 'Picked up', 'On the way', 'Delivered'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: index < 3
                        ? AppColors.postmanOrange
                        : AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index < 3
                          ? AppColors.postmanOrange
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: index == 2
                        ? AppColors.postmanOrangeDark
                        : AppColors.mutedInk,
                    fontSize: 9,
                    fontWeight: index == 2 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: index < 2 ? AppColors.postmanOrange : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}
