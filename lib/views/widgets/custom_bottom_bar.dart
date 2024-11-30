import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      height: 80,
      color: const Color(0xFF303030),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIcon(0, Icons.mode_edit_outline),
          _buildWikiIcon(1),
          _buildIcon(2, Icons.settings),
        ],
      ),
    );
  }

  Widget _buildIcon(int index, IconData icon) {
    final bool isSelected = currentIndex == index;
    return Container(
      decoration: isSelected ? BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ) : null,
      child: IconButton(
        icon: Icon(icon, size: 24),
        color: isSelected ? Colors.white : Colors.white30,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onPressed: () => onTap(index),
      ),
    );
  }

  Widget _buildWikiIcon(int index) {
    final bool isSelected = currentIndex == index;
    return Container(
      decoration: isSelected ? BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ) : null,
      child: IconButton(
        icon: SvgPicture.asset(
          'assets/images/wikitom_logo.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            isSelected ? Colors.white : Colors.white30,
            BlendMode.srcIn,
          ),
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onPressed: () => onTap(index),
      ),
    );
  }
}