import 'package:flutter/material.dart';

class ChatProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hello! I am Kushi. How can I help you?', 'isUser': false}
  ];

  bool _initialMessageSpoken = false;

  List<Map<String, dynamic>> get messages => _messages;
  bool get initialMessageSpoken => _initialMessageSpoken;

  void addMessage(String text, bool isUser, {List<Widget>? cards}) {
    if (text.isEmpty && (cards == null || cards.isEmpty)) return;

    _messages.insert(0, {'text': text, 'isUser': isUser, 'cards': cards});

    notifyListeners();
  }

  void markInitialMessageAsSpoken() {
    _initialMessageSpoken = true;
  }
}
