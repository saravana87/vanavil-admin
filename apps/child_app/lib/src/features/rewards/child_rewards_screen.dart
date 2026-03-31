import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/firestore_records.dart';

class ChildRewardsScreen extends StatelessWidget {
  const ChildRewardsScreen({super.key, required this.featuredChild});

  final ChildProfile featuredChild;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Points hero card ──
          _PointsHeroCard(totalPoints: featuredChild.totalPoints),

          const SizedBox(height: 24),

          // ── Badges section ──
          _SectionHeader(
            icon: Icons.emoji_events_rounded,
            color: VanavilPalette.sun,
            title: 'My Badges',
          ),
          const SizedBox(height: 12),
          _BadgesGrid(childId: featuredChild.id),

          const SizedBox(height: 24),

          // ── Points history section ──
          _SectionHeader(
            icon: Icons.history_rounded,
            color: VanavilPalette.leaf,
            title: 'Points History',
          ),
          const SizedBox(height: 12),
          _PointsHistory(childId: featuredChild.id),

          const SizedBox(height: 24),

          // ── Completed tasks section ──
          _SectionHeader(
            icon: Icons.task_alt_rounded,
            color: VanavilPalette.sky,
            title: 'Completed Tasks',
          ),
          const SizedBox(height: 12),
          _CompletedTasks(childId: featuredChild.id),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Points hero card
// ═══════════════════════════════════════════════════════════════════════════

class _PointsHeroCard extends StatelessWidget {
  const _PointsHeroCard({required this.totalPoints});

  final int totalPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VanavilPalette.sun, Color(0xFFFFD54F), Color(0xFFFFE082)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: VanavilPalette.sun.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Points',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalPoints',
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every task you finish earns more!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section header
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Badges grid
// ═══════════════════════════════════════════════════════════════════════════

const _badgeColors = [
  VanavilPalette.sun,
  VanavilPalette.berry,
  VanavilPalette.sky,
  VanavilPalette.leaf,
  VanavilPalette.coral,
  VanavilPalette.lavender,
];

class _BadgesGrid extends StatelessWidget {
  const _BadgesGrid({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.childBadges)
          .where('childId', isEqualTo: childId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CompactErrorCard(message: snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptySection(
            icon: Icons.emoji_events_rounded,
            message: 'No badges yet. Complete tasks to earn your first badge!',
          );
        }

        final badges = docs.map(ChildBadgeRecord.fromSnapshot).toList();
        badges.sort((a, b) {
          final aDate = a.awardedAt;
          final bDate = b.awardedAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: badges.length,
          itemBuilder: (context, index) {
            final badge = badges[index];
            final color = _badgeColors[index % _badgeColors.length];
            return _BadgeCard(badge: badge, color: color);
          },
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.color});

  final ChildBadgeRecord badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.badgeTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: VanavilPalette.ink,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Points history
// ═══════════════════════════════════════════════════════════════════════════

class _PointsHistory extends StatelessWidget {
  const _PointsHistory({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.pointsLedger)
          .where('childId', isEqualTo: childId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CompactErrorCard(message: snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptySection(
            icon: Icons.history_rounded,
            message: 'No points earned yet. Complete your first task to start!',
          );
        }

        final entries = docs.map(PointsLedgerRecord.fromSnapshot).toList();
        entries.sort((left, right) {
          final leftDate = left.createdAt;
          final rightDate = right.createdAt;
          if (leftDate == null && rightDate == null) {
            return left.reason.compareTo(right.reason);
          }
          if (leftDate == null) return 1;
          if (rightDate == null) return -1;
          return rightDate.compareTo(leftDate);
        });
        final visibleEntries = entries.take(10).toList(growable: false);

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleEntries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = visibleEntries[index];
            return _PointsEntryCard(entry: entry);
          },
        );
      },
    );
  }
}

class _PointsEntryCard extends StatelessWidget {
  const _PointsEntryCard({required this.entry});

  final PointsLedgerRecord entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VanavilPalette.leaf.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [VanavilPalette.leaf, Color(0xFF81C784)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+${entry.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason.isNotEmpty ? entry.reason : 'Points awarded',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: VanavilPalette.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatDueLabel(entry.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: VanavilPalette.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Completed tasks
// ═══════════════════════════════════════════════════════════════════════════

class _CompletedTasks extends StatelessWidget {
  const _CompletedTasks({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.assignments)
          .where('childId', isEqualTo: childId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CompactErrorCard(message: snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final completed = docs
            .map(ChildAssignmentRecord.fromSnapshot)
            .where(
              (r) =>
                  r.status == AssignmentStatus.approved ||
                  r.status == AssignmentStatus.completed,
            )
            .toList();

        completed.sort((a, b) {
          final aDate = a.submittedAt ?? a.createdAt;
          final bDate = b.submittedAt ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        if (completed.isEmpty) {
          return _EmptySection(
            icon: Icons.task_alt_rounded,
            message: 'No completed tasks yet. Keep working on your tasks!',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: completed.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = completed[index];
            return _CompletedTaskCard(record: record);
          },
        );
      },
    );
  }
}

class _CompletedTaskCard extends StatelessWidget {
  const _CompletedTaskCard({required this.record});

  final ChildAssignmentRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: VanavilPalette.leaf,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.taskTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: VanavilPalette.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatDueLabel(record.submittedAt ?? record.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: VanavilPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: VanavilPalette.leaf.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+${record.rewardPoints}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: VanavilPalette.leaf,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared compact widgets
// ═══════════════════════════════════════════════════════════════════════════

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VanavilPalette.creamSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: VanavilPalette.inkSoft.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: VanavilPalette.inkSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactErrorCard extends StatelessWidget {
  const _CompactErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VanavilPalette.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: VanavilPalette.coral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: VanavilPalette.inkSoft,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
