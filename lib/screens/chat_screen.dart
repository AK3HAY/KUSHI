import 'dart:async';
import 'dart:math';
import 'package:bizil/providers/cart_provider.dart';
import 'package:bizil/providers/chat_provider.dart';
import 'package:bizil/providers/restaurant_provider.dart';
import 'package:bizil/screens/billing_screen.dart';
import 'package:bizil/screens/order_success_screen.dart';
import 'package:bizil/services/ai_service.dart';
import 'package:bizil/services/order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:bizil/services/entity_extractor.dart';

import 'package:bizil/providers/restaurant_provider.dart'
    show Restaurant, MenuItem;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum ConversationState {
  normal,
  awaitingPaymentMethod,
  awaitingCheckoutConfirmation,
  awaitingAddQuantity,
  awaitingRemoveQuantity,
  awaitingMenuConfirmation,
  awaitingItemToRemove,
  awaitingItemToAdd,
  awaitingRestaurantChoiceForMenu,
}

enum TtsState { playing, stopped }

class _ChatScreenState extends State<ChatScreen> {
  final AiService _aiService = AiService();
  final OrderService _orderService = OrderService();
  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  bool isListening = false;
  bool _speechEnabled = false;
  bool _isAiReady = false;

  ConversationState _conversationState = ConversationState.normal;
  String _paymentMethod = '';
  Map<String, dynamic>? _itemPendingAction;
  Restaurant? _restaurantPendingConfirmation;
  TtsState _ttsState = TtsState.stopped;

  @override
  void initState() {
    super.initState();
    _initServices();
    flutterTts
        .setStartHandler(() => setState(() => _ttsState = TtsState.playing));
    flutterTts.setCompletionHandler(
        () => setState(() => _ttsState = TtsState.stopped));
    flutterTts
        .setErrorHandler((_) => setState(() => _ttsState = TtsState.stopped));
  }

  Future<void> _initServices() async {
    if (!mounted) return;
    await _initTts();
    await _initSpeech();
    await _aiService.loadModel();
    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    if (restaurantProvider.restaurants.isEmpty) {
      await restaurantProvider.fetchRestaurants();
    }
    if (!mounted) return;
    setState(() => _isAiReady = true);
    _speakInitialMessage();
  }

