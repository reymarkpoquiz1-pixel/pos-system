import 'package:flutter/foundation.dart' show kIsWeb;

// Switch para sa Local Development vs Live Testing
const bool isLocal = true; 

const String _localBaseUrl = 'http://10.0.2.2:3000'; // Gamitin ang IP na ito para sa Android Emulator
const String _liveBaseUrl = 'https://pos-system-u53n.onrender.com';

String get baseUrl {
  if (kIsWeb) {
    return Uri.base.origin;
  }
  return isLocal ? _localBaseUrl : _liveBaseUrl;
}
