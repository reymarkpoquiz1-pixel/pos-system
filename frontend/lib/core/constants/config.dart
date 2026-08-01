import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// Switch for Local Development vs Live Testing
// Set to 'false' before deploying to Render for the Live Website
const bool isLocal = false;

const String _liveBaseUrl = 'https://pos-system-n6zt.onrender.com';

String get baseUrl {
  if (!isLocal) {
    return _liveBaseUrl;
  }

  // Local Development:
  if (kIsWeb) {
    // If using Flutter Web, point to local NestJS port 3000
    return 'http://localhost:3000';
  }

  // Mobile Development:
  if (!kIsWeb) {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (e) {
      // Fallback
    }
  }

  return 'http://localhost:3000';
}
