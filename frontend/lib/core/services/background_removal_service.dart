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
    
    // Convert image to Base64 Data URI once
    final bytes = await imageFile.readAsBytes();
    final base64String = base64Encode(bytes);
    final dataUri = 'data:${imageFile.mimeType ?? "image/png"};base64,$base64String';

    String? lastError;

    for (var baseUrl in _spaceUrls) {
      // Susubukan natin ang iba't ibang endpoint patterns para sa Gradio 3 at 4
      final endpoints = [
        '$baseUrl/gradio_api/run/predict',
        '$baseUrl/gradio_api/api/predict',
        '$baseUrl/run/predict',
        '$baseUrl/api/predict',
      ];

      for (var url in endpoints) {
        final client = http.Client();
        final sessionHash = _generateSessionHash();
        debugPrint('Magic Clean: Trying endpoint: $url');

        try {
          final response = await client.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              "data": [
                {
                  "path": dataUri,
                  "meta": {"_type": "gradio.FileData"}
                }
              ],
              "fn_index": 0,
              "session_hash": sessionHash
            }),
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
                String fullUrl = imgPath.startsWith('http') ? imgPath : '$baseUrl/file=$imgPath';
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
          } else {
            debugPrint('Magic Clean: $url returned ${response.statusCode}');
            lastError = 'Server returned ${response.statusCode}';
          }
        } catch (e) {
          debugPrint('Magic Clean: Error calling $url: $e');
          lastError = e.toString();
        } finally {
          client.close();
        }
      }
    }

    throw BackgroundRemovalException(lastError ?? 'Could not connect to any AI server. Please try again later.');
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}


