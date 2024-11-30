import 'package:flutter/material.dart';
import 'lexitom_screen.dart';
import 'wikitom_screen.dart';
import 'settings_screen.dart';
import '../widgets/custom_bottom_bar.dart';

class MainScreenContainer extends StatefulWidget {
  final int initialIndex;
  
  const MainScreenContainer({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreenContainer> createState() => _MainScreenContainerState();
}

class _MainScreenContainerState extends State<MainScreenContainer> {
  late int _currentIndex;
  final List<Widget> _screens = [
    const MainScreen(),
    const WikiGameScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
} 