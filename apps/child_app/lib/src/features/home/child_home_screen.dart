import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/firestore_records.dart';
import '../announcements/child_announcements_screen.dart';
import '../rewards/child_rewards_screen.dart';
import '../tasks/child_task_detail_screen.dart';
import '../tasks/child_task_list_screen.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({
    super.key,
    required this.featuredChild,
    required this.onSwitchProfile,
  });

  final ChildProfile featuredChild;
  final VoidCallback onSwitchProfile;

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Sky gradient background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFD0ECFF),
                  Color(0xFFEFF8FF),
                  VanavilPalette.creamSoft,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // ── Grass strip at bottom ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7ED957), Color(0xFF4FB36B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              VanavilPalette.berry,
                              VanavilPalette.lavender,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: VanavilPalette.berry.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.transparent,
                          child: Text(
                            widget.featuredChild.avatar,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${widget.featuredChild.name}!',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Let\u2019s finish your tasks and earn rewards!',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: widget.onSwitchProfile,
                          icon: const Icon(
                            Icons.switch_account_rounded,
                            color: VanavilPalette.berry,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tab body ──
                Expanded(child: _buildTabBody()),

                // ── Bottom nav ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavIcon(
                          label: 'Home',
                          icon: Icons.home_rounded,
                          color: VanavilPalette.berry,
                          active: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                        _NavIcon(
                          label: 'Tasks',
                          icon: Icons.checklist_rounded,
                          color: VanavilPalette.sky,
                          active: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                        _NavIcon(
                          label: 'Rewards',
                          icon: Icons.stars_rounded,
                          color: VanavilPalette.sun,
                          active: _selectedTab == 2,
                          onTap: () => setState(() => _selectedTab = 2),
                        ),
                        _NavIcon(
                          label: 'News',
                          icon: Icons.campaign_rounded,
                          color: VanavilPalette.coral,
                          active: _selectedTab == 3,
                          onTap: () => setState(() => _selectedTab = 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_selectedTab) {
      0 => _HomeTab(
        featuredChild: widget.featuredChild,
        childId: widget.featuredChild.id,
      ),
      1 => ChildTaskListScreen(childId: widget.featuredChild.id),
      2 => ChildRewardsScreen(featuredChild: widget.featuredChild),
      3 => const ChildAnnouncementsScreen(),
      _ => const SizedBox.shrink(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Home tab
// ═══════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.featuredChild, required this.childId});

  final ChildProfile featuredChild;
  final String childId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Points hero card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  VanavilPalette.berry,
                  VanavilPalette.lavender,
                  VanavilPalette.sky,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: VanavilPalette.berry.withValues(alpha: 0.3),
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
                        'Your Points',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${featuredChild.totalPoints}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Keep going! One more task can unlock your next badge.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section header ──
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: VanavilPalette.sky,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Today\u2019s Tasks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Firestore task list ──
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.assignments)
                  .where('childId', isEqualTo: childId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: _ErrorCard(message: snapshot.error.toString()),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final records = docs
                    .map(ChildAssignmentRecord.fromSnapshot)
                    .where(
                      (r) =>
                          r.status == AssignmentStatus.assigned ||
                          r.status == AssignmentStatus.submitted ||
                          r.status == AssignmentStatus.rejected,
                    )
                    .toList();
                records.sort((left, right) {
                  final leftDate = left.dueDate;
                  final rightDate = right.dueDate;
                  if (leftDate == null && rightDate == null) {
                    return left.taskTitle.compareTo(right.taskTitle);
                  }
                  if (leftDate == null) {
                    return 1;
                  }
                  if (rightDate == null) {
                    return -1;
                  }
                  return leftDate.compareTo(rightDate);
                });

                if (records.isEmpty) {
                  return const _EmptyHomeState();
                }

                return ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _HomeTaskCard(
                      record: record,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChildTaskDetailScreen(
                              assignment: record,
                              childId: childId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Home task card — colorful, child-friendly
// ═══════════════════════════════════════════════════════════════════════════

const _cardGradients = [
  [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], // blue tint
  [Color(0xFFFCE4EC), Color(0xFFF8BBD0)], // pink tint
  [Color(0xFFF3E5F5), Color(0xFFE1BEE7)], // purple tint
  [Color(0xFFE8F5E9), Color(0xFFC8E6C9)], // green tint
  [Color(0xFFFFF8E1), Color(0xFFFFECB3)], // yellow tint
];

class _HomeTaskCard extends StatelessWidget {
  const _HomeTaskCard({required this.record, required this.onTap});

  final ChildAssignmentRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradientColors =
        _cardGradients[record.taskTitle.length % _cardGradients.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Task icon circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _taskIcon(record.status),
                color: _statusAccent(record.status),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Title + due
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.taskTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: VanavilPalette.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDueLabel(record.dueDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: VanavilPalette.inkSoft,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Status chip
            VanavilStatusChip(status: record.status),

            const SizedBox(width: 10),

            // Points badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [VanavilPalette.leaf, Color(0xFF81C784)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: VanavilPalette.leaf.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '+${record.rewardPoints}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _taskIcon(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => Icons.assignment_rounded,
      AssignmentStatus.submitted => Icons.upload_rounded,
      AssignmentStatus.approved => Icons.check_circle_rounded,
      AssignmentStatus.completed => Icons.task_alt_rounded,
      AssignmentStatus.rejected => Icons.refresh_rounded,
    };
  }

  static Color _statusAccent(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => VanavilPalette.sky,
      AssignmentStatus.submitted => VanavilPalette.sun,
      AssignmentStatus.approved => VanavilPalette.leaf,
      AssignmentStatus.completed => VanavilPalette.leaf,
      AssignmentStatus.rejected => VanavilPalette.coral,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty / Error states
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyHomeState extends StatelessWidget {
  const _EmptyHomeState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: VanavilPalette.sun.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 38,
              color: VanavilPalette.sun,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: VanavilPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No active tasks right now.\nEnjoy your free time!',
            textAlign: TextAlign.center,
            style: TextStyle(color: VanavilPalette.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VanavilPalette.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VanavilPalette.coral.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: VanavilPalette.coral,
          ),
          const SizedBox(height: 12),
          const Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: VanavilPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: VanavilPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Placeholder tab
// ═══════════════════════════════════════════════════════════════════════════

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: VanavilPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VanavilPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom nav icon — colorful when active
// ═══════════════════════════════════════════════════════════════════════════

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.label,
    required this.icon,
    required this.color,
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: active
            ? BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? color : VanavilPalette.inkSoft,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? color : VanavilPalette.inkSoft,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
