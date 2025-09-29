import 'package:bizil/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'package:bizil/providers/cart_provider.dart';
import 'package:bizil/providers/restaurant_provider.dart';
import 'package:bizil/screens/home_screen.dart';
import 'package:bizil/screens/login_screen.dart';
import 'package:bizil/services/auth_service.dart';
import 'package:bizil/services/ai_service.dart';
import 'package:bizil/services/voice_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final aiService = AiService();
  await aiService.loadModel();

  final voiceService = VoiceService();
  await voiceService.initialize();

  runApp(MyApp(aiService: aiService, voiceService: voiceService));
}

class MyApp extends StatelessWidget {
  final AiService aiService;
  final VoiceService voiceService;

  const MyApp({
    super.key,
    required this.aiService,
    required this.voiceService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<AiService>.value(value: aiService),
        Provider<VoiceService>.value(value: voiceService),
      ],
      child: MaterialApp(
        title: 'Campus Food',
        theme: ThemeData(
          primarySwatch: Colors.orange,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          return user == null ? const LoginScreen() : const HomeScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}