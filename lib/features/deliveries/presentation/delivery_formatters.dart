import 'package:flutter/material.dart';

String formatTzs(double amount) {
  final hasFraction = amount != amount.truncateToDouble();
  final raw = hasFraction
      ? amount.toStringAsFixed(2)
      : amount.toStringAsFixed(0);
  final parts = raw.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  if (parts.length == 2) {
    buffer.write('.${parts.last}');
  }
  return 'TZS $buffer';
}

String formatDeliveryTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return 'Time unavailable';
  }

  final local = value.toLocal();
  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  final now = DateTime.now();
  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  return isToday ? time : '${local.day} ${_shortMonth(local.month)} • $time';
}

String _shortMonth(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
