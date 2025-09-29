import 'package:bizil/screens/home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
        title: Text('My Orders',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
      ),
      body: user == null
          ? _buildEmptyState('Please log in to see your orders.')
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildEmptyState('Could not load your orders.');
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('You have no past orders yet.');
                }

                final orders = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final orderData =
                        orders[index].data() as Map<String, dynamic>;
                    return _buildOrderContainer(context, orderData);
                  },
                );
              },
            ),
    );
  }

  Widget _buildOrderContainer(BuildContext context, Map<String, dynamic> order) {
    final List itemsList = order['items'] ?? [];
    final Timestamp timestamp = order['timestamp'] ?? Timestamp.now();
    final String formattedDate =
        DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                children: [
                  const TextSpan(
                      text: 'From: ',
                      style: TextStyle(fontWeight: FontWeight.normal)),
                  TextSpan(
                    text: order['restaurantName'] ?? 'Restaurant',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          ...itemsList
              .map((item) =>
                  _buildItemDetailCard(item as Map<String, dynamic>))
              .toList(),

          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentMethodChip(order['paymentMethod'] ?? 'N/A'),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${(order['totalAmount'] ?? 0.0).toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetailCard(Map<String, dynamic> item) {
    final String imageUrl = item['imageUrl'] ?? '';
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final double totalItemPrice = price * quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: Image.network(
              imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: Icon(Icons.fastfood, color: Colors.grey[400], size: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['itemName'] ?? 'Item Name',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'x $quantity',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '₹${totalItemPrice.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String paymentMethod) {
    Color color = Colors.grey.shade100;
    Color textColor = Colors.grey.shade800;
    IconData icon;
    String text = paymentMethod;

    switch (paymentMethod.toLowerCase()) {
      case 'card':
        icon = Icons.credit_card;
        text = 'Paid by Card';
        break;
      case 'cash on delivery':
        icon = Icons.money;
        text = 'Cash on Delivery';
        break;
      case 'upi':
        icon = Icons.qr_code;
        text = 'Paid by UPI';
        break;
      default:
        icon = Icons.payment;
        text = 'Paid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20.0)),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
                color: textColor, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}