import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/game_session.dart';
import '../models/guess_result.dart';
import 'auth_service.dart';

class MultiplayerService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static String generateGameCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<GameSession> createGameSession({required String gameType}) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final code = generateGameCode();
    final session = GameSession(
      code: code,
      playerIds: [user.uid],
      playerGuesses: {user.uid: []},
      isActive: true,
      gameType: gameType,
    );

    final batch = _db.batch();
    
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final activeGames = Map<String, String>.from(userDoc.data()?['activeGames'] ?? {});
      final activeGame = activeGames[gameType];
      
      if (activeGame != null) {
        final gameDoc = await _db.collection('game_sessions').doc(activeGame).get();
        if (gameDoc.exists) {
          final gameData = GameSession.fromJson(gameDoc.data()!);
          final remainingPlayers = List<String>.from(gameData.playerIds)
            ..remove(user.uid);

          if (remainingPlayers.isEmpty) {
            batch.delete(_db.collection('game_sessions').doc(activeGame));
          } else {
            batch.update(_db.collection('game_sessions').doc(activeGame), {
              'playerIds': FieldValue.arrayRemove([user.uid]),
            });
          }
        }
      }
    }

    batch.set(_db.collection('game_sessions').doc(code), session.toJson());
    batch.set(_db.collection('users').doc(user.uid), {
      'activeGames': {
        gameType: code
      }
    }, SetOptions(merge: true));

    await batch.commit();

    return session;
  }

  static Future<GameSession?> joinGameSession(String code, String playerId, {required String gameType}) async {
    final doc = await _db.collection('game_sessions').doc(code).get();
    if (!doc.exists) return null;

    final session = GameSession.fromJson(doc.data()!);
    if (!session.isActive || session.gameType != gameType) return null;

    final batch = _db.batch();
    
    final userDoc = await _db.collection('users').doc(playerId).get();
    if (userDoc.exists) {
      final activeGames = Map<String, String>.from(userDoc.data()?['activeGames'] ?? {});
      final activeGame = activeGames[gameType];
      
      if (activeGame != null && activeGame != code) {
        final gameDoc = await _db.collection('game_sessions').doc(activeGame).get();
        if (gameDoc.exists) {
          final gameData = GameSession.fromJson(gameDoc.data()!);
          final remainingPlayers = List<String>.from(gameData.playerIds)
            ..remove(playerId);

          if (remainingPlayers.isEmpty) {
            batch.delete(_db.collection('game_sessions').doc(activeGame));
          } else {
            batch.update(_db.collection('game_sessions').doc(activeGame), {
              'playerIds': FieldValue.arrayRemove([playerId]),
            });
          }
        }
      }

      List<dynamic> guesses = [];
      if (gameType == 'lexitom') {
        guesses = userDoc.data()?['lexitomGuesses'] ?? [];
      } else {
        guesses = userDoc.data()?['wikitomGuesses'] ?? [];
      }
      
      if (guesses.isNotEmpty) {
        batch.update(_db.collection('game_sessions').doc(code), {
          'playerIds': FieldValue.arrayUnion([playerId]),
          'playerGuesses.$playerId': guesses,
        });
      } else {
        batch.update(_db.collection('game_sessions').doc(code), {
          'playerIds': FieldValue.arrayUnion([playerId]),
          'playerGuesses.$playerId': [],
        });
      }
    } else {
      batch.update(_db.collection('game_sessions').doc(code), {
        'playerIds': FieldValue.arrayUnion([playerId]),
        'playerGuesses.$playerId': [],
      });
    }

    batch.set(_db.collection('users').doc(playerId), {
      'activeGames': {
        gameType: code
      }
    }, SetOptions(merge: true));

    await batch.commit();

    return GameSession.fromJson((await doc.reference.get()).data()!);
  }

  static Stream<GameSession?> watchGameSession(String code) {
    return _db.collection('game_sessions')
        .doc(code)
        .snapshots()
        .map((doc) {
          return doc.exists ? GameSession.fromJson(doc.data()!) : null;
        });
  }

  static Future<void> addGuess(String code, String playerId, GuessResult guess) async {
    final sessionDoc = await _db.collection('game_sessions').doc(code).get();
    if (!sessionDoc.exists) return;

    final sessionData = sessionDoc.data()!;
    final playerGuesses = sessionData['playerGuesses'] as Map<String, dynamic>;
    final existingGuesses = playerGuesses[playerId] as List<dynamic>? ?? [];

    if (existingGuesses.any((g) => GuessResult.fromJson(g).word == guess.word)) {
      return;
    }

    await _db.collection('game_sessions').doc(code).update({
      'playerGuesses.$playerId': FieldValue.arrayUnion([guess.toJson()]),
    });
  }

  static Future<void> leaveGame(String code, {required String gameType}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final gameDoc = await _db.collection('game_sessions').doc(code).get();
      
      if (!gameDoc.exists) {
        return;
      }

      final batch = _db.batch();
      
      final gameData = GameSession.fromJson(gameDoc.data()!);
      final remainingPlayers = List<String>.from(gameData.playerIds)
        ..remove(user.uid);

      final allGuesses = <GuessResult>{};
      
      for (final entry in gameData.playerGuesses.entries) {
        for (final guess in entry.value) {
          if (!guess.isCorrect || entry.key == user.uid || gameData.winners.contains(user.uid)) {
            allGuesses.add(guess);
          }
        }
      }

      if (allGuesses.isNotEmpty) {
        if (userDoc.exists) {
          final existingGuesses = gameType == 'lexitom'
              ? (userDoc.data()?['lexitomGuesses'] as List? ?? [])
                  .map((g) => GuessResult.fromJson(g))
                  .toList()
              : (userDoc.data()?['wikitomGuesses'] as List? ?? [])
                  .map((g) => GuessResult.fromJson(g))
                  .toList();

          for (final guess in allGuesses) {
            if (!existingGuesses.any((g) => g.word == guess.word)) {
              existingGuesses.add(guess);
            }
          }

          batch.update(_db.collection('users').doc(user.uid), {
            gameType == 'lexitom' ? 'lexitomGuesses' : 'wikitomGuesses': 
                existingGuesses.map((g) => g.toJson()).toList(),
          });
        } else {
          await AuthService.createUserDocument(user);
          batch.update(_db.collection('users').doc(user.uid), {
            gameType == 'lexitom' ? 'lexitomGuesses' : 'wikitomGuesses': 
                allGuesses.toList().map((g) => g.toJson()).toList(),
          });
        }
      }

      if (remainingPlayers.isEmpty) {
        batch.delete(_db.collection('game_sessions').doc(code));
      } else {
        batch.update(_db.collection('game_sessions').doc(code), {
          'playerIds': FieldValue.arrayRemove([user.uid]),
        });
      }

      if (userDoc.exists) {
        batch.update(_db.collection('users').doc(user.uid), {
          'activeGames.$gameType': FieldValue.delete()
        });
      } else {
        await AuthService.createUserDocument(user);
        batch.update(_db.collection('users').doc(user.uid), {
          'activeGames.$gameType': FieldValue.delete()
        });
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error leaving game: $e');
      }
      rethrow;
    }
  }

  static Future<void> notifyWordFound(String code, String playerId) async {
    await _db.collection('game_sessions').doc(code).update({
      'wordFound': true,
      'winners': FieldValue.arrayUnion([playerId]),
    });
  }
} 