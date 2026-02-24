import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  static bool _isReady = false;

  static bool get isReady => _isReady;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _isReady = true;
    } catch (_) {
      // App can run with the in-memory fallback if Firebase is not configured.
      _isReady = false;
    }
  }
}
