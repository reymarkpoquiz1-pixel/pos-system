import 'package:flutter/material.dart';

ImageProvider getFileImageProvider(String path) {
  throw UnsupportedError('Cannot create a file image provider without dart:html or dart:io.');
}

Widget getFileImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
  throw UnsupportedError('Cannot create a file image widget without dart:html or dart:io.');
}
