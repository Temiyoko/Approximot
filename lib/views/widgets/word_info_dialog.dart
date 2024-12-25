import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WordInfoDialog extends StatelessWidget {
  final String word;
  final String directLink;
  final List<String> nature;
  final List<List<String>> genre;
  final List<List<Map<String, String>>> natureDef;

  const WordInfoDialog({
    super.key,
    required this.word,
    required this.directLink,
    required this.nature,
    required this.genre,
    required this.natureDef,
  });

  String cleanText(String text) {
    final Map<String, String> unicodeReplacements = {
      r'\u00e0': 'à',
      r'\u00e2': 'â',
      r'\u00e4': 'ä',
      r'\u00e7': 'ç',
      r'\u00e8': 'è',
      r'\u00e9': 'é',
      r'\u00ea': 'ê',
      r'\u00eb': 'ë',
      r'\u00ee': 'î',
      r'\u00ef': 'ï',
      r'\u00f4': 'ô',
      r'\u00f6': 'ö',
      r'\u00f9': 'ù',
      r'\u00fb': 'û',
      r'\u00fc': 'ü',
      r'\u0153': 'œ',
      r'\u00e6': 'æ',
      r'\u00ff': 'ÿ',
      '&#160;': ' ',
      '&nbsp;': ' ',
    };

    String cleanedText = text;
    
    unicodeReplacements.forEach((key, value) {
      cleanedText = cleanedText.replaceAll(key, value);
    });

    cleanedText = cleanedText.replaceAll(RegExp(r'<[^>]*>'), '');

    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleanedText;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF303030),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cleanText(word),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (nature.isNotEmpty) ...[
                Text(
                  'Nature: ${nature.map(cleanText).join(', ')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (genre.isNotEmpty) ...[
                Text(
                  'Genre:',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                  ),
                ),
                ...genre.map((g) => Text(
                  g.length > 1 
                      ? '${cleanText(g[0])} (${cleanText(g[1])})'
                      : cleanText(g[0]),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                )),
                const SizedBox(height: 16),
              ],
              if (natureDef.isNotEmpty) ...[
                Text(
                  'Définitions:',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                ...natureDef.asMap().entries.map((natureEntry) {
                  final definitions = natureEntry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nature.length > 1) ...[
                        Text(
                          cleanText(nature[natureEntry.key]),
                          style: const TextStyle(
                            color: Color(0xFFF1E173),
                            fontSize: 14,
                            fontFamily: 'Poppins',
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      ...definitions.expand((def) => def.entries).map((entry) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 8),
                          child: Text(
                            '${entry.key}. ${cleanText(entry.value)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      if (natureEntry.key < natureDef.length - 1)
                        const SizedBox(height: 16),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(Uri.parse(directLink));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1E173),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Plus d'informations", style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 