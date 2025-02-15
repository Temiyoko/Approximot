import 'guess_result.dart';

class GameSession {
  final String code;
  final List<String> playerIds;
  final Map<String, List<GuessResult>> playerGuesses;
  final bool isActive;
  final bool wordFound;
  final List<String> winners;
  final String gameType;

  GameSession({
    required this.code,
    required this.playerIds,
    required this.playerGuesses,
    required this.isActive,
    this.wordFound = false,
    this.winners = const [],
    required this.gameType,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'playerIds': playerIds,
    'playerGuesses': playerGuesses.map(
      (key, value) => MapEntry(key, value.map((g) => g.toJson()).toList())
    ),
    'isActive': isActive,
    'wordFound': wordFound,
    'winners': winners,
    'gameType': gameType,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    code: json['code'],
    playerIds: List<String>.from(json['playerIds']),
    playerGuesses: (json['playerGuesses'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        (value as List).map((g) => GuessResult.fromJson(g)).toList(),
      ),
    ),
    isActive: json['isActive'],
    wordFound: json['wordFound'] ?? false,
    winners: List<String>.from(json['winners'] ?? []),
    gameType: json['gameType'] ?? 'lexitom',
  );
}