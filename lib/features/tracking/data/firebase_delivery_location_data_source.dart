import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_location_sample.dart';
import 'package:pelekapro_mobile/features/tracking/domain/firebase_tracking_credential.dart';
import 'package:pelekapro_mobile/features/tracking/domain/firebase_timestamp_formatter.dart';

class FirebaseDeliveryLocationDataSource {
  FirebaseDeliveryLocationDataSource({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  Future<void> authenticate(FirebaseTrackingCredential credential) async {
    await _auth.signInWithCustomToken(credential.token);
  }

  Future<void> submit(
    FirebaseTrackingCredential credential,
    DeliveryLocationSample sample,
  ) async {
    final recordedAt = sample.recordedAt.toUtc();
    final sampleId = _sampleId(sample, recordedAt);
    final sequence = recordedAt.microsecondsSinceEpoch;
    final point = <String, Object>{
      'sample_id': sampleId,
      'sequence': sequence,
      'latitude': sample.latitude,
      'longitude': sample.longitude,
      if (sample.accuracy != null) 'accuracy': sample.accuracy!,
      if (sample.speed != null) 'speed': sample.speed!,
      if (sample.heading != null) 'heading': sample.heading!,
      'recorded_at': FirebaseTimestampFormatter.eastAfricaIso8601(recordedAt),
      'recorded_at_ms': recordedAt.millisecondsSinceEpoch,
      'received_at_ms': ServerValue.timestamp,
    };
    final root = _database.ref(credential.databasePath);

    await root.child('live').runTransaction((current) {
      final existing = current is Map
          ? Map<Object?, Object?>.from(current)
          : const <Object?, Object?>{};
      final existingTime = _integer(existing['recorded_at_ms']) ?? -1;
      final existingSequence = _integer(existing['sequence']) ?? -1;
      final incomingTime = recordedAt.millisecondsSinceEpoch;

      if (incomingTime < existingTime ||
          (incomingTime == existingTime && sequence <= existingSequence)) {
        return Transaction.abort();
      }

      return Transaction.success(point);
    }, applyLocally: false);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _sampleId(DeliveryLocationSample sample, DateTime recordedAt) {
    final timestamp = recordedAt.microsecondsSinceEpoch.toRadixString(36);
    final latitude = ((sample.latitude + 90) * 10000000).round().toRadixString(
      36,
    );
    final longitude = ((sample.longitude + 180) * 10000000)
        .round()
        .toRadixString(36);

    return 'gps_${timestamp}_${latitude}_$longitude';
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite) return value.toInt();
    return null;
  }
}
