import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WordHistoryWidget extends StatelessWidget {
  final List<Map<String, dynamic>> lastWords;
  final Function(String) fetchWordWiki;
  final Stream<String?> currentWordStream;

  const WordHistoryWidget({
    super.key,
    required this.lastWords,
    required this.fetchWordWiki,
    required this.currentWordStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: currentWordStream,
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF303030),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  'Historique des mots',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: lastWords.length,
                  itemBuilder: (context, index) {
                    final wordData = lastWords[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 4,
                      color: const Color(0xFF303030),
                      child: ListTile(
                        title: GestureDetector(
                          onTap: () => fetchWordWiki(wordData['word']),
                          child: Text(
                            wordData['word'],
                            style: const TextStyle(
                              color: Color(0xFFF1E173),
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(wordData['timestamp']),
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}