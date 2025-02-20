import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WordHistoryWidget extends StatelessWidget {
  final List<Map<String, dynamic>> lastWords;
  final Function(String) fetchWordWiki;
  final Stream<String?> currentWordStream;
  final String title;
  final Color pastelYellow = const Color(0xFFF1E173);

  const WordHistoryWidget({
    super.key,
    required this.lastWords,
    required this.fetchWordWiki,
    required this.currentWordStream,
    this.title = 'Historique des mots',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: currentWordStream,
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    scrollbarTheme: ScrollbarThemeData(
                      thumbColor: WidgetStateProperty.all(pastelYellow.withOpacity(0.5)),
                      trackColor: WidgetStateProperty.all(Colors.grey[800]),
                      radius: const Radius.circular(10),
                      thickness: WidgetStateProperty.all(6),
                      thumbVisibility: WidgetStateProperty.all(true),
                      trackVisibility: WidgetStateProperty.all(true),
                    ),
                  ),
                  child: Scrollbar(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      itemCount: lastWords.length,
                      itemBuilder: (context, index) {
                        final wordData = lastWords[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: pastelYellow.withOpacity(0.7),
                              width: 0.5,
                            ),
                          ),
                          elevation: 4,
                          color: const Color(0xFF303030),
                          child: ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    wordData['word'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(wordData['timestamp']),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_forward_ios,
                                        color: pastelYellow.withOpacity(0.3),
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        fetchWordWiki(wordData['word']);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Trouvé ${wordData['found_count'] ?? 0} fois',
                              style: const TextStyle(
                                color: Color(0xFFF1E173),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}