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
  /// Susubukan natin ang iba't ibang spaces. Inuna natin ang 1.4 dahil mas stable ito at hindi gated.
  static const List<String> _spaceUrls = [
    'https://briaai-bria-rmbg-1-4.hf.space',
    'https://huggingface.co/spaces/briaai/BRIA-RMBG-1.4',
    'https://briaai-bria-rmbg-2-0.hf.space',
  ];

  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${imageFile.path}');
    
    // Convert image to Base64 Data URI
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    final dataUri = 'data:${imageFile.mimeType ?? "image/png"};base64,$base64String';

    String? lastError;

    for (var baseUrl in _spaceUrls) {
      // Susubukan natin ang iba't ibang endpoint patterns
      final endpoints = [
        '$baseUrl/gradio_api/api/predict',
        '$baseUrl/api/predict',
        '$baseUrl/run/predict',
        '$baseUrl/gradio_api/run/predict',
      ];

      for (var url in endpoints) {
        final client = http.Client();
        final sessionHash = _generateSessionHash();
        debugPrint('Magic Clean: Trying endpoint: $url');

        try {
          // Susubukan natin ang iba't ibang payload combinations
          final List<Map<String, dynamic>> payloads = [
            // Attempt 1: Bria 2.0 specialized (with api_name)
            {
              "data": [
                {"path": dataUri, "meta": {"_type": "gradio.FileData"}}
              ],
              "api_name": "/png",
              "session_hash": sessionHash
            },
            // Attempt 2: Bria 1.4/Legacy (Simple FileData)
            {
              "data": [
                {"path": dataUri, "meta": {"_type": "gradio.FileData"}}
              ],
              "fn_index": 0,
              "session_hash": sessionHash
            },
            // Attempt 3: Gradio 3 format (Direct Data URI string)
            {
              "data": [dataUri],
              "fn_index": 0,
              "session_hash": sessionHash
            },
          ];

          for (var payload in payloads) {
            debugPrint('Magic Clean: Sending payload to $url (api_name: ${payload['api_name']})');
            final response = await client.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 45));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              debugPrint('Magic Clean: Success from $url');
              
              final outputData = data['data'];
              if (outputData != null && outputData.isNotEmpty) {
                final result = outputData[0];
                String? imgPath;
                
                if (result is Map) {
                  imgPath = result['path'] ?? result['url'];
                } else if (result is String) {
                  imgPath = result;
                }

                if (imgPath != null) {
                  String fullUrl = imgPath.startsWith('http') ? imgPath : '$baseUrl/file=$imgPath';
                  
                  // Handle different file serving paths
                  if (!imgPath.startsWith('http')) {
                    if (url.contains('gradio_api')) {
                       fullUrl = '$baseUrl/gradio_api/file=$imgPath';
                    } else {
                       fullUrl = '$baseUrl/file=$imgPath';
                    }
                  }

                  debugPrint('Magic Clean: Fetching result from $fullUrl');
                  final imgRes = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 25));
                  
                  if (imgRes.statusCode == 200) {
                    final resultBytes = imgRes.bodyBytes;
                    client.close();
                    if (kIsWeb) {
                      return XFile.fromData(resultBytes, name: 'cleaned_${imageFile.name}', mimeType: 'image/png');
                    } else {
                      final tempDir = await getTemporaryDirectory();
                      final fileName = 'cleaned_${DateTime.now().millisecondsSinceEpoch}.png';
                      final cleanedFile = io.File('${tempDir.path}/$fileName');
                      await cleanedFile.writeAsBytes(resultBytes);
                      return XFile(cleanedFile.path);
                    }
                  }
                }
              }
            } else if (response.statusCode != 404) {
               debugPrint('Magic Clean: $url returned ${response.statusCode}');
               String errorBody = '';
               try {
                 final body = jsonDecode(response.body);
                 errorBody = ' (${body["message"] ?? body["error"] ?? ""})';
               } catch (_) {}
               lastError = 'Server error ${response.statusCode}$errorBody from $url';
            } else {
               debugPrint('Magic Clean: $url returned 404');
               lastError = 'Endpoint not found (404) at $url';
               break; // Wag na i-loop ang payloads kung 404 ang URL
            }
          }
        } catch (e) {
          debugPrint('Magic Clean: Error calling $url: $e');
          lastError = 'Connection failed: $e';
        } finally {
          client.close();
        }
      }
    }

    throw BackgroundRemovalException('Magic Clean Error: ${lastError ?? "Server returned 404"}. Please ensure the AI spaces are online.');
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}


