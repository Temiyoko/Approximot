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
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
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
    return AnimatedScale(
      scale: isSelected ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
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
          icon: Icon(
            icon,
            size: 24,
          ),
          color: isSelected ? Colors.white : Colors.white30,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          tooltip: _getTooltipText(index),
          onPressed: () => onTap(index),
        ),
      ),
    );
  }

  Widget _buildWikiIcon(int index) {
    final bool isSelected = currentIndex == index;
    return AnimatedScale(
      scale: isSelected ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
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
          tooltip: _getTooltipText(index),
          onPressed: () => onTap(index),
        ),
      ),
    );
  }

  String _getTooltipText(int index) {
    return switch (index) {
      0 => 'Lexitom',
      1 => 'Wikitom',
      2 => 'Settings',
      _ => '',
    };
  }
}