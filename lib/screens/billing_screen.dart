import 'package:bizil/providers/cart_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'order_success_screen.dart';

enum PaymentMethod { cash, card, upi }

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  PaymentMethod _selectedPaymentMethod = PaymentMethod.upi;
  String _address = '123, Palm Jumeirah, Dubai, UAE';
  bool _isProcessing = false;

  final _addressController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _upiIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressController.text = _address;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(CartProvider cart) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cannot place order. Cart is empty or you are not logged in.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    String paymentMethodString;
    switch (_selectedPaymentMethod) {
      case PaymentMethod.cash:
        paymentMethodString = 'Cash on Delivery';
        break;
      case PaymentMethod.card:
        paymentMethodString = 'Card';
        break;
      case PaymentMethod.upi:
        paymentMethodString = 'UPI';
        break;
    }

    try {
      final firstItem = cart.items.values.first;
      final orderItems = cart.items.values.map((cartItem) {
        return {
          'itemName': cartItem.name,
          'quantity': cartItem.quantity,
          'price': cartItem.price,
          'imageUrl': cartItem.imageUrl,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'orderId': 'ORD${DateTime.now().millisecondsSinceEpoch}',
        'restaurantName': firstItem.restaurantName,
        'restaurantImageUrl': firstItem.restaurantImageUrl,
        'items': orderItems,
        'totalAmount': cart.totalPrice,
        'status': 'Processing',
        'deliveryAddress': _address,
        'paymentMethod': paymentMethodString,
        'timestamp': FieldValue.serverTimestamp(),
      });

      cart.clearCart();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OrderSuccessScreen()),
          (Route<dynamic> route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not place order. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showEditAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Address',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Full Address',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _address = _addressController.text;
                });
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('SAVE ADDRESS',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) => Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text('Checkout',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Delivery Address'),
              _buildAddressCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('Payment Method'),
              _buildPaymentOptions(),
              const SizedBox(height: 24),
              _buildSectionTitle('Order Summary'),
              _buildOrderSummaryCard(cart),
            ],
          ),
        ),
        bottomNavigationBar: _buildPlaceOrderButton(cart),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
    );
  }

  Widget _buildAddressCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.deepOrange, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deliver to',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_address,
                      style: GoogleFonts.poppins(
                          color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ),
            TextButton(
              onPressed: _showEditAddressSheet,
              child: Text('Change',
                  style: GoogleFonts.poppins(
                      color: Colors.deepOrange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Column(
        children: [
          _buildPaymentRadio(
            title: 'Cash on Delivery',
            icon: Icons.money,
            value: PaymentMethod.cash,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildPaymentRadio(
            title: 'Credit/Debit Card',
            icon: Icons.credit_card,
            value: PaymentMethod.card,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildPaymentRadio(
            title: 'UPI',
            icon: Icons.wallet,
            value: PaymentMethod.upi,
          ),
          if (_selectedPaymentMethod == PaymentMethod.card) _buildCardForm(),
          if (_selectedPaymentMethod == PaymentMethod.upi) _buildUpiForm(),
        ],
      ),
    );
  }

  Widget _buildPaymentRadio({
    required String title,
    required IconData icon,
    required PaymentMethod value,
  }) {
    return RadioListTile<PaymentMethod>(
      value: value,
      groupValue: _selectedPaymentMethod,
      onChanged: (newValue) {
        if (newValue != null) setState(() => _selectedPaymentMethod = newValue);
      },
      title: Row(
        children: [
          Icon(icon, color: Colors.deepOrange),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      activeColor: Colors.deepOrange,
    );
  }

  Widget _buildUpiForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 20.0),
      child: TextField(
        controller: _upiIdController,
        decoration: _inputDecoration('Enter UPI ID (e.g., name@bank)'),
        keyboardType: TextInputType.emailAddress,
      ),
    );
  }

  Widget _buildCardForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
      child: Column(
        children: [
          TextField(
              controller: _cardNumberController,
              decoration: _inputDecoration('Card Number'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _expiryDateController,
                      decoration: _inputDecoration('MM/YY'),
                      keyboardType: TextInputType.datetime)),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _cvvController,
                      decoration: _inputDecoration('CVV'),
                      keyboardType: TextInputType.number,
                      obscureText: true)),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    );
  }

  Widget _buildOrderSummaryCard(CartProvider cart) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPriceRow('Subtotal', '₹${cart.subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            _buildPriceRow(
                'Delivery Fee', '₹${cart.deliveryFee.toStringAsFixed(2)}'),
            const Divider(height: 24, thickness: 1),
            _buildPriceRow(
                'Total Amount', '₹${cart.totalPrice.toStringAsFixed(2)}',
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: isTotal ? 17 : 15,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? Colors.black87 : Colors.grey[700])),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: isTotal ? 17 : 15,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: Colors.black87)),
      ],
    );
  }

  Widget _buildPlaceOrderButton(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
          ]),
      child: ElevatedButton(
        onPressed: _isProcessing || cart.items.isEmpty
            ? null
            : () => _placeOrder(cart),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: _isProcessing
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
            : Text('PLACE ORDER',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}