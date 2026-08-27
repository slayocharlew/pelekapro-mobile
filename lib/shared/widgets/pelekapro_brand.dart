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
            child: PelekaProMark(size: markSize),
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

class PelekaProMark extends StatelessWidget {
  const PelekaProMark({required this.size, super.key});

  static const assetName = 'assets/branding/pelekapro_mark_foreground.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: ColoredBox(
        color: AppColors.postmanOrange,
        child: Image.asset(
          assetName,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'PelekaPro',
        ),
      ),
    );
  }
}
