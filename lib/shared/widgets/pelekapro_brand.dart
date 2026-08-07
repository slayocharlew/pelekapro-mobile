import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';

class PelekaProBrand extends StatelessWidget {
  const PelekaProBrand({
    this.compact = false,
    this.showMobile = true,
    super.key,
  });

  final bool compact;
  final bool showMobile;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 38.0 : 54.0;
    final nameSize = compact ? 19.0 : 29.0;

    return Semantics(
      label: 'PelekaPro Mobile',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: markSize,
            child: const CustomPaint(painter: _PelekaProMarkPainter()),
          ),
          SizedBox(width: compact ? 8 : 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Peleka',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: nameSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                      TextSpan(
                        text: 'Pro',
                        style: TextStyle(
                          color: AppColors.postmanOrange,
                          fontSize: nameSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showMobile)
                  Text(
                    'Mobile',
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: compact ? 11 : 14,
                      height: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PelekaProMarkPainter extends CustomPainter {
  const _PelekaProMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()..color = AppColors.postmanOrange;
    final darkOrange = Paint()..color = AppColors.postmanOrangeDark;
    final white = Paint()..color = Colors.white;

    final outer = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.25)
      ..lineTo(size.width, size.height * 0.75)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.75)
      ..lineTo(0, size.height * 0.25)
      ..close();
    canvas.drawPath(outer, orange);

    final shade = Path()
      ..moveTo(0, size.height * 0.25)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.75)
      ..close();
    canvas.drawPath(shade, darkOrange);

    final route = Path()
      ..moveTo(size.width * 0.28, size.height * 0.32)
      ..lineTo(size.width * 0.7, size.height * 0.18)
      ..lineTo(size.width * 0.7, size.height * 0.36)
      ..lineTo(size.width * 0.44, size.height * 0.46)
      ..lineTo(size.width * 0.7, size.height * 0.58)
      ..lineTo(size.width * 0.7, size.height * 0.77)
      ..lineTo(size.width * 0.28, size.height * 0.58)
      ..close();
    canvas.drawPath(route, white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
