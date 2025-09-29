

import 'dart:async';
import 'dart:math';

import 'package:bizil/providers/restaurant_provider.dart';
import 'package:bizil/screens/cart_screen.dart';
import 'package:bizil/screens/chat_screen.dart';
import 'package:bizil/screens/orders_screen.dart';
import 'package:bizil/screens/profile_screen.dart';
import 'package:bizil/screens/restaurant_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RestaurantProvider>(context, listen: false)
          .fetchRestaurants();
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {'icon': Icons.local_pizza, 'name': 'Pizza'},
      {'icon': Icons.fastfood, 'name': 'Burgers'},
      {'icon': Icons.ramen_dining, 'name': 'Asian'},
      {'icon': Icons.local_dining, 'name': 'Indian'},
      {'icon': Icons.cake, 'name': 'Desserts'},
      {'icon': Icons.local_bar, 'name': 'Drinks'},
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20.0),
          child: Icon(Icons.location_on_outlined, color: Colors.black54),
        ),
        title: Text(
          'Vidyanagar',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What would you like\nto order?',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSearchBar(_searchController),
                      if (_searchQuery.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 30),
                            _buildSectionTitle('Categories'),
                            const SizedBox(height: 15),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: categories.length,
                                itemBuilder: (context, index) {
                                  return _buildCategoryItem(
                                      context,
                                      categories[index]['icon'],
                                      categories[index]['name']);
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 30),
                      _buildSectionTitle(
                          _searchQuery.isEmpty ? 'Featured Restaurants' : 'Search Results'),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
                Consumer<RestaurantProvider>(
                  builder: (context, restaurantProvider, child) {
                    if (restaurantProvider.isLoading) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final allRestaurants = restaurantProvider.restaurants;
                    final query = _searchQuery.toLowerCase();

                    if (query.isEmpty) {
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildRestaurantCard(context, allRestaurants[index]),
                          childCount: allRestaurants.length,
                        ),
                      );
                    }

                    final restaurantMatches = allRestaurants
                        .where((r) => r.name.toLowerCase().contains(query))
                        .toList();
                    if (restaurantMatches.isNotEmpty) {
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildRestaurantCard(context, restaurantMatches[index]),
                          childCount: restaurantMatches.length,
                        ),
                      );
                    }
                    final List<Map<String, dynamic>> menuItemMatches = [];
                    for (var restaurant in allRestaurants) {
                      for (var item in restaurant.menu) {
                        if (item.itemName.toLowerCase().contains(query)) {
                          menuItemMatches.add(
                              {'item': item, 'restaurant': restaurant});
                        }
                      }
                    }
                    if (menuItemMatches.isNotEmpty) {
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final match = menuItemMatches[index];
                            return _buildMenuItemSearchResultCard(
                                context, match['item'], match['restaurant']);
                          },
                          childCount: menuItemMatches.length,
                        ),
                      );
                    }
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text('No matching restaurants or dishes found.'),
                        ),
                      ),
                    );
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 90.0)),
              ],
            ),
          ),
          const Positioned(
            bottom: 85,
            right: 20,
            child: KushiChatBubble(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildSearchBar(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Find a restaurant or dish',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search, color: Colors.orange),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
  Widget _buildRestaurantCard(BuildContext context, Restaurant restaurant) {
    final restaurantDataMap = {
      'name': restaurant.name,
      'cuisine': restaurant.cuisine,
      'imageUrl': restaurant.imageUrl,
      'rating': restaurant.rating,
      'deliveryTime': '25-30 min',
      'phone': '9876543210',
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantScreen(
              restaurant: restaurantDataMap,
              restaurantId: restaurant.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              child: Image.network(
                restaurant.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.restaurant_menu,
                      color: Colors.grey[400],
                      size: 50,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    restaurant.cuisine,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.rating.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.timer_outlined,
                          color: Colors.grey, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        restaurantDataMap['deliveryTime'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMenuItemSearchResultCard(
      BuildContext context, MenuItem item, Restaurant restaurant) {
    final restaurantDataMap = {
      'name': restaurant.name,
      'cuisine': restaurant.cuisine,
      'imageUrl': restaurant.imageUrl,
      'rating': restaurant.rating,
      'deliveryTime': '25-30 min',
      'phone': '9876543210',
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantScreen(
              restaurant: restaurantDataMap,
              restaurantId: restaurant.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.network(
                item.imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[200],
                  child: Icon(Icons.fastfood, color: Colors.grey[400]),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${restaurant.name}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, IconData icon, String name) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected category: $name'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Icon(icon, color: Colors.orange, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      },
      tooltip: 'Chat with Kushi',
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.deepOrange, Colors.orangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.deepOrangeAccent,
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 1:
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartScreen()));
            break;
          case 2:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OrdersScreen()));
            break;
          case 3:
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()));
            break;
        }
      },
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey[400],
      showUnselectedLabels: false,
      selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Cart',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
class KushiChatBubble extends StatefulWidget {
  const KushiChatBubble({super.key});

  @override
  State<KushiChatBubble> createState() => _KushiChatBubbleState();
}

class _KushiChatBubbleState extends State<KushiChatBubble> {
  Timer? _chatBubbleTimer;
  int _messageIndex = 0;
  bool _isBubbleVisible = false;
  final List<String> _chatMessages = [
    "Feeling hungry?",
    "What are you craving?",
    "Let me help you find a meal!",
    "Tap me for suggestions!",
    "Discover new restaurants!",
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isBubbleVisible = true;
        });
        _chatBubbleTimer =
            Timer.periodic(const Duration(seconds: 5), (timer) {
          _changeMessage();
        });
      }
    });
  }

  void _changeMessage() {
    if (!mounted) return;
    setState(() {
      _isBubbleVisible = false;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          int newIndex;
          do {
            newIndex = Random().nextInt(_chatMessages.length);
          } while (newIndex == _messageIndex);
          _messageIndex = newIndex;
          _isBubbleVisible = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatBubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isBubbleVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _chatMessages[_messageIndex],
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            bottom: -5,
            right: 30,
            child: Transform.rotate(
              angle: pi / 4,
              child: Container(
                width: 12,
                height: 12,
                color: const Color(0xFFFFFBEA),
              ),
            ),
          )
        ],
      ),
    );
  }
}