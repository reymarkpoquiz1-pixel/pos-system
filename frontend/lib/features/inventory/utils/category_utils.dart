import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData getIconForName(String? name) {
    if (name == null) return Icons.category_outlined;
    final lowerName = name.toLowerCase();
    
    if (lowerName.contains('backpack') || lowerName.contains('knapsack')) {
      return Icons.backpack_outlined;
    } else if (lowerName.contains('bag') || lowerName.contains('pouch') || lowerName.contains('crossbody') || lowerName.contains('wallet') || lowerName.contains('handbag')) {
      return Icons.shopping_bag_outlined;
    } else if (lowerName.contains('shoe') || lowerName.contains('sneaker') || lowerName.contains('footwear') || lowerName.contains('heels') || lowerName.contains('sandals') || lowerName.contains('slippers')) {
      return Icons.straighten_outlined; // Closest to shoe box/measurement or use sports_sneakers if available
    } else if (lowerName.contains('polo') || lowerName.contains('shirt') || lowerName.contains('t-shirt') || lowerName.contains('top')) {
      return Icons.checkroom_outlined; 
    } else if (lowerName.contains('dress') || lowerName.contains('gown') || lowerName.contains('skirt')) {
      return Icons.checkroom_outlined;
    } else if (lowerName.contains('pants') || lowerName.contains('jeans') || lowerName.contains('short') || lowerName.contains('trouser')) {
      return Icons.architecture_outlined; // Looks like folded pants
    } else if (lowerName.contains('cloth') || lowerName.contains('apparel') || lowerName.contains('garment')) {
      return Icons.dry_cleaning_outlined;
    } else if (lowerName.contains('phone') || lowerName.contains('laptop') || lowerName.contains('device') || lowerName.contains('gadget') || lowerName.contains('electronic')) {
      return Icons.devices_outlined;
    } else if (lowerName.contains('food') || lowerName.contains('snack') || lowerName.contains('restaurant') || lowerName.contains('eat')) {
      return Icons.restaurant_outlined;
    } else if (lowerName.contains('drink') || lowerName.contains('coffee') || lowerName.contains('cafe') || lowerName.contains('beverage') || lowerName.contains('milk tea')) {
      return Icons.local_cafe_outlined;
    } else if (lowerName.contains('watch') || lowerName.contains('jewelry') || lowerName.contains('accessory') || lowerName.contains('belt') || lowerName.contains('hat')) {
      return Icons.watch_outlined;
    } else if (lowerName.contains('beauty') || lowerName.contains('makeup') || lowerName.contains('cosmetic') || lowerName.contains('skincare')) {
      return Icons.face_retouching_natural_outlined;
    }

    return Icons.category_outlined;
  }

  static String findNameById(List<dynamic> categories, dynamic id) {
    if (id == null) return 'Select Category';
    for (var cat in categories) {
      if (cat['id'].toString() == id.toString()) return cat['name'] ?? 'Select Category';
      if (cat['sub_categories'] != null) {
        final found = findNameById(cat['sub_categories'], id);
        if (found != 'Select Category') return found;
      }
    }
    return 'Select Category';
  }

  static List<dynamic> flattenCategories(List<dynamic> categories) {
    List<dynamic> flat = [];
    for (var cat in categories) {
      flat.add(cat);
      if (cat['sub_categories'] != null && cat['sub_categories'] is List) {
        flat.addAll(flattenCategories(cat['sub_categories']));
      }
    }
    return flat;
  }

  static String formatDateOnly(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  static String formatLogDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      DateTime dt = DateTime.parse(dateTimeStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      String hour = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString();
      String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${hour.padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (e) {
      return dateTimeStr;
    }
  }

  static Color getLogColor(String? action) {
    final act = action?.toLowerCase() ?? '';
    if (act.contains('update')) return const Color(0xFFF39C12);
    if (act.contains('add')) return const Color(0xFF4CAF50);
    if (act.contains('delete')) return Colors.redAccent;
    if (act.contains('restore')) return Colors.blueAccent;
    return Colors.grey;
  }

  static IconData getLogIcon(String? action) {
    final act = action?.toLowerCase() ?? '';
    if (act.contains('update')) return Icons.edit_note_outlined;
    if (act.contains('add')) return Icons.add_circle_outline;
    if (act.contains('delete')) return Icons.delete_outline;
    if (act.contains('restore')) return Icons.sync;
    return Icons.history;
  }

  static Widget buildStatusBadge(String? status) {
    final s = status ?? 'Active';
    final isActive = s.toLowerCase() == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}
