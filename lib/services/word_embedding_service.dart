import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WordEmbeddingService {
  static WordEmbeddingService? _instance;
  late ByteData _modelData;
  bool _isLoaded = false;

  // Singleton pattern
  static WordEmbeddingService get instance {
    _instance ??= WordEmbeddingService._();
    return _instance!;
  }

  WordEmbeddingService._();

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    try {
      _modelData = await rootBundle.load('assets/modele.bin');
      _isLoaded = true;
      if (kDebugMode) {
        print('Word embedding model loaded successfully: ${_modelData.lengthInBytes} bytes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading word embedding model: $e');
      }
      _isLoaded = false;
    }
  }

  // Add methods to use the model data here
} 