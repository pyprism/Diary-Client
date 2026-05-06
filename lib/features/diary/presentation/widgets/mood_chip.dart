import 'package:flutter/material.dart';

class MoodChip extends StatelessWidget {
  final String mood;
  const MoodChip({super.key, required this.mood});

  @override
  Widget build(BuildContext context) {
    final color = _moodColor(mood);
    return Chip(
      avatar: Icon(_moodIcon(mood), size: 18, color: color),
      label: Text(mood),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  IconData _moodIcon(String mood) => switch (mood.toLowerCase()) {
    'happy' => Icons.sentiment_satisfied_alt,
    'sad' => Icons.sentiment_dissatisfied,
    'nostalgic' => Icons.wb_twilight_outlined,
    'anxious' => Icons.psychology_alt_outlined,
    'excited' => Icons.celebration_outlined,
    'angry' => Icons.sentiment_very_dissatisfied,
    'calm' => Icons.spa_outlined,
    'romantic' => Icons.favorite_outline,
    'reflective' => Icons.psychology_outlined,
    'grateful' => Icons.volunteer_activism_outlined,
    _ => Icons.sentiment_neutral,
  };

  Color _moodColor(String mood) => switch (mood.toLowerCase()) {
    'happy' => Colors.amber,
    'sad' => Colors.blue,
    'nostalgic' => Colors.orange,
    'anxious' => Colors.purple,
    'excited' => Colors.pink,
    'angry' => Colors.red,
    'calm' => Colors.teal,
    'romantic' => Colors.pink,
    'reflective' => Colors.indigo,
    'grateful' => Colors.green,
    _ => Colors.grey,
  };
}
