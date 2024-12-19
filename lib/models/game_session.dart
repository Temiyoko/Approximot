
import 'guess_result.dart';

class GameSession {
  final String code;
  final String hostId;
  final List<String> playerIds;
  final Map<String, List<GuessResult>> playerGuesses;
  final DateTime createdAt;
  final bool isActive;

  GameSession({
    required this.code,
    required this.hostId,
    required this.playerIds,
    required this.playerGuesses,
    required this.createdAt,
    required this.isActive,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'hostId': hostId,
    'playerIds': playerIds,
    'playerGuesses': playerGuesses.map(
      (key, value) => MapEntry(key, value.map((g) => g.toJson()).toList())
    ),
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    code: json['code'],
    hostId: json['hostId'],
    playerIds: List<String>.from(json['playerIds']),
    playerGuesses: (json['playerGuesses'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        (value as List).map((g) => GuessResult.fromJson(g)).toList(),
      ),
    ),
    createdAt: DateTime.parse(json['createdAt']),
    isActive: json['isActive'],
  );
}