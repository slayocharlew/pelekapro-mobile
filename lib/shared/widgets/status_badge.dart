import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (background, foreground) = switch (normalized) {
      'on_the_way' || 'arrived' => (AppColors.infoSoft, AppColors.info),
      'delivered' => (AppColors.successSoft, AppColors.success),
      'failed' => (AppColors.errorSoft, AppColors.error),
      'cancelled' => (const Color(0xFFF0F1F2), AppColors.mutedInk),
      _ => (AppColors.postmanOrangeSoft, AppColors.postmanOrangeDark),
    };

    return Semantics(
      label: 'Status ${_readable(normalized)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          _readable(normalized),
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _readable(String value) {
    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
