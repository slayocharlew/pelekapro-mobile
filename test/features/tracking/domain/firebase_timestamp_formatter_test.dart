import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/tracking/domain/firebase_timestamp_formatter.dart';

void main() {
  test('formats the same instant with the East Africa offset', () {
    expect(
      FirebaseTimestampFormatter.eastAfricaIso8601(
        DateTime.parse('2026-08-26T12:30:45.123Z'),
      ),
      '2026-08-26T15:30:45.123+03:00',
    );
  });
}
