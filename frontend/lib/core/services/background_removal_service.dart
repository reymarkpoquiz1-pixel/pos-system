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
  /// Multiple spaces to ensure high availability. 
  /// 1.4 is prioritized for stability as 2.0 is often gated.
  static const List<String> _spaceUrls = [
    'https://briaai-bria-rmbg-1-4.hf.space',
    'https://briaai-rmbg-1-4.hf.space', // Mirror
    'https://briaai-bria-rmbg-2-0.hf.space', // Fallback
  ];

  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${imageFile.path}');
    
    // 1. Read bytes and enforce a safe size limit for free AI servers
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 3 * 1024 * 1024) {
      throw BackgroundRemovalException('Image is too large (>3MB). Please use a smaller photo.');
    }
    
    // 2. Prepare Data URI formats
    final base64String = base64Encode(bytes);
    final dataUri = 'data:${imageFile.mimeType ?? "image/png"};base64,$base64String';

    String? lastError;

    // 3. Loop through available spaces
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
          // 4. Try different payload "Styles" for each endpoint
          final List<Map<String, dynamic>> payloads = [
            // Style 1: Modern Gradio 4 with FileData object
            {
              "data": [{"path": dataUri, "meta": {"_type": "gradio.FileData"}}],
              "session_hash": sessionHash,
              "fn_index": 0
            },
            // Style 2: Bria 2.0 specific with api_name
            {
              "data": [{"path": dataUri, "meta": {"_type": "gradio.FileData"}}],
              "api_name": "/png",
              "session_hash": sessionHash
            },
            // Style 3: Raw Base64 string (no prefix) - Some servers prefer this
            {
              "data": [base64String],
              "session_hash": sessionHash,
              "fn_index": 0
            },
            // Style 4: Full Data URI string (Gradio 3 style)
            {
              "data": [dataUri],
              "session_hash": sessionHash,
              "fn_index": 0
            }
          ];

          for (var payload in payloads) {
            debugPrint('Magic Clean: Trying ${baseUrl.split("//")[1]} style...');
            
            final response = await client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 50));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final outputData = data['data'];
              
              if (outputData != null && outputData.isNotEmpty) {
                final result = outputData[0];
                String? imgPath;
                
                if (result is Map) {
                  imgPath = result['path'] ?? result['url'];
                } else if (result is String) {
                  imgPath = result;
                }

                if (imgPath != null && imgPath.isNotEmpty) {
                  // Resolve final download URL
                  String fullUrl = imgPath.startsWith('http') ? imgPath : '$baseUrl/file=$imgPath';
                  if (!imgPath.startsWith('http') && url.contains('gradio_api')) {
                     fullUrl = '$baseUrl/gradio_api/file=$imgPath';
                  }

                  debugPrint('Magic Clean: Downloading result...');
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
              lastError = 'AI server is sleeping. Wait 10s and retry.';
              break; 
            } else if (response.statusCode == 413) {
              lastError = 'Image is too large for the AI server.';
              break;
            } else if (response.statusCode != 404) {
              String detail = '';
              try {
                final body = jsonDecode(response.body);
                detail = ' (${body["message"] ?? body["error"] ?? "unknown error"})';
              } catch (_) {}
              lastError = 'Server error ${response.statusCode}$detail';
            }
          }
        } catch (e) {
          debugPrint('Magic Clean: error at $url: $e');
          lastError = 'Connection failed. Check your internet.';
        } finally {
          client.close();
        }
      }
    }

    throw BackgroundRemovalException('Magic Clean: ${lastError ?? "Server unavailable"}. Please try a smaller image or retry in 10s.');
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
