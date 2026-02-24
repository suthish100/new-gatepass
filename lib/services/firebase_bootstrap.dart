import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  static bool _isReady = false;
  static String? _lastError;

  static bool get isReady => _isReady;
  static String? get lastError => _lastError;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isReady = true;
      _lastError = null;
    } catch (error) {
      // App can run with the in-memory fallback if Firebase is not configured.
      _isReady = false;
      _lastError = error.toString();
      debugPrint('Firebase initialization failed: $error');
    }
  }
}
