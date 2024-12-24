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

  static Future<GameSession> createGameSession(String hostId) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final code = generateGameCode();
    final session = GameSession(
      code: code,
      hostId: user.uid,
      playerIds: [user.uid],
      playerGuesses: {user.uid: []},
      createdAt: DateTime.now(),
      isActive: true,
      currentUserId: user.uid,
    );

    final batch = _db.batch();
    
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final activeGame = userDoc.data()?['activeGame'];
      
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
              'playerGuesses.${user.uid}': FieldValue.delete(),
            });
          }
        }
      }
    }

    batch.set(_db.collection('game_sessions').doc(code), session.toJson());
    batch.set(_db.collection('users').doc(user.uid), {
      'activeGame': code
    }, SetOptions(merge: true));

    await batch.commit();

    return session;
  }

  static Future<GameSession?> joinGameSession(String code, String playerId) async {
    final doc = await _db.collection('game_sessions').doc(code).get();
    if (!doc.exists) return null;

    final session = GameSession.fromJson(doc.data()!);
    if (!session.isActive) return null;

    final batch = _db.batch();
    
    final userDoc = await _db.collection('users').doc(playerId).get();
    if (userDoc.exists) {
      final activeGame = userDoc.data()?['activeGame'];
      
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
              'playerGuesses.$playerId': FieldValue.delete(),
            });
          }
        }
      }
    }

    batch.update(_db.collection('game_sessions').doc(code), {
      'playerIds': FieldValue.arrayUnion([playerId]),
      'playerGuesses.$playerId': [],
    });

    batch.set(_db.collection('users').doc(playerId), {
      'activeGame': code
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
    await _db.collection('game_sessions').doc(code).update({
      'playerGuesses.$playerId': FieldValue.arrayUnion([guess.toJson()]),
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> leaveGame(String code) async {
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

      if (remainingPlayers.isEmpty) {
        batch.delete(_db.collection('game_sessions').doc(code));
      } else {
        batch.update(_db.collection('game_sessions').doc(code), {
          'playerIds': FieldValue.arrayRemove([user.uid]),
          'playerGuesses.${user.uid}': FieldValue.delete(),
        });
      }

      if (userDoc.exists) {
        batch.update(_db.collection('users').doc(user.uid), {
          'activeGame': null
        });
      } else {
        await AuthService.createUserDocument(user);
        batch.update(_db.collection('users').doc(user.uid), {
          'activeGame': null
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
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> clearAllGuesses(String code) async {
    final gameDoc = await _db.collection('game_sessions').doc(code).get();
    if (!gameDoc.exists) return;

    await _db.collection('game_sessions').doc(code).update({
      'playerGuesses': {},
      'wordFound': false,
      'winners': [],
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }
} 