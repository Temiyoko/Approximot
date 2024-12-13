import 'package:flutter/material.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF252525),
            const Color(0xFF1A1A1A),
            const Color(0xFF252525),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1E173).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: const Color(0xFFF1E173).withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildNavItem(0, Icons.auto_stories_rounded, 'Lexitom'),
            _buildNavItem(1, Icons.psychology_rounded, 'Wikitom'),
            _buildNavItem(2, Icons.settings_rounded, 'Paramètres'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = currentIndex == index;
    const double iconSize = 26;
    
    return Tooltip(
      preferBelow: false,
      verticalOffset: 50,
      message: label,
      textStyle: const TextStyle(
        fontSize: 14,
        fontFamily: 'Poppins',
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF1E173).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.translucent,
        child: SizedBox(
          width: 65,
          height: 85,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: isSelected ? BoxDecoration(
                    color: const Color(0xFF303030),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF1E173).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ) : null,
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: isSelected 
                          ? const Color(0xFFF1E173)
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(top: 6),
                  width: isSelected ? 25 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF1E173),
                        Color(0xFFFFD700),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF1E173).withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}