import 'package:flutter/material.dart';

class SemanticText extends StatelessWidget {
  final String text;
  final String semanticLabel;
  final TextStyle? style;

  const SemanticText({
    super.key,
    required this.text,
    required this.semanticLabel,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Text(text, style: style),
    );
  }
}