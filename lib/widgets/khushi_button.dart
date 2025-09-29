import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bizil/services/ai_service.dart';
import 'package:bizil/services/voice_service.dart';
import 'package:bizil/providers/cart_provider.dart';
import 'package:bizil/providers/restaurant_provider.dart';

enum KhushiState { idle, listening, processing, speaking }

class KhushiButton extends StatefulWidget {
  const KhushiButton({super.key});

  @override
  State<KhushiButton> createState() => _KhushiButtonState();
}

class _KhushiButtonState extends State<KhushiButton> {
  final VoiceService _voiceService = VoiceService();
  final AiService _aiService = AiService();
  KhushiState _currentState = KhushiState.idle;

  @override
  void initState() {
    super.initState();
    _voiceService.initialize();
    _aiService.loadModel();
  }

  void _handleListen() async {
    if (_currentState != KhushiState.idle) return;
    setState(() => _currentState = KhushiState.listening);
    _voiceService.startListening(onResult: _processVoiceCommand);
  }

  void _processVoiceCommand(String recognizedText) {
    if (!mounted) return;
    setState(() => _currentState = KhushiState.processing);

    if (recognizedText.isEmpty) {
      setState(() => _currentState = KhushiState.idle);
      return;
    }

    final String intent = _aiService.processCommand(recognizedText);

    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    String spokenResponse = "Sorry, I’m not sure how to help with that.";

    switch (intent) {
      case 'AddToCart':
        final details = _findItemInCommand(
            recognizedText.toLowerCase(), restaurantProvider.restaurants);
        if (details != null) {
          cartProvider.addItem(
            details['item'].id,
            details['item'].itemName,
            details['item'].price,
            details['item'].imageUrl,
            details['restaurant'].id,
            details['restaurant'].name,
            details['restaurant'].imageUrl,
          );
          spokenResponse = "Added ${details['item'].itemName} to your cart.";
        } else {
          spokenResponse = "I couldn't find that item.";
        }
        break;

      case 'GetCartTotal':
        spokenResponse =
            "Your total is ₹${cartProvider.totalPrice.toStringAsFixed(2)}.";
        break;

    }

    _speakAndReset(spokenResponse);
  }

  Future<void> _speakAndReset(String text) async {
    setState(() => _currentState = KhushiState.speaking);
    await _voiceService.speak(text);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _currentState = KhushiState.idle);
    });
  }

  Map<String, dynamic>? _findItemInCommand(
      String command, List<Restaurant> restaurants) {
    for (var restaurant in restaurants) {
      for (var item in restaurant.menu) {
        if (command.contains(item.itemName.toLowerCase())) {
          return {'item': item, 'restaurant': restaurant};
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _handleListen,
      backgroundColor: _getColorForState(),
      child: Icon(_getIconForState()),
    );
  }

  IconData _getIconForState() {
    switch (_currentState) {
      case KhushiState.listening:
        return Icons.mic;
      case KhushiState.processing:
        return Icons.settings_voice;
      case KhushiState.speaking:
        return Icons.volume_up;
      default:
        return Icons.mic_none;
    }
  }

  Color _getColorForState() {
    switch (_currentState) {
      case KhushiState.listening:
        return Colors.red;
      case KhushiState.processing:
        return Colors.orange;
      case KhushiState.speaking:
        return Colors.green;
      default:
        return Theme.of(context).primaryColor;
    }
  }
}