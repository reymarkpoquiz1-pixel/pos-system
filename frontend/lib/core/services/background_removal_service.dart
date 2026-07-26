import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:image_picker/image_picker.dart';

class BackgroundRemovalService {
  /// Gagamit tayo ng Stable Gradio 4 Queue API (Hugging Face)
  /// Sinusuportahan nito ang session hashing at SSE events.
  static Future<XFile?> removeBackground(XFile imageFile) async {
    debugPrint('Magic Clean: Starting background removal for ${kIsWeb ? "Web" : "Mobile"}');
    final client = http.Client();
    final sessionHash = _generateSessionHash();
    const spaceUrl = 'https://briaai-bria-rmbg-1-4.hf.space';

    try {
      // Step 1: Upload image to Gradio server first (Required for Gradio 4)
      debugPrint('Magic Clean: Uploading image to HF Space...');
      final uploadRes = await _uploadFile(client, imageFile, spaceUrl);
      if (uploadRes == null) {
        debugPrint('Magic Clean: Upload failed.');
        return null;
      }
      debugPrint('Magic Clean: Upload successful: $uploadRes');

      // Step 2: Join the Queue using FileData object
      debugPrint('Magic Clean: Joining queue...');
      final joinRes = await client.post(
        Uri.parse('$spaceUrl/queue/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "data": [
            {
              "path": uploadRes,
              "meta": {"_type": "gradio.FileData"}
            }
          ],
          "event_data": null,
          "fn_index": 0,
          "session_hash": sessionHash
        }),
      );

      if (joinRes.statusCode != 200) {
        debugPrint('Magic Clean Queue Join Error: ${joinRes.body}');
        return null;
      }

      final eventId = jsonDecode(joinRes.body)['event_id'];
      debugPrint('Magic Clean: Event ID: $eventId');

      // Step 3: Listen for Data via SSE
      final dataUrl = Uri.parse('$spaceUrl/queue/data?session_hash=$sessionHash');
      final streamRequest = http.Request('GET', dataUrl);
      final streamedResponse = await client.send(streamRequest);

      await for (var line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        debugPrint('Magic Clean Server Message: $line');

        if (line.startsWith('data: ')) {
          final dataJson = line.substring(6);
          if (dataJson.isEmpty) continue;

          try {
            final event = jsonDecode(dataJson);
            final msg = event['msg'];

            if (msg == 'process_completed') {
              debugPrint('Magic Clean: Process Completed! Parsing output...');
              final output = event['output'];
              if (output != null && output['data'] != null && output['data'].isNotEmpty) {
                final result = output['data'][0];
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
                    return await _createXFile(imgRes.bodyBytes);
                  } else {
                    debugPrint('Magic Clean: Download failed with status ${imgRes.statusCode}');
                  }
                } else {
                  debugPrint('Magic Clean: Could not find image path in output data.');
                }
              }
              break;
            } else if (msg == 'send_data') {
              debugPrint('Magic Clean: Server is processing...');
            } else if (msg == 'process_starts') {
              debugPrint('Magic Clean: AI started working...');
            } else if (msg == 'queue_full' || msg == 'process_error') {
              debugPrint('Magic Clean Server Error: $msg');
              return null;
            }
          } catch (e) {
            // Ignore keep-alive or malformed messages
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
      
      // Use bytes instead of path for Web compatibility
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

  static Future<XFile> _createXFile(Uint8List bytes) async {
    final fileName = 'cleaned_${DateTime.now().millisecondsSinceEpoch}.png';
    
    if (kIsWeb) {
      // For Web, create XFile directly from bytes
      return XFile.fromData(bytes, name: fileName, mimeType: 'image/png');
    } else {
      // For Mobile/Desktop, save to temp file first
      final tempDir = await getTemporaryDirectory();
      final cleanedFile = io.File('${tempDir.path}/$fileName');
      await cleanedFile.writeAsBytes(bytes);
      debugPrint('Magic Clean: Success! Saved at ${cleanedFile.path}');
      return XFile(cleanedFile.path);
    }
  }
}
