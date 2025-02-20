import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env.dart';

class WikiService {
  static WikiService? _instance;
  static String baseUrl = Environment.herokuApiUrl;

  static WikiService get instance {
    _instance ??= WikiService._();
    return _instance!;
  }

  WikiService._();

  Future<Map<String, dynamic>?> getCurrentArticle() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/current-wiki'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'title': data['title'],
            'extract': data['extract'],
            'timeRemaining': data['time_remaining'],
            'timestamp': data['timestamp'],
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current article: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> getArticle(String title) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get-wiki-article'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          String content = data['content'];
          if (content.contains('=')) {
            content = content.substring(0, content.indexOf('='));
          }
          return {
            'title': data['title'],
            'content': content.trim(),
            'direct_link': data['direct_link'],
          };
        }
      }
      throw Exception('Failed to load article');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting article: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRandomArticle() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/random-wiki-article'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return {
            'title': data['title'],
            'content': data['content'],
          };
        }
      }
      throw Exception('Failed to load random article');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting random article: $e');
      }
      rethrow;
    }
  }
} 