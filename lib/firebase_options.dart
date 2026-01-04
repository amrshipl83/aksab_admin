import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAA2JbmtD52JMCz483glEV8eX1ZDeK0fZE',
    authDomain: 'aksabeg-b6571.firebaseapp.com',
    projectId: 'aksabeg-b6571',
    storageBucket: 'aksabeg-b6571.appspot.com',
    messagingSenderId: '32660558108',
    appId: '1:32660558108:web:102632793b65058953ead9',
  );
}

