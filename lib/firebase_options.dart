import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAR_ilDZbo9hPR0JJ2Wtal555N8VVWvqEQ',
    authDomain: 'aksab-erp.firebaseapp.com',
    databaseURL: 'https://aksab-erp-default-rtdb.firebaseio.com',
    projectId: 'aksab-erp',
    storageBucket: 'aksab-erp.firebasestorage.app',
    messagingSenderId: '549455573441',
    appId: '1:549455573441:web:a198bb1adb5f3b35c4ff40',
    measurementId: 'G-7GGD70EHNC',
  );
}

