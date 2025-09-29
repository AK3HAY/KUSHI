import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDcubx4Tuod4OBN8rhI1u7KhLhAJsj0W1c',
    appId: '1:558595845634:web:208be6d02657ed645b811b',
    messagingSenderId: '558595845634',
    projectId: 'bizil-b81aa',
    authDomain: 'bizil-b81aa.firebaseapp.com',
    storageBucket: 'bizil-b81aa.firebasestorage.app',
    measurementId: 'G-WLGYFGNGYM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA__38tD7MEwzwF4U7GHJV10MdDY8b_VGk',
    appId: '1:558595845634:android:ffcb369e4f9ed0b95b811b',
    messagingSenderId: '558595845634',
    projectId: 'bizil-b81aa',
    storageBucket: 'bizil-b81aa.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDOXPi-WLu52w_dFVvPOVADLVYktmMyoRw',
    appId: '1:558595845634:ios:d55e60795ffafacd5b811b',
    messagingSenderId: '558595845634',
    projectId: 'bizil-b81aa',
    storageBucket: 'bizil-b81aa.firebasestorage.app',
    iosBundleId: 'com.example.bizil',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDOXPi-WLu52w_dFVvPOVADLVYktmMyoRw',
    appId: '1:558595845634:ios:d55e60795ffafacd5b811b',
    messagingSenderId: '558595845634',
    projectId: 'bizil-b81aa',
    storageBucket: 'bizil-b81aa.firebasestorage.app',
    iosBundleId: 'com.example.bizil',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDcubx4Tuod4OBN8rhI1u7KhLhAJsj0W1c',
    appId: '1:558595845634:web:d7a75b5ee4518c6c5b811b',
    messagingSenderId: '558595845634',
    projectId: 'bizil-b81aa',
    authDomain: 'bizil-b81aa.firebaseapp.com',
    storageBucket: 'bizil-b81aa.firebasestorage.app',
    measurementId: 'G-RFZD6GV02N',
  );
}