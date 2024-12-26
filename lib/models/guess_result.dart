class GuessResult {
  final String word;
  final double similarity;
  final bool isCorrect;

  GuessResult({
    required this.word,
    required this.similarity,
    required this.isCorrect,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'similarity': similarity,
    'isCorrect': isCorrect,
  };

  factory GuessResult.fromJson(Map<String, dynamic> json) => GuessResult(
    word: json['word'] as String,
    similarity: (json['similarity'] is int) ? (json['similarity'] as int).toDouble() : json['similarity'] as double,
    isCorrect: json['isCorrect'] as bool,
  );
} 