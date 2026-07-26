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
  /// BiRefNet is high quality, RMBG 2.0 is fast.
  static const List<String> _spaceUrls = [
    'https://zhengpeng7-birefnet.hf.space',
    'https://briaai-bria-rmbg-2-0.hf.space',
    'https://briaai-bria-rmbg-1-4.hf.space',
    'https://briaai-rmbg-1-4.hf.space', 
  ];

  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${imageFile.path}');
    
    // 1. Read bytes and enforce a safe size limit for free AI servers
    final bytes = await imageFile.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) {
      throw BackgroundRemovalException('Image is too large (>4MB). Please use a smaller photo.');
    }
    
    // 2. Prepare Data URI formats
    final base64String = base64Encode(bytes);
    final mimeType = imageFile.mimeType ?? "image/png";
    final dataUri = 'data:$mimeType;base64,$base64String';

    String? lastError;

    // 3. Loop through available spaces
    for (var baseUrl in _spaceUrls) {
      final isBiRefNet = baseUrl.contains('birefnet');
      
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
          final List<Map<String, dynamic>> payloads = [];
          
          if (isBiRefNet) {
            // BiRefNet specific payload
            payloads.add({
              "data": [
                {"path": dataUri, "meta": {"_type": "gradio.FileData"}},
                "1024x1024",
                "General"
              ],
              "session_hash": sessionHash,
              "fn_index": 0
            });
          } else {
            // Standard Gradio 4/5 Styles
            payloads.addAll([
              {
                "data": [{"path": dataUri, "meta": {"_type": "gradio.FileData"}}],
                "session_hash": sessionHash,
                "fn_index": 0
              },
              {
                "data": [dataUri],
                "session_hash": sessionHash,
                "fn_index": 0
              }
            ]);
          }

          for (var payload in payloads) {
            debugPrint('Magic Clean: Trying ${baseUrl.split("//")[1]} style...');
            
            final response = await client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 45));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              
              // Handle Gradio 5 "output" field or Gradio 4 "data" field
              final outputData = data['data'] ?? data['output'];
              
              if (outputData != null && outputData is List && outputData.isNotEmpty) {
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
                  if (!imgPath.startsWith('http')) {
                    if (url.contains('gradio_api')) {
                      fullUrl = '$baseUrl/gradio_api/file=$imgPath';
                    } else if (url.contains('/api/predict')) {
                      fullUrl = '$baseUrl/file=$imgPath';
                    }
                  }

                  debugPrint('Magic Clean: Downloading result from $fullUrl');
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
            } else if (response.statusCode == 503 || response.statusCode == 504) {
              lastError = 'Server is busy or sleeping. Trying next...';
              break; 
            } else if (response.statusCode == 413) {
              lastError = 'Image is too large for this server.';
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
          lastError = 'Connection timeout. Trying next...';
        } finally {
          client.close();
        }
      }
    }

    throw BackgroundRemovalException('Magic Clean: ${lastError ?? "Service unavailable"}. Please try a smaller image or retry in 10s.');
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}
