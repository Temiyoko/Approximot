import 'package:http/http.dart' as http;
import 'dart:convert';

class WikiService {
  static const String baseUrl = 'https://fr.wikipedia.org/w/api.php';
  
  static Future<Map<String, dynamic>> getArticleInfo(String title) async {
    final response = await http.get(Uri.parse(
      '$baseUrl?action=query&format=json&titles=${Uri.encodeComponent(title)}'
      '&prop=extracts|pageviews&explaintext=1&exintro=1'
    ));
    
    return json.decode(response.body);
  }
  
  static Future<bool> isValidArticle(String title) async {
    final info = await getArticleInfo(title);
    final page = info['query']['pages'].values.first;
    
    // Check if article meets our criteria
    final extract = page['extract'] ?? '';
    final pageviews = page['pageviews'] ?? {};
    final averageViews = pageviews.values.fold(0, (sum, views) => sum + views) / pageviews.length;
    
    return extract.length > 500 && // Minimum length
           averageViews > 1000000 && // Minimum popularity
           !title.contains('(') && // Avoid disambiguation
           !title.contains(':'); // Avoid special pages
  }

  static Future<Map<String, dynamic>> getRandomArticle() async {
    // First get a random article title
    final randomResponse = await http.get(Uri.parse(
      '$baseUrl?action=query&format=json&list=random'
      '&rnnamespace=0&rnlimit=1'
    ));
    
    final randomData = json.decode(randomResponse.body);
    final title = randomData['query']['random'][0]['title'];
    
    // Then get the article content
    final contentResponse = await http.get(Uri.parse(
      '$baseUrl?action=query&format=json&titles=${Uri.encodeComponent(title)}'
      '&prop=extracts&explaintext=1&exintro=1'
    ));
    
    final contentData = json.decode(contentResponse.body);
    final pages = contentData['query']['pages'];
    final page = pages[pages.keys.first];
    
    return {
      'title': title,
      'content': page['extract'] ?? '',
    };
  }
} 