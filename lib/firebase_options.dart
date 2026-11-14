import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPiyQism06H7XgxMTfEriq9MdcbmU7bdQ',
    appId: '1:636556953188:android:606ffbfd60680416460171',
    messagingSenderId: '636556953188',
    projectId: 'tontine-ci-44b0f',
    storageBucket: 'tontine-ci-44b0f.firebasestorage.app',
  );
}