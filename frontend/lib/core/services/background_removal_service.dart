import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io' as io;

class BackgroundRemovalService {
  /// Gagamit tayo ng Stable Gradio 4 Queue API (Hugging Face)
  /// Sinusuportahan nito ang session hashing at SSE events.
  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${imageFile.path}');
    final client = http.Client();
    final sessionHash = _generateSessionHash();
    const spaceUrl = 'https://briaai-bria-rmbg-1-4.hf.space';
    
    try {
      // Step 1: Upload image to Gradio server
      debugPrint('Magic Clean: Uploading image to HF Space...');
      final uploadRes = await _uploadFile(client, imageFile, spaceUrl);
      if (uploadRes == null) {
        debugPrint('Magic Clean: Upload failed.');
        return null;
      }
      debugPrint('Magic Clean: Upload successful: $uploadRes');

      // Step 2: Call Predict API (Synchronous is better for Web than SSE)
      debugPrint('Magic Clean: Calling Predict API...');
      final response = await client.post(
        Uri.parse('$spaceUrl/api/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "data": [
            {
              "path": uploadRes,
              "meta": {"_type": "gradio.FileData"}
            }
          ],
          "fn_index": 0,
          "session_hash": sessionHash
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('Magic Clean Predict Error: ${response.statusCode} - ${response.body}');
        return null;
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
          final imgRes = await http.get(Uri.parse(fullUrl));
          if (imgRes.statusCode == 200) {
            final bytes = imgRes.bodyBytes;
            if (kIsWeb) {
              return XFile.fromData(bytes, name: 'cleaned_${imageFile.name}', mimeType: 'image/png');
            } else {
              final tempDir = await getTemporaryDirectory();
              final fileName = 'cleaned_${DateTime.now().millisecondsSinceEpoch}.png';
              final cleanedFile = io.File('${tempDir.path}/$fileName');
              await cleanedFile.writeAsBytes(bytes);
              return XFile(cleanedFile.path);
            }
          } else {
            debugPrint('Magic Clean: Download failed with status ${imgRes.statusCode}');
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Magic Clean Exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Helper to upload file to Gradio /upload endpoint
  static Future<String?> _uploadFile(http.Client client, XFile file, String spaceUrl) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$spaceUrl/upload'));
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'files', 
        bytes,
        filename: file.name,
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final List<dynamic> paths = jsonDecode(response.body);
        if (paths.isNotEmpty) {
          return paths[0].toString();
        }
      }
      debugPrint('Magic Clean Upload Error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('Magic Clean Upload Exception: $e');
    }
    return null;
  }

  static String _generateSessionHash() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(11, (index) => chars[random.nextInt(chars.length)]).join();
  }
}


