import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import './home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.5)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
    ]).animate(_logoController);

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    // Start animations sequence
    _logoController.forward().then((_) {
      _textController.forward();
    });

    // Navigate after animations complete
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Logo
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScaleAnimation.value,
                  child: Opacity(
                    opacity: _logoFadeAnimation.value,
                    child: SvgPicture.asset(
                      'assets/images/bulbResized.svg',
                      width: 120,
                      height: 120,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Animated Text
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _textSlideAnimation.value),
                  child: Opacity(
                    opacity: _textFadeAnimation.value,
                    child: const Text(
                      'Approximot',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 