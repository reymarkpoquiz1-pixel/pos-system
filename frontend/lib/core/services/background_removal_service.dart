import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io' as io;

class BackgroundRemovalException implements Exception {
  final String message;
  BackgroundRemovalException(this.message);
  @override
  String toString() => message;
}

class BackgroundRemovalService {
  /// We prioritize the stable 1.4 version as 2.0 is currently gated (requires login).
  static const List<String> _spaceUrls = [
    'https://briaai-bria-rmbg-1-4.hf.space',
    'https://briaai-bria-rmbg-2-0.hf.space', // Backup fallback
  ];

  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${imageFile.path}');
    
    // 1. Read bytes and check size
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) {
      throw BackgroundRemovalException('Image is too large (>4MB). Please use a smaller photo.');
    }
    
    // 2. Prepare Data URI
    final base64String = base64Encode(bytes);
    final dataUri = 'data:${imageFile.mimeType ?? "image/png"};base64,$base64String';

    String? lastError;

    // 3. Iterate through available AI spaces
    for (var baseUrl in _spaceUrls) {
      final endpoints = [
        '$baseUrl/gradio_api/api/predict',
        '$baseUrl/api/predict',
        '$baseUrl/run/predict',
      ];

      for (var url in endpoints) {
        final client = http.Client();
        final sessionHash = _generateSessionHash();

        try {
          // Different Gradio versions expect different JSON structures
          final payloads = [
            // Attempt 1: Standard Gradio 4 (FileData) - Most likely for 1.4/2.0
            {
              "data": [
                {"path": dataUri, "meta": {"_type": "gradio.FileData"}}
              ],
              "session_hash": sessionHash,
              "fn_index": 0
            },
            // Attempt 2: Bria 2.0 specialized (with api_name)
            {
              "data": [
                {"path": dataUri, "meta": {"_type": "gradio.FileData"}}
              ],
              "api_name": "/png",
              "session_hash": sessionHash
            },
            // Attempt 3: Gradio 3 (Simple string array)
            {
              "data": [dataUri],
              "session_hash": sessionHash,
              "fn_index": 0
            }
          ];

          for (var payload in payloads) {
            debugPrint('Magic Clean: Trying $url with payload variation...');
            final response = await client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 45));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final outputData = data['data'];
              if (outputData != null && outputData.isNotEmpty) {
                final result = outputData[0];
                String? imgPath = (result is Map) ? (result['path'] ?? result['url']) : result;

                if (imgPath != null) {
                  // Resolve final download URL
                  String fullUrl = imgPath.startsWith('http') ? imgPath : '$baseUrl/file=$imgPath';
                  if (!imgPath.startsWith('http') && url.contains('gradio_api')) {
                     fullUrl = '$baseUrl/gradio_api/file=$imgPath';
                  }

                  debugPrint('Magic Clean: Fetching result from $fullUrl');
                  final imgRes = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 25));
                  
                  if (imgRes.statusCode == 200) {
                    client.close();
                    if (kIsWeb) {
                      return XFile.fromData(imgRes.bodyBytes, name: 'cleaned_${imageFile.name}', mimeType: 'image/png');
                    } else {
                      final tempDir = await getTemporaryDirectory();
                      final file = io.File('${tempDir.path}/cleaned_${DateTime.now().millisecondsSinceEpoch}.png');
                      await file.writeAsBytes(imgRes.bodyBytes);
                      return XFile(file.path);
                    }
                  }
                }
              }
            } else if (response.statusCode == 503) {
              lastError = 'AI Server is sleeping. Please wait 10s and retry.';
              break; // Don't try other payloads on this URL if it's sleeping
            } else if (response.statusCode == 413) {
              lastError = 'Image is too large for the server.';
              break;
            } else if (response.statusCode != 404) {
              lastError = 'Server error (${response.statusCode})';
            }
          }
        } catch (e) {
          debugPrint('Magic Clean error at $url: $e');
          lastError = 'Connection failed. Check your internet.';
        } finally {
          client.close();
        }
      }
    }

    throw BackgroundRemovalException(lastError ?? 'Could not connect to AI. Please try again.');
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
