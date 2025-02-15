import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WikiArticleDialog extends StatelessWidget {
  final String title;
  final String content;
  final String? directLink;

  const WikiArticleDialog({
    super.key,
    required this.title,
    required this.content,
    this.directLink,
  });

  @override
  Widget build(BuildContext context) {
    // Split content into paragraphs and filter out empty ones
    final paragraphs = content.split('\n').where((p) => p.trim().isNotEmpty).toList();

    return Dialog(
      backgroundColor: const Color(0xFF303030),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFFF1E173),
                    size: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: paragraphs.map((paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      paragraph,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  )).toList(),
                ),
              ),
            ),
            if (directLink != null) ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(Uri.parse(directLink!));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1E173),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Voir l'article complet",
                    style: TextStyle(
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 