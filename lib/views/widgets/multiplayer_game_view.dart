import 'package:flutter/material.dart';
import '../../models/game_session.dart';

class MultiplayerGameView extends StatelessWidget {
  final GameSession session;
  final String currentUserId;

  const MultiplayerGameView({
    super.key,
    required this.session,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Game code display
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Code de partie: ',
                style: TextStyle(color: Colors.white70),
              ),
              SelectableText(
                session.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Players' guesses
        ...session.playerIds.map((playerId) {
          final guesses = session.playerGuesses[playerId] ?? [];
          if (guesses.isEmpty) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: playerId == currentUserId 
                    ? const Color(0xFFF1E173).withOpacity(0.3)
                    : Colors.white24,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    playerId == currentUserId ? 'Vos propositions' : 'Joueur ${playerId.substring(0, 4)}',
                    style: TextStyle(
                      color: playerId == currentUserId 
                          ? const Color(0xFFF1E173)
                          : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...guesses.map((guess) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        guess.word,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '${(guess.similarity * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: guess.isCorrect ? Colors.green : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
} 