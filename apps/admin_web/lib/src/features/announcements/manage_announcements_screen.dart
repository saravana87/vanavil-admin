import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../app/admin_access.dart';

class ManageAnnouncementsScreen extends StatefulWidget {
  const ManageAnnouncementsScreen({super.key, required this.access});

  final AdminAccess access;

  @override
  State<ManageAnnouncementsScreen> createState() =>
      _ManageAnnouncementsScreenState();
}

class _ManageAnnouncementsScreenState extends State<ManageAnnouncementsScreen> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create and manage announcements visible to children.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAnnouncementDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Announcement'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── List ──
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.announcements)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.campaign_rounded,
                          size: 56,
                          color: VanavilPalette.coral.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No announcements yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: VanavilPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap "New Announcement" to create one.',
                          style: TextStyle(color: VanavilPalette.inkSoft),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = data['title'] as String? ?? 'Untitled';
                    final message = data['message'] as String? ?? '';
                    final status = data['status'] as String? ?? 'draft';
                    final visibilityDate = _readDateTime(
                      data['visibilityDate'],
                    );
                    final createdAt = _readDateTime(data['createdAt']);

                    return VanavilSectionCard(
                      child: Row(
                        children: [
                          // Status indicator
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status == 'published'
                                  ? VanavilPalette.leaf
                                  : VanavilPalette.sun,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: VanavilPalette.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: VanavilPalette.inkSoft,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _MetaChip(
                                      icon: status == 'published'
                                          ? Icons.public_rounded
                                          : Icons.drafts_rounded,
                                      label: status == 'published'
                                          ? 'Published'
                                          : 'Draft',
                                      color: status == 'published'
                                          ? VanavilPalette.leaf
                                          : VanavilPalette.sun,
                                    ),
                                    if (visibilityDate != null) ...[
                                      const SizedBox(width: 8),
                                      _MetaChip(
                                        icon: Icons.schedule_rounded,
                                        label: _formatDate(visibilityDate),
                                        color: VanavilPalette.sky,
                                      ),
                                    ],
                                    if (createdAt != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'Created ${_formatDate(createdAt)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: VanavilPalette.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            onPressed: () =>
                                _showAnnouncementDialog(context, doc: doc),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: Icon(
                              status == 'published'
                                  ? Icons.unpublished_rounded
                                  : Icons.publish_rounded,
                              size: 20,
                            ),
                            onPressed: () => _toggleStatus(doc.id, status),
                            tooltip: status == 'published'
                                ? 'Unpublish'
                                : 'Publish',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: VanavilPalette.coral,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, doc.id, title),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
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

  // ── Toggle draft ↔ published ──

  Future<void> _toggleStatus(String docId, String currentStatus) async {
    final newStatus = currentStatus == 'published' ? 'draft' : 'published';
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.announcements)
        .doc(docId)
        .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // ── Delete with confirmation ──

  Future<void> _confirmDelete(
    BuildContext context,
    String docId,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VanavilPalette.coral,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.announcements)
          .doc(docId)
          .delete();
    }
  }

  // ── Create / Edit dialog ──

  Future<void> _showAnnouncementDialog(
    BuildContext context, {
    DocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final isEditing = doc != null;
    final data = doc?.data() ?? <String, dynamic>{};

    final titleCtrl = TextEditingController(
      text: data['title'] as String? ?? '',
    );
    final messageCtrl = TextEditingController(
      text: data['message'] as String? ?? '',
    );
    String status = data['status'] as String? ?? 'draft';
    DateTime? visibilityDate = _readDateTime(data['visibilityDate']);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Announcement' : 'New Announcement'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Status: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Draft'),
                      selected: status == 'draft',
                      onSelected: (_) => setDialogState(() => status = 'draft'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Published'),
                      selected: status == 'published',
                      onSelected: (_) =>
                          setDialogState(() => status = 'published'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Visible from: '),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        visibilityDate != null
                            ? _formatDate(visibilityDate!)
                            : 'Pick a date',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: visibilityDate ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => visibilityDate = picked);
                        }
                      },
                    ),
                    if (visibilityDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () =>
                            setDialogState(() => visibilityDate = null),
                        tooltip: 'Clear date',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final message = messageCtrl.text.trim();
                if (title.isEmpty) return;

                final payload = <String, dynamic>{
                  'title': title,
                  'message': message,
                  'status': status,
                  'visibilityDate': visibilityDate != null
                      ? Timestamp.fromDate(visibilityDate!)
                      : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEditing) {
                  await FirebaseFirestore.instance
                      .collection(FirestoreCollections.announcements)
                      .doc(doc!.id)
                      .update(payload);
                } else {
                  payload['createdBy'] =
                      FirebaseAuth.instance.currentUser?.uid ?? '';
                  payload['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection(FirestoreCollections.announcements)
                      .add(payload);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatDate(DateTime date) {
  final months = [
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
