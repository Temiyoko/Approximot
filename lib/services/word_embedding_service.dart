import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WordEmbeddingService {
  static WordEmbeddingService? _instance;
  static const String baseUrl = 'https://approximot-1967d63b9545.herokuapp.com/';

  static WordEmbeddingService get instance {
    _instance ??= WordEmbeddingService._();
    return _instance!;
  }

  WordEmbeddingService._();

  Future<List<double>?> getEmbedding(String text) async {
    if (text.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/embed'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<double>.from(data['embedding']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting embedding: $e');
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getSimilarWords(String word, {int topn = 100}) async {

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/similar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': word, 'topn': topn}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['similar_words']);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting similar words: $e');
      }
      return null;
    }
  }

  Future<String?> getRandomWord() async {
    try {

      final response = await http.get(
        Uri.parse('$baseUrl/random'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['word'];
        } else {
          throw Exception('Server returned success: false - ${data['error']}');
        }
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting random word: $e');
      }
      rethrow;
    }
  }

  Future<double?> getSimilarity(String word1, String word2) async {

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/similarity'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'word1': word1, 'word2': word2}),
      );

      if (response.statusCode == 404) {
        throw WordNotFoundException(word1);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['similarity'];
        }
      }
      return null;
    } catch (e) {
      if (e is WordNotFoundException) {
        rethrow;
      }
      if (kDebugMode) {
        print('Error getting similarity: $e');
      }
      return null;
    }
  }
}

class WordNotFoundException implements Exception {
  final String word;
  WordNotFoundException(this.word);

  @override
  String toString() => 'Le mot "$word" n\'existe pas dans notre dictionnaire';
}