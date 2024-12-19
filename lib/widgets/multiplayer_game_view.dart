import 'package:flutter/material.dart';
import '../models/game_session.dart';

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
            border: Border.all(
              color: const Color(0xFFF1E173).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Code de partie: ',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Poppins',
                ),
              ),
              SelectableText(
                session.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),

        // Players list
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFF1E173).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Joueurs connectés:',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...session.playerIds.map((playerId) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: playerId == currentUserId
                          ? const Color(0xFFF1E173)
                          : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      playerId == currentUserId ? 'Vous' : 'Joueur ${playerId.substring(0, 4)}',
                      style: TextStyle(
                        color: playerId == currentUserId
                            ? const Color(0xFFF1E173)
                            : Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ],
    );
  }
} 