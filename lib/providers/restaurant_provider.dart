import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItem {
  final String id;
  final String itemName;
  final double price;
  final String imageUrl;
  MenuItem(
      {required this.id,
      required this.itemName,
      required this.price,
      required this.imageUrl});
}

class Restaurant {
  final String id;
  final String name;
  final String cuisine;
  final String imageUrl;
  final double rating;
  final List<MenuItem> menu;
  Restaurant(
      {required this.id,
      required this.name,
      required this.cuisine,
      required this.imageUrl,
      required this.rating,
      required this.menu});
}

class RestaurantProvider with ChangeNotifier {
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;

  List<Restaurant> get restaurants => [..._restaurants];
  bool get isLoading => _isLoading;

  Future<void> fetchRestaurants() async {
    if (_restaurants.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      List<Restaurant> loadedRestaurants = [];
      QuerySnapshot restaurantSnapshot =
          await FirebaseFirestore.instance.collection('restaurants').get();
      for (var restaurantDoc in restaurantSnapshot.docs) {
        var restaurantData = restaurantDoc.data() as Map<String, dynamic>;
        List<MenuItem> menuItems = [];
        QuerySnapshot menuSnapshot =
            await restaurantDoc.reference.collection('menu').get();
        for (var itemDoc in menuSnapshot.docs) {
          var itemData = itemDoc.data() as Map<String, dynamic>;
          menuItems.add(MenuItem(
            id: itemDoc.id,
            itemName: itemData['itemName'] ?? 'No Name',
            price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
            imageUrl: itemData['imageUrl'] ?? '',
          ));
        }
        loadedRestaurants.add(Restaurant(
          id: restaurantDoc.id,
          name: restaurantData['name'] ?? 'Unnamed Restaurant',
          cuisine: restaurantData['cuisine'] ?? 'Unknown',
          imageUrl: restaurantData['imageUrl'] ?? '',
          rating: (restaurantData['rating'] as num?)?.toDouble() ?? 0.0,
          menu: menuItems,
        ));
      }
      _restaurants = loadedRestaurants;
    } catch (e) {
      print("Error fetching restaurants: $e");
    }
    _isLoading = false;
    notifyListeners();
  }
}
