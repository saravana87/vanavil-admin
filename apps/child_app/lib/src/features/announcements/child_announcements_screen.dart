import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/firestore_records.dart';

class ChildAnnouncementsScreen extends StatelessWidget {
  const ChildAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.announcements)
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
        final announcements = docs
            .map(AnnouncementRecord.fromSnapshot)
            .where((a) => a.isVisible)
            .toList();

        announcements.sort((a, b) {
          final aDate = a.visibilityDate ?? a.createdAt;
          final bDate = b.visibilityDate ?? b.createdAt;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        if (announcements.isEmpty) {
          return const _EmptyBody();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: announcements.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final announcement = announcements[index];
            return _AnnouncementCard(announcement: announcement);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Announcement card
// ═══════════════════════════════════════════════════════════════════════════

const _announcementGradients = [
  [Color(0xFFFFF3E0), Color(0xFFFFE0B2)], // warm orange
  [Color(0xFFE8F5E9), Color(0xFFC8E6C9)], // green
  [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], // blue
  [Color(0xFFFCE4EC), Color(0xFFF8BBD0)], // pink
  [Color(0xFFF3E5F5), Color(0xFFE1BEE7)], // purple
];

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final AnnouncementRecord announcement;

  @override
  Widget build(BuildContext context) {
    final gradient =
        _announcementGradients[announcement.title.length %
            _announcementGradients.length];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: VanavilPalette.coral,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: VanavilPalette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            announcement.message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: VanavilPalette.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: VanavilPalette.inkSoft,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(
                  announcement.visibilityDate ?? announcement.createdAt,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: VanavilPalette.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';

    const months = [
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
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty / Error states
// ═══════════════════════════════════════════════════════════════════════════

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
                    VanavilPalette.coral.withValues(alpha: 0.2),
                    VanavilPalette.sun.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                size: 40,
                color: VanavilPalette.coral,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No news yet!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: VanavilPalette.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When your parent posts announcements,\nthey will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VanavilPalette.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

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
              const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: VanavilPalette.coral,
              ),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong',
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
