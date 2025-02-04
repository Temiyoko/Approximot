import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  // Configuration
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  static String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseStorageBucket => dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseWebClientId => dotenv.env['FIREBASE_WEB_CLIENT_ID'] ?? '';

  // API
  static String get herokuApiUrl => dotenv.env['HEROKU_API_URL'] ?? '';

  // iOS
  static String get iosClientId => dotenv.env['IOS_CLIENT_ID'] ?? '';
  static String get iosBundleId => dotenv.env['IOS_BUNDLE_ID'] ?? '';
  
  // Android
  static String get androidClientId => dotenv.env['ANDROID_CLIENT_ID'] ?? '';
}