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
  /// Susubukan natin ang iba't ibang spaces kung sakaling down ang isa.
  static const List<String> _spaceUrls = [
    'https://briaai-bria-rmbg-1-4.hf.space',
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
      // Idinagdag ang /png dahil ito ang kailangan ng Bria 2.0
      final endpoints = [
        '$baseUrl/api/png',
        '$baseUrl/gradio_api/api/png',
        '$baseUrl/api/predict',
        '$baseUrl/gradio_api/api/predict',
        '$baseUrl/run/predict',
        '$baseUrl/gradio_api/run/predict',
      ];

      for (var url in endpoints) {
        final client = http.Client();
        final sessionHash = _generateSessionHash();
        debugPrint('Magic Clean: Trying endpoint: $url');

        try {
          // Susubukan muna ang FileData format (Standard Gradio 4)
          final payload1 = {
            "data": [
              {
                "path": dataUri,
                "meta": {"_type": "gradio.FileData"}
              }
            ],
            "fn_index": 0,
            "session_hash": sessionHash
          };

          // At ang Simple String format (Standard Gradio 3)
          final payload2 = {
            "data": [dataUri],
            "fn_index": 0,
            "session_hash": sessionHash
          };

          for (var payload in [payload1, payload2]) {
            debugPrint('Magic Clean: Sending payload to $url');
            final response = await client.post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 40));

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
                  // Minsan ang path ay relative lang sa base URL
                  String fullUrl = imgPath.startsWith('http') ? imgPath : '$baseUrl/file=$imgPath';
                  
                  // May mga spaces na gumagamit ng ibang format para sa file access
                  if (!imgPath.startsWith('http') && !url.contains('gradio_api')) {
                     fullUrl = '$baseUrl/file=$imgPath';
                  } else if (!imgPath.startsWith('http')) {
                     fullUrl = '$baseUrl/gradio_api/file=$imgPath';
                  }

                  final imgRes = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 20));
                  
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
               // Kung hindi 404, ibig sabihin nahanap ang server pero may payload error (422, 500, etc)
               // Subukan naman ang susunod na payload format.
               debugPrint('Magic Clean: $url returned ${response.statusCode}');
               
               String errorDetail = '';
               try {
                 final errorData = jsonDecode(response.body);
                 errorDetail = ' - ${errorData["message"] ?? errorData["error"] ?? ""}';
               } catch (_) {}
               
               lastError = 'Server error (${response.statusCode})$errorDetail from $url';
            } else {
               debugPrint('Magic Clean: $url returned 404');
               lastError = 'Endpoint not found (404) at $url';
               break; // Wag na ituloy ang payload 2 kung 404 naman ang URL
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


