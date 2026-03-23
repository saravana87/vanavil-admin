library;

import 'package:flutter/foundation.dart';

enum AssignmentStatus { assigned, submitted, approved, completed, rejected }

enum NotificationType {
  newTask,
  submissionApproved,
  submissionRejected,
  badgeReceived,
  announcement,
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.totalPoints,
    required this.isActive,
  });

  final String id;
  final String name;
  final String avatar;
  final int totalPoints;
  final bool isActive;
}

class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    required this.rewardPoints,
    required this.status,
    required this.dueLabel,
  });

  final String id;
  final String title;
  final int rewardPoints;
  final AssignmentStatus status;
  final String dueLabel;
}

class DashboardMetric {
  const DashboardMetric({required this.label, required this.value});

  final String label;
  final String value;
}

@immutable
class AdminLoginDraft {
  const AdminLoginDraft({this.email = '', this.password = ''});

  final String email;
  final String password;

  bool get isValid => email.contains('@') && password.length >= 6;
}

@immutable
class ChildPinDraft {
  const ChildPinDraft({required this.child, this.pin = ''});

  final ChildProfile child;
  final String pin;

  bool get isValid => RegExp(r'^\d{4}$').hasMatch(pin);
}

class DemoSeedData {
  static const children = <ChildProfile>[
    ChildProfile(
      id: 'madhu',
      name: 'Madhu',
      avatar: 'M',
      totalPoints: 140,
      isActive: true,
    ),
    ChildProfile(
      id: 'kavin',
      name: 'Kavin',
      avatar: 'K',
      totalPoints: 95,
      isActive: true,
    ),
    ChildProfile(
      id: 'nila',
      name: 'Nila',
      avatar: 'N',
      totalPoints: 80,
      isActive: true,
    ),
  ];

  static const assignments = <Assignment>[
    Assignment(
      id: 'a1',
      title: 'Clean your study table',
      rewardPoints: 20,
      status: AssignmentStatus.assigned,
      dueLabel: 'Today, 6:00 PM',
    ),
    Assignment(
      id: 'a2',
      title: 'Read one story book chapter',
      rewardPoints: 15,
      status: AssignmentStatus.submitted,
      dueLabel: 'Today, 7:30 PM',
    ),
    Assignment(
      id: 'a3',
      title: 'Water the plants',
      rewardPoints: 10,
      status: AssignmentStatus.rejected,
      dueLabel: 'Tomorrow, 5:00 PM',
    ),
  ];

  static const adminMetrics = <DashboardMetric>[
    DashboardMetric(label: 'Tasks Today', value: '12'),
    DashboardMetric(label: 'Pending Reviews', value: '4'),
    DashboardMetric(label: 'Approved', value: '18'),
    DashboardMetric(label: 'Rejected', value: '2'),
  ];
}
