import 'package:flutter/material.dart';
import '../atoms/card_atom.dart';

class BatchListTile extends StatelessWidget {
  final String name;
  final String timing;
  final int studentCount;
  final VoidCallback onTap;

  const BatchListTile({
    super.key,
    required this.name,
    required this.timing,
    required this.studentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CardAtom(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 4),
              Text(timing, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF9FBE7),
            ),
            child: Text(
              '$studentCount',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
            ),
          )
        ],
      ),
    );
  }
}