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
      'activeGame': null,
      'displayName': user.displayName ?? 'User',
      'email': user.email,
      'lastSeen': FieldValue.serverTimestamp(),
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

  static Future<void> updateUserLastSeen() async {
    if (currentUser != null) {
      await _db.collection('users').doc(currentUser!.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> createUserDocument(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'activeGame': null,
        'createdAt': FieldValue.serverTimestamp(),
        'displayName': user.displayName ?? 'User',
        'email': user.email,
        'lastSeen': FieldValue.serverTimestamp(),
        'photoURL': user.photoURL,
        'singlePlayerGuesses': null,
      });
    }
  }
} 