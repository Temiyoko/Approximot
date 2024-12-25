import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import '../models/guess_result.dart';

class SinglePlayerService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> addGuess(GuessResult guess) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists || userDoc.data()?['singlePlayerGuesses'] == null) {
      await _db.collection('users').doc(user.uid).set({
        'singlePlayerGuesses': [],
      }, SetOptions(merge: true));
    }

    final existingGuesses = userDoc.data()?['singlePlayerGuesses'] as List? ?? [];
    if (existingGuesses.any((g) => GuessResult.fromJson(g).word == guess.word)) {
      return;
    }

    await _db.collection('users').doc(user.uid).update({
      'singlePlayerGuesses': FieldValue.arrayUnion([guess.toJson()]),
    });
  }

  static Future<List<GuessResult>> loadGuesses() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'singlePlayerGuesses': [],
      }, SetOptions(merge: true));
      return [];
    }

    final guesses = doc.data()?['singlePlayerGuesses'] as List?;
    if (guesses == null) {
      await _db.collection('users').doc(user.uid).update({
        'singlePlayerGuesses': [],
      });
      return [];
    }

    return guesses.map((g) => GuessResult.fromJson(g)).toList();
  }

  static Future<void> clearGuesses() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    
    if (!userDoc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'singlePlayerGuesses': [],
      }, SetOptions(merge: true));
      return;
    }

    await _db.collection('users').doc(user.uid).update({
      'singlePlayerGuesses': [],
    });
  }
} 