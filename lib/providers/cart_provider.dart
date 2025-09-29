import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImageUrl,
    this.quantity = 1,
  });
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  double get subtotal => _items.values
      .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  double get deliveryFee => 50.00;
  double get totalPrice => subtotal + deliveryFee;

  void addItem(
    String productId,
    String name,
    double price,
    String imageUrl,
    String restaurantId,
    String restaurantName,
    String restaurantImageUrl,
  ) {
    if (_items.isNotEmpty && _items.values.first.restaurantId != restaurantId) {
      clearCart();
    }

    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existing) => CartItem(
            id: existing.id,
            name: existing.name,
            price: existing.price,
            imageUrl: existing.imageUrl,
            restaurantId: existing.restaurantId,
            restaurantName: existing.restaurantName,
            restaurantImageUrl: existing.restaurantImageUrl,
            quantity: existing.quantity + 1),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(
          id: productId,
          name: name,
          price: price,
          imageUrl: imageUrl,
          restaurantId: restaurantId,
          restaurantName: restaurantName,
          restaurantImageUrl: restaurantImageUrl,
          quantity: 1,
        ),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(
          productId,
          (existing) => CartItem(
              id: existing.id,
              name: existing.name,
              price: existing.price,
              imageUrl: existing.imageUrl,
              restaurantId: existing.restaurantId,
              restaurantName: existing.restaurantName,
              restaurantImageUrl: existing.restaurantImageUrl,
              quantity: existing.quantity - 1));
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void clearCart() {
    _items = {};
    notifyListeners();
  }
}
