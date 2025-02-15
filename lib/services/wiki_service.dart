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
    
    final extract = page['extract'] ?? '';
    final pageviews = page['pageviews'] ?? {};
    final averageViews = pageviews.values.fold(0, (sum, views) => sum + views) / pageviews.length;
    
    return extract.length > 500 && // Taille minimum
           averageViews > 1000000 && // Popularité minimum
           !title.contains(':'); // Éviter les pages spéciales
  }

  static Future<Map<String, dynamic>> getRandomArticle() async {
    // Premièrement, obtenir un titre d'article aléatoire
    final randomResponse = await http.get(Uri.parse(
      '$baseUrl?action=query&format=json&list=random'
      '&rnnamespace=0&rnlimit=1'
    ));
    
    final randomData = json.decode(randomResponse.body);
    final title = randomData['query']['random'][0]['title'];
    
    // Ensuite, obtenir le contenu de l'article
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