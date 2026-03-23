library;

import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';

class VanavilPalette {
  static const cream = Color(0xFFFEFEFD);
  static const creamSoft = Color(0xFFFEFBF4);
  static const sand = Color(0xFFFEF9F3);
  static const ink = Color(0xFF2B2A28);
  static const inkSoft = Color(0xFF4C4A46);
  static const sun = Color(0xFFF5B938);
  static const coral = Color(0xFFF46F5E);
  static const leaf = Color(0xFF4FB36B);
  static const sky = Color(0xFF4CA7E8);
  static const berry = Color(0xFFD95AA5);
  static const lavender = Color(0xFF8B7CF6);
}

ThemeData buildAdminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VanavilPalette.sky,
    brightness: Brightness.light,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: VanavilPalette.cream,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: VanavilPalette.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: VanavilPalette.ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: VanavilPalette.inkSoft),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
  );
}

ThemeData buildChildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VanavilPalette.berry,
    brightness: Brightness.light,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: VanavilPalette.sand,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: VanavilPalette.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: VanavilPalette.ink,
      ),
      bodyMedium: TextStyle(fontSize: 15, color: VanavilPalette.inkSoft),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
  );
}

class VanavilStatusChip extends StatelessWidget {
  const VanavilStatusChip({super.key, required this.status});

  final AssignmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, label) = switch (status) {
      AssignmentStatus.assigned => (
        VanavilPalette.sky.withValues(alpha: 0.14),
        'Assigned',
      ),
      AssignmentStatus.submitted => (
        VanavilPalette.sun.withValues(alpha: 0.18),
        'Submitted',
      ),
      AssignmentStatus.approved => (
        VanavilPalette.leaf.withValues(alpha: 0.18),
        'Approved',
      ),
      AssignmentStatus.completed => (
        VanavilPalette.leaf.withValues(alpha: 0.18),
        'Completed',
      ),
      AssignmentStatus.rejected => (
        VanavilPalette.coral.withValues(alpha: 0.18),
        'Needs Fix',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: VanavilPalette.ink,
        ),
      ),
    );
  }
}

class VanavilSectionCard extends StatelessWidget {
  const VanavilSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}
