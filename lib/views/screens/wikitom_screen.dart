import 'package:flutter/material.dart';
import '../widgets/custom_bottom_bar.dart';
import 'lexitom_screen.dart';
import 'settings_screen.dart';

class WikiGameScreen extends StatelessWidget {
  const WikiGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Wikitom',
          style: TextStyle(color: Colors.white),
        ),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 1,
        onTap: (index) {
          if (index != 1) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                  switch (index) {
                    0 => const MainScreen(),
                    2 => const SettingsScreen(),
                    _ => const WikiGameScreen(),
                  },
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        },
      ),
    );
  }
} 