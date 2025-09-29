import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final SpeechToText speechToText = SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeechInitialized = false;

  Future<void> initialize() async {
    if (!_isSpeechInitialized) {
      _isSpeechInitialized = await speechToText.initialize();
    }
  }

  Future<void> startListening({required Function(String) onResult}) async {
    await initialize();
    if (speechToText.isAvailable && !speechToText.isListening) {
      speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
      );
    }
  }

  Future<void> stopListening() async {
    await speechToText.stop();
  }

  Future<void> speak(String text) async {
    await flutterTts.speak(text);
  }
}