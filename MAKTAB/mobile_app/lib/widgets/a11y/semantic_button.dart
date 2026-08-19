import 'package:flutter/material.dart';
import '../atoms/custom_button.dart';

class SemanticButton extends StatelessWidget {
  final String label;
  final String hint;
  final VoidCallback onPressed;

  const SemanticButton({
    super.key,
    required this.label,
    required this.hint,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: CustomButton(
        text: label,
        onPressed: onPressed,
      ),
    );
  }
}