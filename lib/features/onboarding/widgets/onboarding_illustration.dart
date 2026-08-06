import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';

enum OnboardingIllustrationKind { deliveries, tracking, completion }

class OnboardingIllustration extends StatefulWidget {
  const OnboardingIllustration({
    required this.kind,
    required this.semanticLabel,
    super.key,
  });

  final OnboardingIllustrationKind kind;
  final String semanticLabel;

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _motion;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _motion = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);

    if (_reduceMotion == reduceMotion) {
      return;
    }

    _reduceMotion = reduceMotion;

    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0.5;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, child) {
            final motion = (_motion.value - 0.5) * 2;

            return _IllustrationStage(kind: widget.kind, motion: motion);
          },
        ),
      ),
    );
  }
}

class _IllustrationStage extends StatelessWidget {
  const _IllustrationStage({required this.kind, required this.motion});

  final OnboardingIllustrationKind kind;
  final double motion;

  @override
  Widget build(BuildContext context) {
    final details = _IllustrationDetails.forKind(kind);
    final perspective = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(motion * 0.025)
      ..rotateY(motion * 0.055);

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 330,
          height: 270,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 24 + (motion * 5),
                top: 26 - (motion * 3),
                child: const _SoftOrb(size: 72),
              ),
              Positioned(
                right: 17 - (motion * 4),
                bottom: 32 + (motion * 4),
                child: const _SoftOrb(size: 52),
              ),
              Positioned(
                left: 45,
                right: 45,
                bottom: 18,
                child: Transform.scale(
                  scaleX: 1 - (motion.abs() * 0.04),
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                top: 20,
                bottom: 36,
                child: Transform.translate(
                  offset: Offset(0, motion * 6),
                  child: Transform(
                    key: ValueKey('onboarding-illustration-${kind.name}'),
                    alignment: Alignment.center,
                    transform: perspective,
                    child: Center(
                      child: Container(
                        width: 208,
                        height: 174,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF8157),
                              AppColors.postmanOrange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(38),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.postmanOrangeDark.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 32,
                              offset: const Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              details.primaryIcon,
                              size: 72,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 88,
                              height: 9,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24 + (motion * 7),
                top: 116 - (motion * 5),
                child: Transform.rotate(
                  angle: -0.08 + (motion * 0.02),
                  child: _FloatingBadge(
                    icon: details.leftIcon,
                    label: details.leftLabel,
                  ),
                ),
              ),
              Positioned(
                right: 18 - (motion * 8),
                top: 55 + (motion * 6),
                child: Transform.rotate(
                  angle: 0.08 - (motion * 0.025),
                  child: _FloatingBadge(
                    icon: details.rightIcon,
                    label: details.rightLabel,
                  ),
                ),
              ),
              Positioned(
                right: 59 + (motion * 4),
                bottom: 27 - (motion * 3),
                child: _RoundBadge(icon: details.bottomIcon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationDetails {
  const _IllustrationDetails({
    required this.primaryIcon,
    required this.leftIcon,
    required this.leftLabel,
    required this.rightIcon,
    required this.rightLabel,
    required this.bottomIcon,
  });

  final IconData primaryIcon;
  final IconData leftIcon;
  final String leftLabel;
  final IconData rightIcon;
  final String rightLabel;
  final IconData bottomIcon;

  static _IllustrationDetails forKind(OnboardingIllustrationKind kind) {
    return switch (kind) {
      OnboardingIllustrationKind.deliveries => const _IllustrationDetails(
        primaryIcon: Icons.local_shipping_rounded,
        leftIcon: Icons.inventory_2_rounded,
        leftLabel: 'Orders',
        rightIcon: Icons.task_alt_rounded,
        rightLabel: 'Ready',
        bottomIcon: Icons.route_rounded,
      ),
      OnboardingIllustrationKind.tracking => const _IllustrationDetails(
        primaryIcon: Icons.navigation_rounded,
        leftIcon: Icons.play_circle_fill_rounded,
        leftLabel: 'Start',
        rightIcon: Icons.location_on_rounded,
        rightLabel: 'Live',
        bottomIcon: Icons.shield_rounded,
      ),
      OnboardingIllustrationKind.completion => const _IllustrationDetails(
        primaryIcon: Icons.verified_rounded,
        leftIcon: Icons.photo_camera_rounded,
        leftLabel: 'Proof',
        rightIcon: Icons.payments_rounded,
        rightLabel: 'Paid',
        bottomIcon: Icons.done_all_rounded,
      ),
    };
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: AppColors.postmanOrangeDark),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 18,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 25),
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.postmanOrangeSoft,
        shape: BoxShape.circle,
      ),
    );
  }
}
