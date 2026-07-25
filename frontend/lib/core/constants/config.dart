import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// Switch para sa Local Development vs Live Testing
// I-set sa 'false' bago i-deploy sa Render para sa Live Website
const bool isLocal = false; 

const String _liveBaseUrl = 'https://pos-system-9ucq.onrender.com';

String get baseUrl {
  if (!isLocal) {
    return _liveBaseUrl;
  }

  // Local Development:
  if (kIsWeb) {
    // Kung Flutter Web ang gamit, ituro sa local NestJS port 3000
    return 'http://localhost:3000';
  }

  // Mobile Development:
  try {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
  } catch (e) {
    // Fallback
  }
  
  return 'http://localhost:3000';
}
