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
  /// Gagamit tayo ng Stable Gradio 4 Queue API (Hugging Face)
  /// Sinusuportahan nito ang session hashing at SSE events.
  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${imageFile.path}');
    final client = http.Client();
    final sessionHash = _generateSessionHash();
    const spaceUrl = 'https://briaai-bria-rmbg-1-4.hf.space';
    
    try {
      // Step 1: Convert image to Base64 Data URI
      debugPrint('Magic Clean: Converting image to Base64...');
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUri = 'data:${imageFile.mimeType ?? "image/png"};base64,$base64String';

      // Step 2: Call Predict API with Base64 data
      debugPrint('Magic Clean: Calling Predict API (Base64)...');
      final response = await client.post(
        Uri.parse('$spaceUrl/api/predict'),
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
      ).timeout(const Duration(seconds: 60), onTimeout: () {
        throw BackgroundRemovalException('Request timed out (60s). The AI server might be busy.');
      });

      if (response.statusCode != 200) {
        debugPrint('Magic Clean Predict Error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 429) {
          throw BackgroundRemovalException('AI Server is too busy (Rate Limited). Try again later.');
        }
        throw BackgroundRemovalException('Server Error (${response.statusCode}). Please try another image.');
      }

      final data = jsonDecode(response.body);
      debugPrint('Magic Clean: Parsing output...');
      
      if (data != null && data['data'] != null && data['data'].isNotEmpty) {
        final result = data['data'][0];
        String? imgPath;
        
        if (result is Map) {
          imgPath = result['path'] ?? result['url'];
        } else if (result is String) {
          imgPath = result;
        }

        if (imgPath != null) {
          // Gradio 4 dynamic file path handling
          String fullUrl = imgPath.startsWith('http') 
              ? imgPath 
              : '$spaceUrl/file=$imgPath';
          
          debugPrint('Magic Clean: Final Download URL: $fullUrl');
          final imgRes = await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 30));
          if (imgRes.statusCode == 200) {
            final resultBytes = imgRes.bodyBytes;
            if (kIsWeb) {
              return XFile.fromData(resultBytes, name: 'cleaned_${imageFile.name}', mimeType: 'image/png');
            } else {
              final tempDir = await getTemporaryDirectory();
              final fileName = 'cleaned_${DateTime.now().millisecondsSinceEpoch}.png';
              final cleanedFile = io.File('${tempDir.path}/$fileName');
              await cleanedFile.writeAsBytes(resultBytes);
              return XFile(cleanedFile.path);
            }
          } else {
            throw BackgroundRemovalException('Failed to download cleaned image (${imgRes.statusCode})');
          }
        }
      }

      throw BackgroundRemovalException('AI processed the image but returned no result.');
    } on BackgroundRemovalException catch (e) {
      rethrow;
    } catch (e) {
      debugPrint('Magic Clean Exception: $e');
      if (e.toString().contains('XMLHttpRequest error')) {
        throw BackgroundRemovalException('Web Security (CORS) blocked the request. This can happen on some browsers.');
      }
      throw BackgroundRemovalException('An unexpected error occurred: $e');
    } finally {
      client.close();
    }
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}