  void _speakInitialMessage() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (!chatProvider.initialMessageSpoken) {
      final initialBotMessage = chatProvider.messages.last['text'];
      if (initialBotMessage != null && initialBotMessage.isNotEmpty) {
        _speak(initialBotMessage);
        chatProvider.markInitialMessageAsSpoken();
      }
    }
  }

  Future<void> _initTts() async => await flutterTts.setLanguage("en-US");

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) => setState(() => isListening = _speech.isListening),
        onError: (error) {
          print("Speech Recognition Error: $error");
          setState(() => isListening = false);
        },
      );
    } else {
      print("Microphone permission was not granted.");
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _speak(String text, {bool listenAfter = false}) async {
    setState(() => _ttsState = TtsState.playing);
    if (text.isNotEmpty) {
      flutterTts.setCompletionHandler(() {
        setState(() => _ttsState = TtsState.stopped);
        if (listenAfter && mounted) _listen();
      });
      await flutterTts.speak(text);
    } else if (listenAfter && mounted) {
      setState(() => _ttsState = TtsState.stopped);
      _listen();
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _speech.stop();
    _aiService.close();
    super.dispose();
  }

  void _listen() {
    if (!_speechEnabled || !_isAiReady) return;
    if (_speech.isListening) {
      _speech.stop();
      setState(() => isListening = false);
    } else {
      _speech.listen(onResult: _onSpeechResult, localeId: "en-US");
      setState(() => isListening = true);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    print(
        "Speech Recognition Result: final=${result.finalResult}, words='${result.recognizedWords}'");

    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      Provider.of<ChatProvider>(context, listen: false)
          .addMessage(result.recognizedWords, true);
      _getBotResponse(result.recognizedWords);
    }
  }

  int _extractQuantity(String command) {
    final text = command.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '');
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    final numberWords = {
      'a': 1,
      'an': 1,
      'one': 1,
      'two': 2,
      'to': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10
    };
    if (words.isEmpty) return 1;
    for (final word in words) {
      final numValue = int.tryParse(word);
      if (numValue != null) return numValue;
      if (numberWords.containsKey(word)) return numberWords[word]!;
    }
    return words.isNotEmpty ? 1 : 0;
  }

  Future<void> _getBotResponse(String userMessage) async {
    switch (_conversationState) {
      case ConversationState.awaitingItemToAdd:
        _handleItemToAddResponse(userMessage);
        break;
      case ConversationState.awaitingItemToRemove:
        _handleItemToRemoveResponse(userMessage);
        break;
      case ConversationState.awaitingAddQuantity:
        _handleQuantityResponse(userMessage, isAdding: true);
        break;
      case ConversationState.awaitingRemoveQuantity:
        _handleQuantityResponse(userMessage, isAdding: false);
        break;
      case ConversationState.awaitingMenuConfirmation:
        _handleMenuConfirmation(userMessage);
        break;
      case ConversationState.awaitingRestaurantChoiceForMenu:
        _handleRestaurantChoiceForMenu(userMessage);
        break;
      case ConversationState.awaitingPaymentMethod:
        _handlePaymentMethodResponse(userMessage);
        break;
      case ConversationState.awaitingCheckoutConfirmation:
        _handleCheckoutConfirmation(userMessage);
        break;
      case ConversationState.normal:
        _handleNormalIntent(userMessage);
        break;
    }
  }

  void _handleItemToAddResponse(String userMessage) {
    setState(() => _conversationState = ConversationState.normal);
    _handleNormalIntent('add $userMessage');
  }

  void _handleItemToRemoveResponse(String userMessage) {
    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    setState(() => _conversationState = ConversationState.normal);
    final extracted = EntityExtractor.extractMenuItem(
        userMessage, restaurantProvider.restaurants);
    if (extracted != null &&
        cartProvider.items.containsKey(extracted['item'].id)) {
      final int quantityToRemove = _extractQuantity('one $userMessage');
      final MenuItem item = extracted['item'];
      for (int i = 0; i < quantityToRemove; i++) {
        cartProvider.removeSingleItem(item.id);
      }
      _addAndSpeak(
          "Removed ${quantityToRemove > 1 ? '$quantityToRemove ' : ''}${item.itemName}${quantityToRemove > 1 ? 's' : ''} from your cart.");
    } else {
      _addAndSpeak(
          "I'm sorry, I couldn't find '${userMessage}' in your cart to remove.");
    }
  }

  void _handleRestaurantChoiceForMenu(String userMessage) {
    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final restaurant = EntityExtractor.extractRestaurant(
        userMessage, restaurantProvider.restaurants);
    setState(() => _conversationState = ConversationState.normal);

    if (restaurant != null) {
      _showFullMenuFor(restaurant);
    } else {
      chatProvider.addMessage(
          "I'm sorry, I couldn't find a restaurant by that name. Please try again.",
          false);
      _speak(
          "I'm sorry, I couldn't find a restaurant by that name. Please try again.",
          listenAfter: true);
    }
  }

  void _handleMenuConfirmation(String userMessage) {
    final command = userMessage.toLowerCase();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (command.contains('yes') ||
        command.contains('sure') ||
        command.contains('okay')) {
      if (_restaurantPendingConfirmation != null) {
        _showFullMenuFor(_restaurantPendingConfirmation!);
      }
    } else {
      chatProvider.addMessage("Okay, what else can I help you with?", false);
      _speak("Okay, what else can I help you with?");
    }
    setState(() {
      _conversationState = ConversationState.normal;
      _restaurantPendingConfirmation = null;
    });
  }

  void _handleQuantityResponse(String userMessage, {required bool isAdding}) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final int quantity = _extractQuantity(userMessage);
    if (quantity > 0 && _itemPendingAction != null) {
      final MenuItem item = _itemPendingAction!['item'];
      final Restaurant restaurant = _itemPendingAction!['restaurant'];
      String botResponseText;
      if (isAdding) {
        for (int i = 0; i < quantity; i++) {
          cartProvider.addItem(
              item.id,
              item.itemName,
              item.price,
              item.imageUrl,
              restaurant.id,
              restaurant.name,
              restaurant.imageUrl);
        }
        botResponseText =
            "Added ${quantity > 1 ? '$quantity ' : ''}${item.itemName}${quantity > 1 ? 's' : ''} to your cart.";
      } else {
        for (int i = 0; i < quantity; i++) {
          cartProvider.removeSingleItem(item.id);
        }
        botResponseText =
            "Removed ${quantity > 1 ? '$quantity ' : ''}${item.itemName}${quantity > 1 ? 's' : ''} from your cart.";
      }
      chatProvider.addMessage(botResponseText, false);
      _speak(botResponseText);
    } else {
      chatProvider.addMessage("I'm sorry, I didn't get that. How many?", false);
      _speak("I'm sorry, I didn't get that. How many?", listenAfter: true);
      return;
    }
    setState(() {
      _conversationState = ConversationState.normal;
      _itemPendingAction = null;
    });
  }

  void _handlePaymentMethodResponse(String userMessage) {
    final command = userMessage.toLowerCase();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    String? chosenMethod;
    if (command.contains('cash') || command.contains('delivery')) {
      chosenMethod = 'Cash on Delivery';
    } else if (command.contains('upi') ||
        command.contains('paytm') ||
        command.contains('phonepe') ||
        command.contains('google pay')) chosenMethod = 'UPI';

    if (chosenMethod != null) {
      _paymentMethod = chosenMethod;
      if (chosenMethod == 'UPI') {
        chatProvider.addMessage("Okay, proceeding to UPI payment.", false);
        _speak("Okay, proceeding to UPI payment.");
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (ctx) => const BillingScreen()));
        setState(() => _conversationState = ConversationState.normal);
      } else {
        setState(() =>
            _conversationState = ConversationState.awaitingCheckoutConfirmation);
        final part1 =
            "Great. You have selected Cash on Delivery. Here is your order summary.";
        final part2 = "Is this correct, and should I place the order?";
        final spokenSummary = _generateSpokenCartSummary(
            Provider.of<CartProvider>(context, listen: false));
        final responseCards = Provider.of<CartProvider>(context, listen: false)
            .items
            .values
            .map((cartItem) => _buildInfoCard(
                title: cartItem.name,
                subtitle: 'From ${cartItem.restaurantName}',
                imageUrl: cartItem.imageUrl,
                trailingText:
                    'Qty: ${cartItem.quantity}\n₹${(cartItem.price * cartItem.quantity).toStringAsFixed(2)}'))
            .toList();

        chatProvider.addMessage(part1, false, cards: responseCards);
        _speak(part1).then((_) {
          if (mounted) {
            chatProvider.addMessage(part2, false);
            _speak("$spokenSummary. $part2", listenAfter: true);
          }
        });
      }
    } else {
      chatProvider.addMessage(
          "Sorry, I didn't catch that. Please choose 'Cash on delivery' or 'UPI'.",
          false);
      _speak(
          "Sorry, I didn't catch that. Please choose 'Cash on delivery' or 'UPI'.",
          listenAfter: true);
    }
  }

  void _handleCheckoutConfirmation(String userMessage) async {
    final command = userMessage.toLowerCase();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (command.contains('yes') ||
        command.contains('correct') ||
        command.contains('place') ||
        command.contains('confirm')) {
      try {
        await _orderService.placeOrder(
            cart: Provider.of<CartProvider>(context, listen: false),
            paymentMethod: _paymentMethod);
        Provider.of<CartProvider>(context, listen: false).clearCart();
        chatProvider.addMessage(
            "Excellent! Your order has been placed successfully.", false);
        _speak(
            "Excellent! Your order has been placed. Redirecting to order summary.");
        if (mounted) {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const OrderSuccessScreen()));
        }
      } catch (e) {
        chatProvider.addMessage(
            "Sorry, there was an error placing your order. Please try again.",
            false);
        _speak(
            "Sorry, there was an error placing your order. Please try again.");
      }
      setState(() => _conversationState = ConversationState.normal);
    } else if (command.contains('no') ||
        command.contains('cancel') ||
        command.contains('stop')) {
      chatProvider.addMessage(
          "Okay, I have cancelled the checkout process. How else can I help you?",
          false);
      _speak(
          "Okay, I have cancelled the checkout process. How else can I help you?");
      setState(() => _conversationState = ConversationState.normal);
    } else {
      chatProvider.addMessage(
          "Please confirm with a 'Yes' to place the order or 'No' to cancel.",
          false);
      _speak(
          "Please confirm with a 'Yes' to place the order or 'No' to cancel.",
          listenAfter: true);
    }
  }

  Future<void> _handleNormalIntent(String userMessage) async {
    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    String intent = _aiService.processCommand(userMessage);

    print("USER SAID: '$userMessage' ---> AI PREDICTED INTENT: '$intent'");

    switch (intent) {
      case 'IncompleteAdd':
        setState(
            () => _conversationState = ConversationState.awaitingItemToAdd);
        _addAndSpeak("Certainly, what item would you like to add?",
            listenAfter: true);
        break;

      case 'IncompleteRemove':
        if (cartProvider.items.isEmpty) {
          _addAndSpeak(
              "Your cart is already empty, so there's nothing to remove.");
          break;
        }
        setState(
            () => _conversationState = ConversationState.awaitingItemToRemove);
        _addAndSpeak("Sure, what item would you like to remove from your cart?",
            listenAfter: true);
        break;

      case 'Thanks':
        _addAndSpeak("You're welcome! Is there anything else I can help with?");
        break;

      case 'Greeting':
        const greetings = [
          'Hello! How can I assist you?',
          'Hi there! What are we craving today?',
          'Hey! Ready to order something delicious?'
        ];
        _addAndSpeak(greetings[Random().nextInt(greetings.length)]);
        break;

      case 'GetRestaurantList':
        final restaurants = restaurantProvider.restaurants;
        if (restaurants.isNotEmpty) {
          final botResponseText = "Sure, here are the available restaurants:";
          final responseCards = restaurants
              .map((r) => _buildInfoCard(
                  title: r.name,
                  subtitle: r.cuisine,
                  imageUrl: r.imageUrl,
                  trailingText: '⭐ ${r.rating.toStringAsFixed(1)}'))
              .toList();
          final spokenText =
              "The available restaurants are: ${restaurants.map((r) => r.name).join(', ')}.";
          _addAndSpeak(botResponseText,
              spokenOverride: spokenText, cards: responseCards);
        } else {
          _addAndSpeak(
              "Sorry, I couldn't find any available restaurants right now.");
        }
        break;

      case 'ClearCart':
        if (cartProvider.items.isEmpty) {
          _addAndSpeak("Your cart is already empty.");
        } else {
          cartProvider.clearCart();
          _addAndSpeak("I have cleared all items from your cart.");
        }
        break;

      case 'AddToCart':
        final extractedItem = EntityExtractor.extractMenuItem(
            userMessage, restaurantProvider.restaurants);
        if (extractedItem != null) {
          final int quantity = _extractQuantity(userMessage);
          if (quantity == 0 ||
              userMessage.toLowerCase().contains("how many")) {
            setState(() {
              _conversationState = ConversationState.awaitingAddQuantity;
              _itemPendingAction = extractedItem;
            });
            _addAndSpeak("Sure, how many would you like to add?",
                listenAfter: true);
          } else {
            final MenuItem item = extractedItem['item'];
            final Restaurant restaurant = extractedItem['restaurant'];
            for (int i = 0; i < quantity; i++) {
              cartProvider.addItem(
                  item.id,
                  item.itemName,
                  item.price,
                  item.imageUrl,
                  restaurant.id,
                  restaurant.name,
                  restaurant.imageUrl);
            }
            _addAndSpeak(
                "Added ${quantity > 1 ? '$quantity ' : ''}${item.itemName}${quantity > 1 ? 's' : ''} to your cart.");
          }
        } else {
          setState(
              () => _conversationState = ConversationState.awaitingItemToAdd);
          _addAndSpeak(
              "I see you want to add something. What item would you like?",
              listenAfter: true);
        }
        break;

      case 'RemoveFromCart':
        if (cartProvider.items.isEmpty) {
          _addAndSpeak(
              "Your cart is already empty, so there's nothing to remove.");
          break;
        }
        final extracted = EntityExtractor.extractMenuItem(
            userMessage, restaurantProvider.restaurants);
        if (extracted != null &&
            cartProvider.items.containsKey(extracted['item'].id)) {
          final int quantityToRemove = _extractQuantity(userMessage);
          final MenuItem item = extracted['item'];
          for (int i = 0; i < quantityToRemove; i++) {
            cartProvider.removeSingleItem(item.id);
          }
          _addAndSpeak(
              "Removed ${quantityToRemove > 1 ? '$quantityToRemove ' : ''}${item.itemName}${quantityToRemove > 1 ? 's' : ''} from your cart.");
        } else {
          setState(() =>
              _conversationState = ConversationState.awaitingItemToRemove);
          _addAndSpeak(
              "I see you want to remove something. What item would you like to remove?",
              listenAfter: true);
        }
        break;

      case 'GetCartTotal':
        if (cartProvider.items.isEmpty) {
          _addAndSpeak("Your cart is currently empty.");
        } else {
          _addAndSpeak(
              "Your cart total is ₹${cartProvider.totalPrice.toStringAsFixed(2)}.");
        }
        break;

      case 'ShowCart':
        if (cartProvider.items.isEmpty) {
          _addAndSpeak("Your cart is empty, so there's nothing to show.");
        } else {
          final botResponseText = "Sure, here are the items in your cart:";
          final responseCards = cartProvider.items.values
              .map((cartItem) => _buildInfoCard(
                  title: cartItem.name,
                  subtitle: 'From ${cartItem.restaurantName}',
                  imageUrl: cartItem.imageUrl,
                  trailingText:
                      'Qty: ${cartItem.quantity}\n₹${(cartItem.price * cartItem.quantity).toStringAsFixed(2)}'))
              .toList();
          final spokenText = _generateSpokenCartSummary(cartProvider);
          _addAndSpeak(botResponseText,
              spokenOverride: spokenText, cards: responseCards);
        }
        break;

      case 'GetItemPrice':
        final extracted = EntityExtractor.extractMenuItem(
            userMessage, restaurantProvider.restaurants);
        if (extracted != null) {
          final MenuItem item = extracted['item'];
          final Restaurant restaurant = extracted['restaurant'];
          final botResponseText = "Here is the price for ${item.itemName}:";
          final responseCards = [
            _buildInfoCard(
                title: item.itemName,
                subtitle: 'From ${restaurant.name}',
                imageUrl: item.imageUrl,
                trailingText: '₹${item.price.toStringAsFixed(2)}')
          ];
          final spokenText =
              "${item.itemName} from ${restaurant.name} costs ${item.price.toStringAsFixed(0)} rupees.";
          _addAndSpeak(botResponseText,
              spokenOverride: spokenText, cards: responseCards);
        } else {
          _addAndSpeak(
              "I'm sorry, I couldn't find that item to check its price.");
        }
        break;

      case 'ShowFullMenu':
        final restaurant = EntityExtractor.extractRestaurant(
            userMessage, restaurantProvider.restaurants);
        if (restaurant != null) {
          _showFullMenuFor(restaurant);
        } else {
          final restaurants = restaurantProvider.restaurants;
          setState(() => _conversationState =
              ConversationState.awaitingRestaurantChoiceForMenu);
          final botResponseText =
              "Of course. Which restaurant's menu would you like to see?";
          final responseCards = restaurants
              .map((r) => _buildInfoCard(
                  title: r.name,
                  subtitle: r.cuisine,
                  imageUrl: r.imageUrl,
                  trailingText: '⭐ ${r.rating.toStringAsFixed(1)}'))
              .toList();
          final spokenText =
              "$botResponseText ${restaurants.map((r) => r.name).join(', ')}?";
          _addAndSpeak(botResponseText,
              spokenOverride: spokenText,
              cards: responseCards,
              listenAfter: true);
        }
        break;

      case 'StartCheckout':
        if (cartProvider.items.isEmpty) {
          _addAndSpeak(
              "Your cart is empty. Please add items before checking out.");
        } else {
          setState(() =>
              _conversationState = ConversationState.awaitingPaymentMethod);
          _addAndSpeak(
              "To proceed, would you like to pay with Cash on Delivery or UPI?",
              listenAfter: true);
        }
        break;

      case 'ConfirmationYes':
      case 'ConfirmationNo':
        _addAndSpeak(
            "Sorry, I'm not sure what you're confirming. Can you be more specific?");
        break;

      case 'Unknown':
      default:
        _addAndSpeak("Sorry, I didn’t understand that. Please try again.");
        break;
    }
  }

  void _addAndSpeak(String text,
      {String? spokenOverride,
      List<Widget>? cards,
      bool listenAfter = false}) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.addMessage(text, false, cards: cards);
    _speak(spokenOverride ?? text, listenAfter: listenAfter);
  }

  void _showFullMenuFor(Restaurant restaurant) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    String botResponseText;
    String spokenText;
    List<Widget> responseCards;
    if (restaurant.menu.isEmpty) {
      botResponseText =
          "It looks like ${restaurant.name} doesn't have a menu available right now.";
      spokenText = botResponseText;
      responseCards = [];
    } else {
      botResponseText = "Of course! Here is the menu for ${restaurant.name}:";
      responseCards = restaurant.menu
          .map((item) => _buildInfoCard(
              title: item.itemName,
              subtitle: '₹${item.price.toStringAsFixed(2)}',
              imageUrl: item.imageUrl,
              trailingText: ''))
          .toList();
      spokenText =
          "The menu for ${restaurant.name} has: ${_generateSpokenMenuSummary(restaurant)}";
    }
    chatProvider.addMessage(botResponseText, false, cards: responseCards);
    _speak(spokenText);
  }

  String _generateSpokenCartSummary(CartProvider cart) {
    if (cart.items.isEmpty) return "Your cart is empty.";
    final itemsList = cart.items.values
        .map((item) => "${item.quantity} ${item.name}")
        .toList();
    return "You have: ${itemsList.join(', ')}. The total is ${cart.totalPrice.toStringAsFixed(0)} rupees.";
  }

  String _generateSpokenMenuSummary(Restaurant restaurant) {
    if (restaurant.menu.isEmpty) return "no items.";
    final itemsList = restaurant.menu
        .map((item) =>
            "${item.itemName} for ${item.price.toStringAsFixed(0)} rupees")
        .toList();
    return itemsList.join(', ');
  }

  Widget _buildInfoCard(
      {required String title,
      required String subtitle,
      required String imageUrl,
      required String trailingText}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: const [
            BoxShadow(color: Colors.black12, spreadRadius: 1, blurRadius: 3)
          ]),
      child: Row(
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Image.network(imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: Icon(Icons.fastfood_rounded,
                          color: Colors.grey[400])))),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[600]))
                ]
              ],
            ),
          ),
          if (trailingText.isNotEmpty)
            Text(trailingText,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMicEnabled = _ttsState == TtsState.stopped;
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Kushi AI Assistant')),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (ctx, i) => _ChatMessage(
                      text: chatProvider.messages[i]['text'],
                      isUserMessage: chatProvider.messages[i]['isUser'],
                      cards: chatProvider.messages[i]['cards']),
                ),
              ),
              if (!_isAiReady)
                const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                        child: Column(children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text("Warming up AI...")
                    ]))),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: isMicEnabled && _isAiReady ? _listen : null,
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: isMicEnabled && _isAiReady
                            ? Colors.deepOrange
                            : Colors.grey,
                        child: Icon(isListening ? Icons.mic : Icons.mic_off,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String text;
  final bool isUserMessage;
  final List<Widget>? cards;
  const _ChatMessage(
      {required this.text, required this.isUserMessage, this.cards});
  @override
  Widget build(BuildContext context) {
    final bool hasCards = cards != null && cards!.isNotEmpty;
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
            color: isUserMessage
                ? Colors.deepOrange[400]
                : (hasCards ? Colors.transparent : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isUserMessage || hasCards
                ? []
                : [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 2)
                  ]),
        child: hasCards
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (text.isNotEmpty) ...[
                    Text(text,
                        style: GoogleFonts.poppins(
                            color: Colors.black87, fontSize: 16)),
                    const SizedBox(height: 8),
                  ],
                  ...cards!,
                ],
              )
            : Text(text,
                style: GoogleFonts.poppins(
                    color: isUserMessage ? Colors.white : Colors.black87,
                    fontSize: 16)),
      ),
    );
  }
}