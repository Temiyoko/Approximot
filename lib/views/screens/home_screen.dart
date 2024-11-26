import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
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
                          'assets/images/logo.png',
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
                      // Bouton "Se connecter"
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                        child: ElevatedButton(
                          onPressed: () {
                            // Action à faire en cas de click
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
                            'Se connecter',
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
                          onPressed: () {
                            // Action en cas de click
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
                        onPressed: () {
                          // Action en cas de click
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          splashFactory: NoSplash.splashFactory,
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                        child: const Text(
                          "Jouer en tant qu'invité",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
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
