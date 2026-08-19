import 'package:flutter/material.dart';

class DividerAtom extends StatelessWidget {
  const DividerAtom({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: Colors.grey,
      height: 1.0,
      thickness: 0.5,
    );
  }
}