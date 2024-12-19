import 'package:cloud_firestore/cloud_firestore.dart';
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
    );

    final batch = _db.batch();
    batch.set(_db.collection('game_sessions').doc(code), session.toJson());
    batch.update(_db.collection('users').doc(user.uid), {
      'activeGames': FieldValue.arrayUnion([code])
    });
    await batch.commit();

    return session;
  }

  static Future<GameSession?> joinGameSession(String code, String playerId) async {
    final doc = await _db.collection('game_sessions').doc(code).get();
    if (!doc.exists) return null;

    final session = GameSession.fromJson(doc.data()!);
    if (!session.isActive) return null;

    await _db.collection('game_sessions').doc(code).update({
      'playerIds': FieldValue.arrayUnion([playerId]),
      'playerGuesses.$playerId': [],
    });

    return GameSession.fromJson((await doc.reference.get()).data()!);
  }

  static Stream<GameSession> watchGameSession(String code) {
    return _db.collection('game_sessions')
        .doc(code)
        .snapshots()
        .map((doc) => GameSession.fromJson(doc.data()!));
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

    final batch = _db.batch();
    batch.update(_db.collection('game_sessions').doc(code), {
      'playerIds': FieldValue.arrayRemove([user.uid])
    });
    batch.update(_db.collection('users').doc(user.uid), {
      'activeGames': FieldValue.arrayRemove([code])
    });
    await batch.commit();
  }
} 