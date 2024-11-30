import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';

import 'home_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  String _getUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return "Vous êtes connecté en tant qu'invité";
    }
    return user.email ?? "Vous êtes connecté en tant qu'invité";
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bienvenue !',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _getUserInfo(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 40),
            // Bouton de déconnexion
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: ElevatedButton(
                onPressed: () => _signOut(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF303030),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 6,
                  minimumSize: Size(screenWidth * 0.8, 48),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
        color: const Color(0xFF303030),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.mode_edit_outline, size: 24),
                color: Colors.white,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onPressed: () {
                  print("Clicked on Lexitom");
                },
              ),
            ),
            IconButton(
              icon: SvgPicture.asset(
                'assets/images/wikitom_logo.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.white30,
                  BlendMode.srcIn,
                ),
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () {
                print("Clicked on Wikitom");
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 24),
              color: Colors.white30,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () {
                print("Clicked on Settings");
              },
            ),
          ],
        ),
      ),
    );
  }
} 