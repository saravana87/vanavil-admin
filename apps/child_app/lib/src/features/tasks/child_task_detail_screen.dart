import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/attachment_service.dart';
import '../../data/firestore_records.dart';
import 'proof_submission_screen.dart';

class ChildTaskDetailScreen extends StatefulWidget {
  const ChildTaskDetailScreen({
    super.key,
    required this.assignment,
    required this.childId,
  });

  /// Initial assignment data (used until the stream emits).
  final ChildAssignmentRecord assignment;
  final String childId;

  @override
  State<ChildTaskDetailScreen> createState() => _ChildTaskDetailScreenState();
}

class _ChildTaskDetailScreenState extends State<ChildTaskDetailScreen> {
  final _attachmentService = AttachmentService();
  final _loadingAttachments = <String, bool>{};

  /// Live assignment — updated by the Firestore stream, falls back to the
  /// initial snapshot passed via the constructor.
  late ChildAssignmentRecord _liveAssignment = widget.assignment;

  // ── Attachment download ─────────────────────────────────────────────────

  Future<void> _openAttachment(TaskAttachmentRecord attachment) async {
    final key = attachment.objectKey.isNotEmpty
        ? attachment.objectKey
        : attachment.storagePath;

    if (key.isEmpty) {
      _showError('No file reference available for this attachment.');
      return;
    }

    setState(() => _loadingAttachments[key] = true);

    try {
      final url = await _attachmentService.getChildDownloadUrl(
        objectKey: key,
        taskId: _liveAssignment.taskId,
        assignmentId: _liveAssignment.id,
        childId: widget.childId,
      );
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showError('Could not open the file.');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingAttachments[key] = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: VanavilPalette.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Navigate to proof submission ────────────────────────────────────────

  void _openProofScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProofSubmissionScreen(
          assignmentId: _liveAssignment.id,
          taskId: _liveAssignment.taskId,
          childId: widget.childId,
          taskTitle: _liveAssignment.taskTitle,
          isResubmission:
              _liveAssignment.status == AssignmentStatus.rejected,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.assignments)
            .doc(widget.assignment.id)
            .snapshots(),
        builder: (context, assignmentSnapshot) {
          // Update live assignment if the stream has data.
          if (assignmentSnapshot.hasData &&
              assignmentSnapshot.data != null &&
              assignmentSnapshot.data!.exists) {
            final d = assignmentSnapshot.data!.data()!;
            _liveAssignment = ChildAssignmentRecord(
              id: assignmentSnapshot.data!.id,
              taskId: readString(d['taskId']),
              taskTitle: readString(d['taskTitle'],
                  fallback: widget.assignment.taskTitle),
              childId: readString(d['childId']),
              childName: readString(d['childName']),
              assignedBy: readString(d['assignedBy']),
              dueDate: readDateTime(d['dueDate']),
              status: assignmentStatusFromString(readString(d['status'])),
              rewardPoints: readInt(d['rewardPoints']),
              assignedAt: readDateTime(d['assignedAt']),
              submittedAt: readDateTime(d['submittedAt']),
              createdAt: readDateTime(d['createdAt']),
            );
          }

          final a = _liveAssignment;

          return Stack(
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
                    stops: [0.0, 0.35, 1.0],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // ── Colorful header bar ──
                    _buildHeader(a),

                    const SizedBox(height: 16),

                    // ── Scrollable body ──
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          _buildAssignmentInfoCard(context, a),
                          const SizedBox(height: 16),
                          _buildTaskDetailSection(context),
                        ],
                      ),
                    ),

                    // ── Status-based CTA ──
                    _buildStatusCta(a.status),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Header bar ──────────────────────────────────────────────────────────

  Widget _buildHeader(ChildAssignmentRecord a) {
    final gradient = _headerGradient(a.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon:
                const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              a.taskTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          VanavilStatusChip(status: a.status),
        ],
      ),
    );
  }

  // ── Header gradient per status ──────────────────────────────────────────

  static List<Color> _headerGradient(AssignmentStatus status) {
    return switch (status) {
      AssignmentStatus.assigned => const [
          VanavilPalette.sky,
          Color(0xFF42A5F5),
        ],
      AssignmentStatus.submitted => const [
          VanavilPalette.sun,
          Color(0xFFFFB300),
        ],
      AssignmentStatus.approved => const [
          VanavilPalette.leaf,
          Color(0xFF66BB6A),
        ],
      AssignmentStatus.completed => const [
          VanavilPalette.leaf,
          Color(0xFF43A047),
        ],
      AssignmentStatus.rejected => const [
          VanavilPalette.coral,
          Color(0xFFEF5350),
        ],
    };
  }

  // ── Status-based CTA button ─────────────────────────────────────────────

  Widget _buildStatusCta(AssignmentStatus status) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: switch (status) {
        AssignmentStatus.assigned => _ctaButton(
            label: 'Start Task',
            icon: Icons.rocket_launch_rounded,
            gradient: const [VanavilPalette.leaf, Color(0xFF66BB6A)],
            onTap: _openProofScreen,
          ),
        AssignmentStatus.rejected => _ctaButton(
            label: 'Fix And Resubmit',
            icon: Icons.refresh_rounded,
            gradient: const [VanavilPalette.coral, Color(0xFFEF5350)],
            onTap: _openProofScreen,
          ),
        AssignmentStatus.submitted => _ctaBanner(
            label: 'Waiting For Review',
            icon: Icons.hourglass_top_rounded,
            gradient: [
              VanavilPalette.sun.withValues(alpha: 0.7),
              const Color(0xFFFFB300).withValues(alpha: 0.6),
            ],
          ),
        AssignmentStatus.approved => _ctaBanner(
            label: 'Great Job!',
            icon: Icons.celebration_rounded,
            gradient: const [VanavilPalette.leaf, Color(0xFF66BB6A)],
          ),
        AssignmentStatus.completed => _ctaBanner(
            label: 'Completed',
            icon: Icons.task_alt_rounded,
            gradient: const [VanavilPalette.leaf, Color(0xFF43A047)],
          ),
      },
    );
  }

  Widget _ctaButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctaBanner({
    required String label,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ── Assignment info card ────────────────────────────────────────────────

  Widget _buildAssignmentInfoCard(
    BuildContext context,
    ChildAssignmentRecord a,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Due date
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VanavilPalette.sky.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      size: 20, color: VanavilPalette.sky),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Due',
                          style: TextStyle(
                            fontSize: 12,
                            color: VanavilPalette.inkSoft,
                          )),
                      const SizedBox(height: 2),
                      Text(
                        formatDueLabel(a.dueDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: VanavilPalette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Reward points badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [VanavilPalette.sun, Color(0xFFFFD54F)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: VanavilPalette.sun.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${a.rewardPoints} pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Task detail section (fetched by taskId) ─────────────────────────────

  Widget _buildTaskDetailSection(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.tasks)
          .doc(widget.assignment.taskId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildInfoCard(
            icon: Icons.error_outline_rounded,
            iconColor: VanavilPalette.coral,
            bgColor: VanavilPalette.coral.withValues(alpha: 0.1),
            text: 'Could not load task details.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data;
        if (doc == null || !doc.exists) {
          return _buildInfoCard(
            icon: Icons.info_outline_rounded,
            iconColor: VanavilPalette.inkSoft,
            bgColor: VanavilPalette.sky.withValues(alpha: 0.08),
            text: 'Task details not available.',
          );
        }

        final task = TaskDetailRecord.fromSnapshot(doc);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Description ──
            if (task.description.isNotEmpty) ...[
              _sectionHeader(context, 'Description',
                  Icons.article_rounded, VanavilPalette.sky),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  task.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: VanavilPalette.ink,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── Comments ──
            if (task.comments.isNotEmpty) ...[
              _sectionHeader(context, 'Comments',
                  Icons.chat_bubble_outline_rounded, VanavilPalette.lavender),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: VanavilPalette.lavender.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: VanavilPalette.lavender.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  task.comments,
                  style: const TextStyle(
                    fontSize: 15,
                    color: VanavilPalette.inkSoft,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── Attachments ──
            if (task.attachments.isNotEmpty) ...[
              _sectionHeader(
                context,
                'Attachments (${task.attachments.length})',
                Icons.attach_file_rounded,
                VanavilPalette.berry,
              ),
              const SizedBox(height: 8),
              ...task.attachments.map(_buildAttachmentRow),
            ],
          ],
        );
      },
    );
  }

  // ── Section header with icon ────────────────────────────────────────────

  Widget _sectionHeader(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  // ── Info card (error / empty) ───────────────────────────────────────────

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style:
                  TextStyle(color: iconColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Attachment row ──────────────────────────────────────────────────────

  Widget _buildAttachmentRow(TaskAttachmentRecord attachment) {
    final key = attachment.objectKey.isNotEmpty
        ? attachment.objectKey
        : attachment.storagePath;
    final isLoading = _loadingAttachments[key] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // File type icon in colored circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _fileColor(attachment.contentType)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconForContentType(attachment.contentType),
                color: _fileColor(attachment.contentType),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // File name + size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: VanavilPalette.ink,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatFileSize(attachment.sizeBytes),
                    style: const TextStyle(
                        fontSize: 12, color: VanavilPalette.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Download button
            isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [VanavilPalette.sky, Color(0xFF42A5F5)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              VanavilPalette.sky.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openAttachment(attachment),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.download_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  static Color _fileColor(String contentType) {
    final ct = contentType.toLowerCase();
    if (ct.startsWith('image/')) return VanavilPalette.berry;
    if (ct.startsWith('video/')) return VanavilPalette.leaf;
    if (ct.startsWith('audio/')) return VanavilPalette.sun;
    if (ct.contains('pdf')) return VanavilPalette.coral;
    return VanavilPalette.sky;
  }
}
