import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const AppIcon({
    super.key,
    required this.icon,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? const Color(0xFF004D40), // Maktab Dark Green
    );
  }
}