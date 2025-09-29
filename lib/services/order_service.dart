import 'package:bizil/providers/cart_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> placeOrder({
    required CartProvider cart,
    required String paymentMethod,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not logged in.");
    }
    if (cart.items.isEmpty) {
      throw Exception("Cannot place an order with an empty cart.");
    }

    final firstItem = cart.items.values.first;

    final itemsList = cart.items.values.map((item) => {
      'productId': item.id,
      'itemName': item.name,
      'price': item.price,
      'quantity': item.quantity,
      'imageUrl': item.imageUrl,
    }).toList();

    await _firestore.collection('orders').add({
      'userId': user.uid,
      'restaurantId': firstItem.restaurantId,
      'restaurantName': firstItem.restaurantName,
      'restaurantImageUrl': firstItem.restaurantImageUrl,
      'items': itemsList,
      'totalAmount': cart.totalPrice,
      'subtotal': cart.subtotal,
      'deliveryFee': cart.deliveryFee,
      'paymentMethod': paymentMethod,
      'status': 'Processing',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}