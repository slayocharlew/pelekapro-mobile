import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/features/tracking/domain/firebase_tracking_credential.dart';

void main() {
  group('FirebaseTrackingCredential', () {
    const deliveryAlias =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const sessionAlias =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    test('parses one scoped credential and refreshes before expiry', () {
      final credential = FirebaseTrackingCredential.fromJson({
        'token': 'short-lived-custom-token',
        'delivery_alias': deliveryAlias,
        'session_alias': sessionAlias,
        'database_path': 'delivery_tracking/$deliveryAlias',
        'expires_at': 1787567400,
      });

      expect(credential.deliveryAlias, deliveryAlias);
      expect(credential.sessionAlias, sessionAlias);
      expect(credential.databasePath, 'delivery_tracking/$deliveryAlias');
      expect(
        credential.needsRefresh(
          DateTime.fromMillisecondsSinceEpoch(1787567000 * 1000, isUtc: true),
        ),
        isFalse,
      );
      expect(
        credential.needsRefresh(
          DateTime.fromMillisecondsSinceEpoch(1787567150 * 1000, isUtc: true),
        ),
        isTrue,
      );
    });

    test('rejects mismatched or unsafe database paths', () {
      expect(
        () => FirebaseTrackingCredential.fromJson({
          'token': 'short-lived-custom-token',
          'delivery_alias': deliveryAlias,
          'session_alias': sessionAlias,
          'database_path': 'delivery_tracking/another-delivery',
          'expires_at': 1787567400,
        }),
        throwsFormatException,
      );
    });

    test('rejects internal identifiers in place of opaque aliases', () {
      expect(
        () => FirebaseTrackingCredential.fromJson({
          'token': 'short-lived-custom-token',
          'delivery_alias': '123',
          'session_alias': '456',
          'database_path': 'delivery_tracking/123',
          'expires_at': 1787567400,
        }),
        throwsFormatException,
      );
    });
  });
}
