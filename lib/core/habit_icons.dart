import 'package:flutter/material.dart';

/// Icons a habit can use. The key is what gets stored in the database, so
/// existing keys must never be renamed.
const habitIcons = <String, IconData>{
  'check': Icons.check_rounded,
  'water': Icons.water_drop_rounded,
  'book': Icons.menu_book_rounded,
  'run': Icons.directions_run_rounded,
  'walk': Icons.directions_walk_rounded,
  'gym': Icons.fitness_center_rounded,
  'meditate': Icons.self_improvement_rounded,
  'sleep': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded,
  'fruit': Icons.apple_rounded,
  'code': Icons.code_rounded,
  'language': Icons.translate_rounded,
  'music': Icons.music_note_rounded,
  'write': Icons.edit_rounded,
  'plant': Icons.local_florist_rounded,
  'clean': Icons.cleaning_services_rounded,
  'money': Icons.savings_rounded,
  'phone': Icons.phonelink_erase_rounded,
};

IconData habitIcon(String key) => habitIcons[key] ?? Icons.check_rounded;
