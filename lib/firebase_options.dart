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
    apiKey: 'AIzaSyANipt0iI3QD7XaabF2yEeoEGeS0pi7dNo',
    appId: '1:831871600625:web:4f988246402794e2482650',
    messagingSenderId: '831871600625',
    projectId: 'doroti-fe',
    authDomain: 'doroti-fe.firebaseapp.com',
    storageBucket: 'doroti-fe.firebasestorage.app',
    measurementId: 'G-8PY378XQRX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAn_HH02BKcBhPyuKhW7BKUJD_zou32vIQ',
    appId: '1:831871600625:android:2b9293021d5641e8482650',
    messagingSenderId: '831871600625',
    projectId: 'doroti-fe',
    storageBucket: 'doroti-fe.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyArKpHw9FY9hfnQj7hVeLWOUR5Nj_b7OTA',
    appId: '1:831871600625:ios:56e3bcb949bd74b2482650',
    messagingSenderId: '831871600625',
    projectId: 'doroti-fe',
    storageBucket: 'doroti-fe.firebasestorage.app',
    iosBundleId: 'com.example.appAppTest',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyArKpHw9FY9hfnQj7hVeLWOUR5Nj_b7OTA',
    appId: '1:831871600625:ios:56e3bcb949bd74b2482650',
    messagingSenderId: '831871600625',
    projectId: 'doroti-fe',
    storageBucket: 'doroti-fe.firebasestorage.app',
    iosBundleId: 'com.example.appAppTest',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyANipt0iI3QD7XaabF2yEeoEGeS0pi7dNo',
    appId: '1:831871600625:web:9f460109236eb8c8482650',
    messagingSenderId: '831871600625',
    projectId: 'doroti-fe',
    authDomain: 'doroti-fe.firebaseapp.com',
    storageBucket: 'doroti-fe.firebasestorage.app',
    measurementId: 'G-FCH68FVM5S',
  );
}
