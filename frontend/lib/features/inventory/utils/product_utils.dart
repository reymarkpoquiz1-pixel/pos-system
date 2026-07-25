import 'package:flutter/material.dart';

class ProductUtils {
  static Color getColorFromName(String name) {
    switch (name.toLowerCase().trim()) {
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'yellow': return Colors.yellow;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      case 'brown': return Colors.brown;
      case 'grey':
      case 'gray': return Colors.grey;
      case 'cyan': return Colors.cyan;
      case 'teal': return Colors.teal;
      case 'indigo': return Colors.indigo;
      case 'amber': return Colors.amber;
      case 'lime': return Colors.lime;
      default: return const Color(0xff607d8b); // Default: BlueGrey
    }
  }

  static String generateBarcode(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomStr = (100 + (DateTime.now().microsecond % 900)).toString();
    return "$prefix-$timestamp-$randomStr";
  }
}
