import 'package:flutter/material.dart';
import '../widgets/custom_bottom_bar.dart';
import '../../utils/page_transitions.dart';
import 'lexitom_screen.dart';
import 'wikitom_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          'Settings Screen',
          style: TextStyle(color: Colors.white),
        ),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pushReplacement(
              context,
              PageTransitions.slideTransition(
                switch (index) {
                  0 => const MainScreen(),
                  1 => const WikiGameScreen(),
                  _ => const SettingsScreen(),
                },
              ),
            );
          }
        },
      ),
    );
  }
} 