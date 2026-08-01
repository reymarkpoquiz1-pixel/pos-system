import 'package:flutter/material.dart';

ImageProvider getFileImageProvider(String path) {
  return NetworkImage(path);
}

Widget getFileImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
  return Image.network(path, fit: fit);
}
