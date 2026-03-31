import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({
    super.key,
    required this.children,
    required this.onSelected,
  });

  final List<ChildProfile> children;
  final ValueChanged<ChildProfile> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [VanavilPalette.creamSoft, VanavilPalette.sand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose your profile', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Pick your picture and enter your 4-digit PIN to continue.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: child.isActive ? () => onSelected(child) : null,
                        child: VanavilSectionCard(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: VanavilPalette.sky.withValues(alpha: 0.16),
                                foregroundColor: VanavilPalette.ink,
                                child: Text(
                                  child.avatar,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                child.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: VanavilPalette.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${child.totalPoints} points',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}