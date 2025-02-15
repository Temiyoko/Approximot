import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../models/guess_result.dart';

class SinglePlayerService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> addGuess(GuessResult guess, {required String gameType}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists || userDoc.data()?[gameType] == null) {
      await _db.collection('users').doc(user.uid).set({
        gameType: [],
      }, SetOptions(merge: true));
    }

    final existingGuesses = userDoc.data()?[gameType] as List? ?? [];
    if (existingGuesses.any((g) => GuessResult.fromJson(g).word == guess.word)) {
      return;
    }

    await _db.collection('users').doc(user.uid).update({
      gameType: FieldValue.arrayUnion([guess.toJson()]),
    });
  }

  static Future<List<GuessResult>> loadGuesses({required String gameType}) async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        gameType: [],
      }, SetOptions(merge: true));
      return [];
    }

    final guesses = doc.data()?[gameType] as List?;
    if (guesses == null) {
      await _db.collection('users').doc(user.uid).update({
        gameType: [],
      });
      return [];
    }

    return guesses.map((g) => GuessResult.fromJson(g)).toList();
  }

  static Future<void> clearGuesses({required String gameType}) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      await _db.collection('users').doc(user.uid).set({
        gameType: [],
      }, SetOptions(merge: true));
      return;
    }

    await _db.collection('users').doc(user.uid).update({
      gameType: [],
    });
  }
} 