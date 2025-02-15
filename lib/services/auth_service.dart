import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<void> _updateUserData(User user) async {
    await _db.collection('users').doc(user.uid).set({
      'displayName': user.displayName ?? 'User',
      'email': user.email,
      'photoURL': user.photoURL,
    }, SetOptions(merge: true));
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      await signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw Exception('Connexion Google annulée');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _updateUserData(userCredential.user!);
      return userCredential;
    } catch (e) {
      throw Exception('Erreur lors de la connexion Google, veuillez réessayer');
    }
  }

  static Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        await createUserDocument(credential.user!);
      }
      
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  static Future<UserCredential> createUserWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await createUserDocument(userCredential.user!);
    return userCredential;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  static Future<void> createUserDocument(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'activeGames': {},
        'displayName': user.displayName ?? 'User',
        'email': user.email,
        'photoURL': user.photoURL,
        'lexitomGuesses': [],
        'wikitomGuesses': [],
      });
    }
  }

  static Future<void> updateLoginAttempts(String email, {bool reset = false}) async {
    final userQuery = await _db.collection('users').where('email', isEqualTo: email).get();
    if (userQuery.docs.isNotEmpty) {
      final userDoc = userQuery.docs.first;
      await _db.collection('users').doc(userDoc.id).update({
        'loginAttempts': reset ? 0 : FieldValue.increment(1),
        'lastLoginAttempt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<bool> isAccountLocked(String email) async {
    final userQuery = await _db.collection('users').where('email', isEqualTo: email).get();
    if (userQuery.docs.isNotEmpty) {
      final userData = userQuery.docs.first.data();
      final attempts = userData['loginAttempts'] ?? 0;
      final lastAttempt = userData['lastLoginAttempt'] as Timestamp?;
      
      if (attempts >= 3 && lastAttempt != null) {
        final lockoutDuration = const Duration(minutes: 30);
        final now = DateTime.now();
        final lockoutEnd = lastAttempt.toDate().add(lockoutDuration);
        if (now.isBefore(lockoutEnd)) {
          return true;
        } else {
          // Reset attempts after lockout period
          await updateLoginAttempts(email, reset: true);
          return false;
        }
      }
    }
    return false;
  }

  static Future<void> unlockAccount(String email) async {
    final userQuery = await _db.collection('users').where('email', isEqualTo: email).get();
    if (userQuery.docs.isNotEmpty) {
      final userDoc = userQuery.docs.first;
      await _db.collection('users').doc(userDoc.id).update({
        'loginAttempts': 0,
        'lastLoginAttempt': null,
      });
    }
  }
} 