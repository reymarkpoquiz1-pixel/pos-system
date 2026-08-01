import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider getFileImageProvider(String path) {
  return FileImage(File(path));
}

Widget getFileImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.file(File(path), fit: fit);
}
