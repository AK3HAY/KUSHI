import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SimpleTokenizer {
  final Map<String, int> vocab;
  final int unkId;

  SimpleTokenizer(this.vocab, {this.unkId = 1});

  List<int> encode(String text) {
    final tokens = _basicTokenize(text);
    return tokens.map((token) => vocab[token] ?? unkId).toList();
  }

  List<String> _basicTokenize(String text) {
    final cleaned = text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s]+"), '');
    final parts = cleaned.split(RegExp(r"\s+"));
    return parts.where((p) => p.isNotEmpty).toList();
  }
}

class AiService {
  Interpreter? _interpreter;
  bool _isLoaded = false;
  late List<String> _labels;
  late SimpleTokenizer _tokenizer;
  int _inputLength = 30;

  Future<void> loadModel({
    String modelPath = 'assets/model.tflite',
    String labelsPath = 'assets/labels.txt',
    String vocabPath = 'assets/vocabulary.txt',
  }) async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      if (_interpreter == null) {
        print("AI Service Error: Interpreter.fromAsset() returned null. Check asset path and file.");
        _isLoaded = false;
        return;
      }

      _labels = await _loadLabels(labelsPath);
      final vocab = await _loadVocab(vocabPath);
      _tokenizer = SimpleTokenizer(vocab, unkId: vocab['[UNK]'] ?? 1);
      
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      _isLoaded = true;
      print("AI Service: Model loaded successfully.");
      print(" -> Input shape: ${inputTensor.shape}, type: ${inputTensor.type}");
      print(" -> Output shape: ${outputTensor.shape}, type: ${outputTensor.type}");

    } catch (e) {
      _isLoaded = false;
      print("AI Service Critical Error: Failed to load model from assets. Exception: $e");
    }
  }

  Future<List<String>> _loadLabels(String path) async {
    final raw = await rootBundle.loadString(path);
    return raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  Future<Map<String, int>> _loadVocab(String path) async {
    final raw = await rootBundle.loadString(path);
    final lines = raw.split('\n');
    final map = <String, int>{};
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        map[token] = i;
      }
    }
    return map;
  }

  String processCommand(String text) {
    if (!_isLoaded || _interpreter == null) {
      print("AI Service Error: Interpreter is not initialized.");
      return 'Error';
    }

    final ids = _tokenizer.encode(text);
    final paddedIds = List<int>.filled(_inputLength, 0)..setAll(0, ids.take(_inputLength));
    
    final tokenList = paddedIds.map((id) => id.toDouble()).toList();
    final input = Float32List.fromList(tokenList).reshape([1, _inputLength]);

    final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print("AI Service Error: Failed to run model inference. $e");
      return 'Error';
    }
    
    final scores = output[0] as List<double>;
    int maxIdx = 0;
    double maxScore = -double.infinity;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIdx = i;
      }
    }

    if (maxIdx >= _labels.length) {
      print("AI Service Error: Predicted index is out of bounds.");
      return 'Error';
    }
    return _labels[maxIdx];
  }

  void close() {
    _interpreter?.close();
  }
}