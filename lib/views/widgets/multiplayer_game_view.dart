import 'package:flutter/material.dart';
import '../../models/game_session.dart';
import '../../services/multiplayer_service.dart';
import '../../services/auth_service.dart';

class MultiplayerGameView extends StatelessWidget {
  final String gameCode;
  final String gameType;

  const MultiplayerGameView({
    super.key, 
    required this.gameCode,
    required this.gameType,
  });

  String _getTemperatureEmoji(double score) {
    if (score < 0) {
      return '🧊';
    } else if (score >= 0 && score < 25) {
      return '❄️';
    } else {
      return '🔥';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GameSession?>(
      stream: MultiplayerService.watchGameSession(gameCode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final session = snapshot.data;
        if (session == null || session.gameType != gameType) {
          return const Center(child: Text('Session not found.'));
        }

        return Column(
          children: [
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
                  Expanded(
                    child: SelectableText(
                      session.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            if (session.wordFound) ...[
              if (session.winners.contains(AuthService.currentUser?.uid)) 
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Félicitations ! Vous avez trouvé le mot !',
                    style: TextStyle(color: Colors.green, fontSize: 18),
                  ),
                )
              else 
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Un joueur a trouvé le mot caché !',
                    style: TextStyle(color: Colors.green, fontSize: 18),
                  ),
                ),
            ],

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
                    color: playerId == AuthService.currentUser?.uid 
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
                        playerId == AuthService.currentUser?.uid ? 'Vos propositions' : 'Joueur ${playerId.substring(0, 4)}',
                        style: TextStyle(
                          color: playerId == AuthService.currentUser?.uid 
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
                          if (gameType == 'lexitom')
                            Text(
                              '${(guess.similarity * 100).toStringAsFixed(1)}° ${_getTemperatureEmoji(guess.similarity * 100)}',
                              style: TextStyle(
                                color: guess.isCorrect ? Colors.green : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Icon(
                              guess.isCorrect ? Icons.check_circle : Icons.close,
                              color: guess.isCorrect ? Colors.green : Colors.red,
                            ),
                        ],
                      ),
                    )),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
} 