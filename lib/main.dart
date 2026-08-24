import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/app.dart';
import 'package:pelekapro_mobile/core/config/firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.androidOptions);
  }

  runApp(const PelekaProApp());
}
