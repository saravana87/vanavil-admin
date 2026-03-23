import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../children/manage_children_screen.dart';
import '../reviews/manage_reviews_screen.dart';
import '../tasks/manage_tasks_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.bootstrap});

  final VanavilFirebaseBootstrap bootstrap;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  _AdminSection _selectedSection = _AdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248,
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VANAVIL',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: VanavilPalette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin control center',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VanavilPalette.creamSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.email ?? 'Signed in',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: VanavilPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.bootstrap.statusLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                for (final item in _AdminSection.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSection = item;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        backgroundColor: _selectedSection == item
                            ? VanavilPalette.sky.withValues(alpha: 0.12)
                            : Colors.transparent,
                        foregroundColor: VanavilPalette.ink,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(item.label),
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_selectedSection) {
                _AdminSection.dashboard => _DashboardOverview(
                  key: const ValueKey(_AdminSection.dashboard),
                  bootstrap: widget.bootstrap,
                  onOpenChildren: () {
                    setState(() {
                      _selectedSection = _AdminSection.children;
                    });
                  },
                  onOpenTasks: () {
                    setState(() {
                      _selectedSection = _AdminSection.tasks;
                    });
                  },
                  onOpenReviews: () {
                    setState(() {
                      _selectedSection = _AdminSection.reviews;
                    });
                  },
                ),
                _AdminSection.children => const ManageChildrenScreen(
                  key: ValueKey(_AdminSection.children),
                ),
                _AdminSection.reviews => const ManageReviewsScreen(
                  key: ValueKey(_AdminSection.reviews),
                ),
                _AdminSection.tasks => const ManageTasksScreen(
                  key: ValueKey(_AdminSection.tasks),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _AdminSection {
  dashboard('Dashboard'),
  children('Children'),
  reviews('Reviews'),
  tasks('Tasks');

  const _AdminSection(this.label);

  final String label;
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    super.key,
    required this.bootstrap,
    required this.onOpenChildren,
    required this.onOpenReviews,
    required this.onOpenTasks,
  });

  final VanavilFirebaseBootstrap bootstrap;
  final VoidCallback onOpenChildren;
  final VoidCallback onOpenReviews;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Sign in again to continue.'));
    }

    final childrenStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.children)
        .where('adminId', isEqualTo: currentUserId)
        .snapshots();

    final adminAssignmentsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.assignments)
        .where('assignedBy', isEqualTo: currentUserId)
        .snapshots();

    final announcementsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.announcements)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: childrenStream,
        builder: (context, childrenSnapshot) {
          if (childrenSnapshot.hasError) {
            return _DashboardErrorState(
              title: 'Unable to load children',
              message: childrenSnapshot.error.toString(),
            );
          }

          if (childrenSnapshot.connectionState == ConnectionState.waiting &&
              !childrenSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final children =
              childrenSnapshot.data?.docs
                  .map(_AdminChildSummary.fromSnapshot)
                  .toList() ??
              <_AdminChildSummary>[];
          children.sort(
            (left, right) => right.totalPoints.compareTo(left.totalPoints),
          );

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: adminAssignmentsStream,
            builder: (context, pendingSnapshot) {
              if (pendingSnapshot.hasError) {
                return _DashboardErrorState(
                  title: 'Unable to load review queue',
                  message: pendingSnapshot.error.toString(),
                );
              }

              final adminAssignments =
                  pendingSnapshot.data?.docs
                      .map(_PendingAssignmentItem.fromSnapshot)
                      .toList() ??
                  <_PendingAssignmentItem>[];

              final pendingAssignments = adminAssignments
                  .where((item) => item.status == AssignmentStatus.submitted)
                  .toList();

              pendingAssignments.sort((left, right) {
                final leftDate = left.sortDate;
                final rightDate = right.sortDate;
                if (leftDate == null && rightDate == null) {
                  return left.title.compareTo(right.title);
                }
                if (leftDate == null) return 1;
                if (rightDate == null) return -1;
                return rightDate.compareTo(leftDate);
              });

              final openAssignments = adminAssignments
                  .where(
                    (item) =>
                        item.status == AssignmentStatus.assigned ||
                        item.status == AssignmentStatus.rejected ||
                        item.status == AssignmentStatus.submitted,
                  )
                  .length;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: announcementsStream,
                builder: (context, announcementSnapshot) {
                  if (announcementSnapshot.hasError) {
                    return _DashboardErrorState(
                      title: 'Unable to load announcements',
                      message: announcementSnapshot.error.toString(),
                    );
                  }

                  final announcements =
                      announcementSnapshot.data?.docs
                          .map(_AnnouncementItem.fromSnapshot)
                          .where((item) => item.status != 'draft')
                          .toList() ??
                      <_AnnouncementItem>[];
                  announcements.sort((left, right) {
                    final leftDate = left.visibilityDate;
                    final rightDate = right.visibilityDate;
                    if (leftDate == null && rightDate == null) {
                      return left.title.compareTo(right.title);
                    }
                    if (leftDate == null) return 1;
                    if (rightDate == null) return -1;
                    return rightDate.compareTo(leftDate);
                  });

                  final totalPoints = children.fold<int>(
                    0,
                    (total, child) => total + child.totalPoints,
                  );
                  final metrics = <_DashboardMetricData>[
                    _DashboardMetricData(
                      label: 'Children',
                      value: '${children.length}',
                      accent: VanavilPalette.sky,
                    ),
                    _DashboardMetricData(
                      label: 'Pending Reviews',
                      value: '${pendingAssignments.length}',
                      accent: VanavilPalette.sun,
                    ),
                    _DashboardMetricData(
                      label: 'Open Assignments',
                      value: '$openAssignments',
                      accent: VanavilPalette.berry,
                    ),
                    _DashboardMetricData(
                      label: 'Total Points',
                      value: '$totalPoints',
                      accent: VanavilPalette.leaf,
                    ),
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today overview',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Live activity for child progress, review queue, and announcements.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: onOpenTasks,
                            style: FilledButton.styleFrom(
                              backgroundColor: VanavilPalette.berry,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            child: const Text('Manage Tasks'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final metric in metrics)
                            SizedBox(
                              width: 220,
                              child: VanavilSectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: metric.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      metric.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      metric.value,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: VanavilPalette.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: VanavilSectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Pending reviews',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                        ),
                                        Text(
                                          '${pendingAssignments.length} waiting',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(width: 12),
                                        TextButton(
                                          onPressed: onOpenReviews,
                                          child: const Text('Open Reviews'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (pendingAssignments.isEmpty)
                                      _DashboardEmptyState(
                                        title: 'No submissions to review',
                                        message:
                                            'Submitted assignments will appear here once children upload proof.',
                                      )
                                    else
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: pendingAssignments.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 14),
                                          itemBuilder: (context, index) {
                                            final assignment =
                                                pendingAssignments[index];
                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: VanavilPalette.cream,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          assignment.title,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                VanavilPalette
                                                                    .ink,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          '${assignment.childName} • ${assignment.rewardPoints} points • ${_formatDueLabel(context, assignment.dueDate)}',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  VanavilStatusChip(
                                                    status: assignment.status,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  OutlinedButton(
                                                    onPressed: onOpenReviews,
                                                    child: const Text('Review'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: VanavilSectionCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Points by child',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 16),
                                          if (children.isEmpty)
                                            const _DashboardEmptyState(
                                              title: 'No children yet',
                                              message:
                                                  'Add a child profile to start tracking points and assignments.',
                                            )
                                          else
                                            Expanded(
                                              child: ListView.builder(
                                                itemCount: children.length,
                                                itemBuilder: (context, index) {
                                                  final child = children[index];
                                                  return ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: CircleAvatar(
                                                      backgroundColor:
                                                          VanavilPalette
                                                              .lavender
                                                              .withValues(
                                                                alpha: 0.16,
                                                              ),
                                                      foregroundColor:
                                                          VanavilPalette.ink,
                                                      child: Text(child.avatar),
                                                    ),
                                                    title: Text(child.name),
                                                    subtitle: Text(
                                                      child.isActive
                                                          ? 'Active child'
                                                          : 'Inactive child',
                                                    ),
                                                    trailing: Text(
                                                      '${child.totalPoints} pts',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            VanavilPalette.ink,
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
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: VanavilSectionCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Announcements',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 16),
                                          if (announcements.isEmpty)
                                            const _DashboardEmptyState(
                                              title: 'No announcements yet',
                                              message:
                                                  'Published announcements will show up here for quick review.',
                                            )
                                          else
                                            Expanded(
                                              child: ListView.separated(
                                                itemCount: announcements
                                                    .take(3)
                                                    .length,
                                                separatorBuilder: (_, _) =>
                                                    const SizedBox(height: 12),
                                                itemBuilder: (context, index) {
                                                  final announcement =
                                                      announcements[index];
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: VanavilPalette.sun
                                                          .withValues(
                                                            alpha: 0.16,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          announcement.title,
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                VanavilPalette
                                                                    .ink,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          announcement.message,
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            height: 1.5,
                                                            color:
                                                                VanavilPalette
                                                                    .ink,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          _formatShortDate(
                                                            context,
                                                            announcement
                                                                .visibilityDate,
                                                          ),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium,
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
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
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardMetricData {
  const _DashboardMetricData({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;
}

class _AdminChildSummary {
  const _AdminChildSummary({
    required this.name,
    required this.avatar,
    required this.totalPoints,
    required this.isActive,
  });

  factory _AdminChildSummary.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final name = _readString(data['name'], fallback: 'Child');

    return _AdminChildSummary(
      name: name,
      avatar: _readString(
        data['avatar'],
        fallback: name.characters.first.toUpperCase(),
      ),
      totalPoints: _readInt(data['totalPoints']),
      isActive: _readString(data['status'], fallback: 'active') == 'active',
    );
  }

  final String name;
  final String avatar;
  final int totalPoints;
  final bool isActive;
}

class _PendingAssignmentItem {
  const _PendingAssignmentItem({
    required this.title,
    required this.childName,
    required this.rewardPoints,
    required this.status,
    required this.dueDate,
    required this.assignedBy,
    required this.sortDate,
  });

  factory _PendingAssignmentItem.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _PendingAssignmentItem(
      title: _readString(data['taskTitle'], fallback: 'Untitled assignment'),
      childName: _readString(data['childName'], fallback: 'Unknown child'),
      rewardPoints: _readInt(data['rewardPoints']),
      status: _assignmentStatusFromString(
        _readString(data['status'], fallback: 'assigned'),
      ),
      dueDate: _readDateTime(data['dueDate']),
      assignedBy: data['assignedBy'] as String?,
      sortDate:
          _readDateTime(data['submittedAt']) ??
          _readDateTime(data['updatedAt']) ??
          _readDateTime(data['createdAt']) ??
          _readDateTime(data['dueDate']),
    );
  }

  final String title;
  final String childName;
  final int rewardPoints;
  final AssignmentStatus status;
  final DateTime? dueDate;
  final String? assignedBy;
  final DateTime? sortDate;
}

class _AnnouncementItem {
  const _AnnouncementItem({
    required this.title,
    required this.message,
    required this.status,
    required this.visibilityDate,
  });

  factory _AnnouncementItem.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _AnnouncementItem(
      title: _readString(data['title'], fallback: 'Announcement'),
      message: _readString(data['message']),
      status: _readString(data['status'], fallback: 'draft'),
      visibilityDate:
          _readDateTime(data['visibilityDate']) ??
          _readDateTime(data['updatedAt']) ??
          _readDateTime(data['createdAt']),
    );
  }

  final String title;
  final String message;
  final String status;
  final DateTime? visibilityDate;
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: VanavilSectionCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VanavilPalette.creamSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: VanavilPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

AssignmentStatus _assignmentStatusFromString(String value) {
  return switch (value) {
    'submitted' => AssignmentStatus.submitted,
    'approved' => AssignmentStatus.approved,
    'completed' => AssignmentStatus.completed,
    'rejected' => AssignmentStatus.rejected,
    _ => AssignmentStatus.assigned,
  };
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

String _formatDueLabel(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) {
    return 'No due date';
  }

  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  final dateOnly = DateUtils.dateOnly(dateTime);
  final tomorrow = today.add(const Duration(days: 1));
  final timeLabel = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));

  if (dateOnly == today) {
    return 'Today, $timeLabel';
  }

  if (dateOnly == tomorrow) {
    return 'Tomorrow, $timeLabel';
  }

  return '${dateTime.day} ${_monthLabel(dateTime.month)}, $timeLabel';
}

String _formatShortDate(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) {
    return 'No publish date';
  }

  final now = DateUtils.dateOnly(DateTime.now());
  final value = DateUtils.dateOnly(dateTime);
  if (value == now) {
    return 'Today';
  }

  return '${dateTime.day} ${_monthLabel(dateTime.month)}';
}

String _monthLabel(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[month - 1];
}
