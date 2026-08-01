import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;

class FileHelper {
  static ImageProvider getImageProvider(String path) {
    if (kIsWeb) {
      return NetworkImage(path);
    } else {
      // We use a helper function to avoid direct dart:io usage in code paths that run on web
      return _buildFileImageProvider(path);
    }
  }

  static Widget getFileImage(String path, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) {
      return Image.network(path, fit: fit);
    } else {
      return _buildFileImageWidget(path, fit);
    }
  }

  static ImageProvider _buildFileImageProvider(String path) {
    return FileImage(io.File(path));
  }

  static Widget _buildFileImageWidget(String path, BoxFit fit) {
    return Image.file(io.File(path), fit: fit);
  }
}
