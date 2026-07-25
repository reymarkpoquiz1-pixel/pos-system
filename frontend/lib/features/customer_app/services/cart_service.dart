import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final Map<String, dynamic>? selectedVariant;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.selectedVariant,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'imageUrl': imageUrl,
    'selectedVariant': selectedVariant,
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'],
    name: json['name'],
    price: (json['price'] as num).toDouble(),
    imageUrl: json['imageUrl'],
    selectedVariant: json['selectedVariant'],
    quantity: json['quantity'],
  );
}

class CartService extends ChangeNotifier {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    _loadCart();
  }

  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.length;

  double get totalAmount {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(_items.map((item) => item.toJson()).toList());
    await prefs.setString('shopping_cart', encodedData);
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('shopping_cart');
    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      _items.clear();
      _items.addAll(decodedData.map((item) => CartItem.fromJson(item)).toList());
      notifyListeners();
    }
  }

  void addToCart(CartItem newItem) {
    // Check if item with same ID and same variant already exists
    int existingIndex = _items.indexWhere((item) => 
      item.id == newItem.id && 
      _isSameVariant(item.selectedVariant, newItem.selectedVariant)
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(int index) {
    _items.removeAt(index);
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      _items[index].quantity = newQuantity;
      _saveCart();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  bool _isSameVariant(Map<String, dynamic>? v1, Map<String, dynamic>? v2) {
    if (v1 == null && v2 == null) return true;
    if (v1 == null || v2 == null) return false;
    // Simple comparison of color_name and size
    return v1['color_name'] == v2['color_name'] && v1['size'] == v2['size'];
  }
}
