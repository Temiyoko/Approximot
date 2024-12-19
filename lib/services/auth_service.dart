import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user getter
  static User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Create or update user document
  static Future<void> _updateUserData(User user) async {
    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName ?? 'User',
      'photoURL': user.photoURL,
      'lastSeen': FieldValue.serverTimestamp(),
      'activeGames': [],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Google Sign In
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

  // Email Sign In
  static Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _updateUserData(userCredential.user!);
    return userCredential;
  }

  // Email Sign Up
  static Future<UserCredential> createUserWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _updateUserData(userCredential.user!);
    return userCredential;
  }

  // Sign Out
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Update user's last seen
  static Future<void> updateUserLastSeen() async {
    if (currentUser != null) {
      await _db.collection('users').doc(currentUser!.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }
} 