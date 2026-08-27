abstract final class FirebaseTimestampFormatter {
  static String eastAfricaIso8601(DateTime value) {
    final local = value.toUtc().add(const Duration(hours: 3));
    final withoutUtcSuffix = local.toIso8601String().replaceFirst(
      RegExp(r'Z$'),
      '',
    );

    return '$withoutUtcSuffix+03:00';
  }
}
