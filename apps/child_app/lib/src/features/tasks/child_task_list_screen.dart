import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/firestore_records.dart';
import 'child_task_detail_screen.dart';

enum _TaskFilter { active, completed }

class ChildTaskListScreen extends StatefulWidget {
  const ChildTaskListScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ChildTaskListScreen> createState() => _ChildTaskListScreenState();
}

class _ChildTaskListScreenState extends State<ChildTaskListScreen> {
  _TaskFilter _filter = _TaskFilter.active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter toggle ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              _FilterChip(
                label: 'Active',
                icon: Icons.assignment_rounded,
                selected: _filter == _TaskFilter.active,
                color: VanavilPalette.sky,
                onTap: () => setState(() => _filter = _TaskFilter.active),
              ),
              const SizedBox(width: 10),
              _FilterChip(
                label: 'Completed',
                icon: Icons.task_alt_rounded,
                selected: _filter == _TaskFilter.completed,
                color: VanavilPalette.leaf,
                onTap: () => setState(() => _filter = _TaskFilter.completed),
              ),
            ],
          ),
        ),

        // ── Task list ──
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.assignments)
                .where('childId', isEqualTo: widget.childId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorBody(message: snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const _EmptyBody();
              }

              final all = docs.map(ChildAssignmentRecord.fromSnapshot).toList();

              final records = _filter == _TaskFilter.active
                  ? all
                        .where(
                          (r) =>
                              r.status == AssignmentStatus.assigned ||
                              r.status == AssignmentStatus.submitted ||
                              r.status == AssignmentStatus.rejected,
                        )
                        .toList()
                  : all
                        .where(
                          (r) =>
                              r.status == AssignmentStatus.approved ||
                              r.status == AssignmentStatus.completed,
                        )
                        .toList();

              records.sort((left, right) {
                final leftDate = left.dueDate;
                final rightDate = right.dueDate;
                if (leftDate == null && rightDate == null) {
                  return left.taskTitle.compareTo(right.taskTitle);
                }
                if (leftDate == null) return 1;
                if (rightDate == null) return -1;
                if (_filter == _TaskFilter.completed) {
                  return rightDate.compareTo(leftDate);
                }
                return leftDate.compareTo(rightDate);
              });

              if (records.isEmpty) {
                return _filter == _TaskFilter.completed
                    ? const _EmptyBodyMessage(
                        icon: Icons.task_alt_rounded,
                        color: VanavilPalette.leaf,
                        title: 'No completed tasks yet',
                        subtitle:
                            'Tasks you finish will appear here.\nKeep going!',
                      )
                    : const _EmptyBody();
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _TaskCard(
                    record: record,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChildTaskDetailScreen(
                            assignment: record,
                            childId: widget.childId,
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
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : Colors.transparent,
          ),
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? color : VanavilPalette.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : VanavilPalette.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Colorful task card ────────────────────────────────────────────────────

const _statusGradients = <AssignmentStatus, List<Color>>{
  AssignmentStatus.assigned: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
  AssignmentStatus.submitted: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
  AssignmentStatus.approved: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
  AssignmentStatus.completed: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
  AssignmentStatus.rejected: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
};

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.record, required this.onOpen});

  final ChildAssignmentRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final gradient =
        _statusGradients[record.status] ??
        const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)];

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _statusIcon(record.status),
                color: _statusColor(record.status),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Title + due + status
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: VanavilPalette.inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          formatDueLabel(record.dueDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: VanavilPalette.inkSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  VanavilStatusChip(status: record.status),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Points badge + arrow
            Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: VanavilPalette.inkSoft,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _statusIcon(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => Icons.assignment_rounded,
      AssignmentStatus.submitted => Icons.upload_rounded,
      AssignmentStatus.approved => Icons.check_circle_rounded,
      AssignmentStatus.completed => Icons.task_alt_rounded,
      AssignmentStatus.rejected => Icons.refresh_rounded,
    };
  }

  static Color _statusColor(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => VanavilPalette.sky,
      AssignmentStatus.submitted => VanavilPalette.sun,
      AssignmentStatus.approved => VanavilPalette.leaf,
      AssignmentStatus.completed => VanavilPalette.leaf,
      AssignmentStatus.rejected => VanavilPalette.coral,
    };
  }
}

// ── Parameterised empty state ─────────────────────────────────────────────

class _EmptyBodyMessage extends StatelessWidget {
  const _EmptyBodyMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: VanavilPalette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VanavilPalette.inkSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VanavilPalette.sky.withValues(alpha: 0.2),
                    VanavilPalette.lavender.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.checklist_rounded,
                size: 40,
                color: VanavilPalette.sky,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tasks yet!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: VanavilPalette.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When your parent assigns tasks,\nthey will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VanavilPalette.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: VanavilPalette.coral.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: VanavilPalette.coral.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: VanavilPalette.coral.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 30,
                  color: VanavilPalette.coral,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: VanavilPalette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: VanavilPalette.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
