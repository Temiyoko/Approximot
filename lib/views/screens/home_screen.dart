import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/google_auth_service.dart';
import 'email_auth_screen.dart';
import 'lexitom_screen.dart';
import '../../utils/page_transitions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    checkEmailVerification();
    checkAuthState();
  }

  void checkAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        if (user.metadata.creationTime?.isAfter(
              DateTime.now().subtract(const Duration(seconds: 10)),
            ) ??
            false) {
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
          (route) => false,
        );
      }
    });
  }

  Future<void> checkEmailVerification() async {
    final auth = FirebaseAuth.instance;
    
    if (auth.isSignInWithEmailLink(Uri.base.toString())) {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('emailForSignIn');
      
      if (email != null) {
        try {
          await auth.signInWithEmailLink(
            email: email,
            emailLink: Uri.base.toString(),
          );

          await prefs.remove('emailForSignIn');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors de la connexion, veuillez réessayer'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(
                  bottom: MediaQuery.of(context).size.height - 100,
                  right: 20,
                  left: 20,
                ),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginScreen();
  }
}

class LoginScreen extends StatelessWidget {
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  LoginScreen({super.key});

  void _handleGuestLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageTransitions.slideTransition(const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  'assets/images/background.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xFF1A1A1A),
                    ],
                    stops: [0, 0.48],
                  ),
                ),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // Logo and Title
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 180),
                        Image.asset(
                          'assets/images/IconNormal.png',
                          height: 96,
                        ),
                        const Text(
                          'Approximot',
                          style: TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Buttons
                  Column(
                    children: [
                      // Bouton "Continuer avec Email"
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageTransitions.slideTransition(const EmailAuthScreen())
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 6,
                            minimumSize: Size(screenWidth * 0.8, 48),
                          ),
                          child: const Text(
                            'Continuer avec Email',
                            style: TextStyle(
                              color: Color(0xFF303030),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 35),
                      // Bouton "Continuer avec Google"
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final userCredential = await _googleAuthService.signInWithGoogle();
                              if (userCredential != null) {
                                if (context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    PageTransitions.slideTransition(const MainScreen()),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Erreur de connexion veuillez réessayer"),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      margin: EdgeInsets.only(
                                        bottom: MediaQuery.of(context).size.height - 100,
                                        right: 20,
                                        left: 20,
                                      ),
                                    ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF303030),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 6,
                            minimumSize: Size(screenWidth * 0.8, 48),
                          ),
                          icon: Image.asset(
                            'assets/images/google_icon.png',
                            height: 24,
                          ),
                          label: const Text(
                            'Continuer avec Google',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Bouton "Jouer en tant qu'invité"
                      TextButton(
                        onPressed: () => _handleGuestLogin(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          splashFactory: NoSplash.splashFactory,
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white,
                                width: 1.0,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                          child: const Text(
                            "Jouer en tant qu'invité",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
