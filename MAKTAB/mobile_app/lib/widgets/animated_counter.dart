import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  final int count;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.count,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: count.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          value.toInt().toString(),
          style: style,
        );
      },
    );
  }
}
