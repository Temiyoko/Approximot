import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_bottom_bar.dart';
import 'lexitom_screen.dart';
import 'wikitom_screen.dart';
import 'home_screen.dart';
import '../../utils/page_transitions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        PageTransitions.slideTransitionRightToLeft(const HomeScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    Color iconColor = Colors.white,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showGameRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF303030),
        title: const Text('Règles du jeu', 
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'LexiTom:\n'
                '• Devinez le mot le plus rapidement possible\n'
                '• Chaque essai doit être un mot valide\n'
                '• La couleur des tuiles change pour montrer la proximité avec le mot\n\n'
                'WikiTom:\n'
                '• Devinez le titre d\'une page Wikipédia le plus rapidement possible\n'
                '• Dévoilez petit à petit son contenu\n'
                '• Les mots proches sémantiquement sont affichés en transparence',
                style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', 
              style: TextStyle(color: Colors.blue, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  void _showAboutApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF303030),
        title: const Text('À propos', 
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: const Text(
          'Version: 1.0.0\n\n'
          'Approximot est une collection de jeux de réflexion et de culture générale.\n\n'
          'Développé avec ❤️ par l\'équipe',
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', 
              style: TextStyle(color: Colors.blue, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF303030),
        title: const Text('Bientôt disponible', 
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: const Text(
          'Cette fonctionnalité sera disponible prochainement !',
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', 
              style: TextStyle(color: Colors.blue, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: const Text(
                  'Paramètres',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 20),
        children: [
          _buildSettingsSection(
            'Compte',
            [
              _buildSettingsTile(
                title: _getUserInfo(),
                icon: Icons.person,
                iconColor: const Color(0xFFFECC79),
                onTap: FirebaseAuth.instance.currentUser != null 
                  ? () => _showComingSoon(context)
                  : null,
                trailing: FirebaseAuth.instance.currentUser != null
                  ? const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16)
                  : null,
              ),
            ],
          ),
          _buildSettingsSection(
            'Jeux',
            [
              _buildSettingsTile(
                title: 'Règles des jeux',
                icon: Icons.rule,
                iconColor: const Color(0xFFEDA95D),
                onTap: () => _showGameRules(context),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ),
            ],
          ),
          _buildSettingsSection(
            'Application',
            [
              _buildSettingsTile(
                title: 'À propos',
                icon: Icons.info,
                iconColor: const Color(0xFFD37D3A),
                onTap: () => _showAboutApp(context),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.1),
            child: ElevatedButton(
              onPressed: () => _signOut(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF303030),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 6,
                minimumSize: Size(MediaQuery.of(context).size.width * 0.8, 48),
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
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => 
                  switch (index) {
                    0 => const MainScreen(),
                    1 => const WikiGameScreen(),
                    _ => const SettingsScreen(),
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