import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

const String _s3ApiBaseUrl = String.fromEnvironment('VANAVIL_S3_API_BASE_URL');

class ManageReviewsScreen extends StatefulWidget {
  const ManageReviewsScreen({super.key});

  @override
  State<ManageReviewsScreen> createState() => _ManageReviewsScreenState();
}

class _ManageReviewsScreenState extends State<ManageReviewsScreen> {
  String? _selectedAssignmentId;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('Sign in again to continue.'));
    }

    final assignmentsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.assignments)
        .where('assignedBy', isEqualTo: currentUserId)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: assignmentsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReviewsErrorState(
              title: 'Unable to load reviews',
              message: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pendingAssignments =
              snapshot.data?.docs
                  .map(_PendingReviewAssignment.fromSnapshot)
                  .where(
                    (assignment) =>
                        assignment.status == AssignmentStatus.submitted,
                  )
                  .toList() ??
              <_PendingReviewAssignment>[];

          pendingAssignments.sort((left, right) {
            final leftDate = left.sortDate;
            final rightDate = right.sortDate;
            if (leftDate == null && rightDate == null) {
              return left.taskTitle.compareTo(right.taskTitle);
            }
            if (leftDate == null) return 1;
            if (rightDate == null) return -1;
            return rightDate.compareTo(leftDate);
          });

          if (pendingAssignments.isEmpty) {
            return const _ReviewsEmptyState(
              title: 'No pending reviews',
              message:
                  'Child submissions will appear here after they upload proof and submit a task.',
            );
          }

          final selectedAssignment = pendingAssignments.firstWhere(
            (assignment) => assignment.id == _selectedAssignmentId,
            orElse: () => pendingAssignments.first,
          );

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
                          'Reviews',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Open submitted proof, approve work, or send tasks back for resubmission.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _ReviewMetricCard(
                    label: 'Pending',
                    value: '${pendingAssignments.length}',
                    accent: VanavilPalette.sun,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 360,
                      child: VanavilSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Queue',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                Text(
                                  '${pendingAssignments.length} waiting',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.separated(
                                itemCount: pendingAssignments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final assignment = pendingAssignments[index];
                                  final isSelected =
                                      assignment.id == selectedAssignment.id;

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      setState(() {
                                        _selectedAssignmentId = assignment.id;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? VanavilPalette.sky.withValues(
                                                alpha: 0.12,
                                              )
                                            : VanavilPalette.creamSoft,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? VanavilPalette.sky
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            assignment.taskTitle,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: VanavilPalette.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${assignment.childName} • ${assignment.rewardPoints} points',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _formatDueLabel(
                                                    context,
                                                    assignment.dueDate,
                                                  ),
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                ),
                                              ),
                                              VanavilStatusChip(
                                                status: assignment.status,
                                              ),
                                            ],
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ReviewDetailsPane(
                        key: ValueKey(selectedAssignment.id),
                        assignment: selectedAssignment,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewDetailsPane extends StatefulWidget {
  const _ReviewDetailsPane({super.key, required this.assignment});

  final _PendingReviewAssignment assignment;

  @override
  State<_ReviewDetailsPane> createState() => _ReviewDetailsPaneState();
}

class _ReviewDetailsPaneState extends State<_ReviewDetailsPane> {
  late final TextEditingController _commentController;
  late final TextEditingController _pointsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _pointsController = TextEditingController(
      text: widget.assignment.rewardPoints.toString(),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionsStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.submissions)
        .where('childId', isEqualTo: widget.assignment.childId)
        .snapshots();

    return VanavilSectionCard(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: submissionsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReviewsErrorState(
              title: 'Unable to load submission details',
              message: snapshot.error.toString(),
            );
          }

          final submissions =
              snapshot.data?.docs
                  .map(_SubmissionRecord.fromSnapshot)
                  .where(
                    (submission) =>
                        submission.assignmentId == widget.assignment.id,
                  )
                  .toList() ??
              <_SubmissionRecord>[];

          submissions.sort((left, right) {
            final leftDate = left.uploadedAt;
            final rightDate = right.uploadedAt;
            if (leftDate == null && rightDate == null) {
              return left.fileName.compareTo(right.fileName);
            }
            if (leftDate == null) return 1;
            if (rightDate == null) return -1;
            return rightDate.compareTo(leftDate);
          });

          final notes = submissions
              .map((submission) => submission.note)
              .where((note) => note.isNotEmpty)
              .toSet()
              .toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.assignment.taskTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.assignment.childName} • ${widget.assignment.rewardPoints} default points',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted ${_formatDateTime(context, widget.assignment.submittedAt)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    VanavilStatusChip(status: widget.assignment.status),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ReviewInfoChip(
                      label: _formatDueLabel(
                        context,
                        widget.assignment.dueDate,
                      ),
                      color: VanavilPalette.sun,
                    ),
                    _ReviewInfoChip(
                      label:
                          '${submissions.length} proof item${submissions.length == 1 ? '' : 's'}',
                      color: VanavilPalette.sky,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Child explanation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (notes.isEmpty)
                  const Text(
                    'No written explanation was included with this submission.',
                  )
                else
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
                        for (final note in notes) ...[
                          Text(note),
                          if (note != notes.last) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Uploaded proof',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (submissions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VanavilPalette.creamSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'No uploaded proof files were found for this assignment yet.',
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: submissions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final submission = submissions[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: VanavilPalette.cream,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _attachmentIcon(submission.contentType),
                                color: VanavilPalette.ink,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    submission.fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: VanavilPalette.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${submission.proofTypeLabel} • ${_formatFileSize(submission.sizeBytes)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  _isSaving || submission.objectKey.isEmpty
                                  ? null
                                  : () => _openSubmissionAttachment(submission),
                              icon: Icon(
                                _attachmentActionIcon(submission.contentType),
                              ),
                              label: Text(
                                _attachmentActionLabel(submission.contentType),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Text(
                  'Review decision',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comment for the child',
                    hintText:
                        'Optional feedback shown when the task is approved or rejected.',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Points to award',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _approveAssignment,
                      style: FilledButton.styleFrom(
                        backgroundColor: VanavilPalette.leaf,
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _rejectAssignment,
                      icon: const Icon(Icons.undo_outlined),
                      label: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSubmissionAttachment(_SubmissionRecord submission) async {
    try {
      final response = await http.post(
        _buildS3ApiUri('/attachments/admin-submission-download-url'),
        headers: await _buildS3ApiJsonHeaders(),
        body: jsonEncode(<String, dynamic>{
          'submissionId': submission.id,
          'fileName': submission.fileName,
          'contentType': submission.contentType,
        }),
      );
      _throwIfS3ApiFailed(
        response,
        fallbackMessage: 'Unable to open the submitted proof file.',
      );

      final payload = _decodeJsonObject(response.body);
      final resolvedUrl = _readString(payload['downloadUrl']);
      final uri = Uri.tryParse(resolvedUrl);
      if (uri == null) {
        throw Exception('The API returned an invalid proof URL.');
      }

      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open ${submission.fileName}.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _approveAssignment() async {
    final parsedPoints = int.tryParse(_pointsController.text.trim());
    if (parsedPoints == null || parsedPoints < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points must be a non-negative number.')),
      );
      return;
    }

    await _submitReview(decision: 'approved', pointsAwarded: parsedPoints);
  }

  Future<void> _rejectAssignment() async {
    await _submitReview(decision: 'rejected', pointsAwarded: 0);
  }

  Future<void> _submitReview({
    required String decision,
    required int pointsAwarded,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final adminId = currentUser?.uid;
    if (adminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The current session expired.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final firestore = FirebaseFirestore.instance;
    final assignmentRef = firestore
        .collection(FirestoreCollections.assignments)
        .doc(widget.assignment.id);
    final childRef = firestore
        .collection(FirestoreCollections.children)
        .doc(widget.assignment.childId);
    final comment = _commentController.text.trim();

    try {
      await firestore.runTransaction((transaction) async {
        final assignmentSnapshot = await transaction.get(assignmentRef);
        if (!assignmentSnapshot.exists) {
          throw Exception('Assignment no longer exists.');
        }

        final data = assignmentSnapshot.data() ?? <String, dynamic>{};
        final latestStatus = _readString(data['status'], fallback: 'assigned');
        final latestAssignedBy = _readString(data['assignedBy']);
        if (latestAssignedBy != adminId) {
          throw Exception('You can only review assignments you created.');
        }
        if (latestStatus != 'submitted') {
          throw Exception('This assignment has already been reviewed.');
        }

        final reviewRef = firestore
            .collection(FirestoreCollections.reviews)
            .doc();
        transaction.set(reviewRef, <String, dynamic>{
          'assignmentId': widget.assignment.id,
          'childId': widget.assignment.childId,
          'adminId': adminId,
          'decision': decision,
          'comment': comment,
          'pointsAwarded': pointsAwarded,
          'reviewedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(assignmentRef, <String, dynamic>{
          'status': decision,
          'lastReviewId': reviewRef.id,
          if (decision == 'approved')
            'approvedAt': FieldValue.serverTimestamp(),
          if (decision == 'rejected')
            'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (decision == 'approved') {
          final pointsLedgerRef = firestore
              .collection(FirestoreCollections.pointsLedger)
              .doc();
          transaction.set(pointsLedgerRef, <String, dynamic>{
            'childId': widget.assignment.childId,
            'assignmentId': widget.assignment.id,
            'reviewId': reviewRef.id,
            'points': pointsAwarded,
            'reason': 'Approved ${widget.assignment.taskTitle}',
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(childRef, <String, dynamic>{
            'totalPoints': FieldValue.increment(pointsAwarded),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved'
                ? 'Task approved and points awarded.'
                : 'Task rejected and sent back for resubmission.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _PendingReviewAssignment {
  const _PendingReviewAssignment({
    required this.id,
    required this.taskTitle,
    required this.childId,
    required this.childName,
    required this.rewardPoints,
    required this.status,
    required this.dueDate,
    required this.submittedAt,
  });

  factory _PendingReviewAssignment.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _PendingReviewAssignment(
      id: snapshot.id,
      taskTitle: _readString(data['taskTitle'], fallback: 'Assigned task'),
      childId: _readString(data['childId']),
      childName: _readString(data['childName'], fallback: 'Unknown child'),
      rewardPoints: _readInt(data['rewardPoints']),
      status: _assignmentStatusFromString(
        _readString(data['status'], fallback: 'assigned'),
      ),
      dueDate: _readDateTime(data['dueDate']),
      submittedAt: _readDateTime(data['submittedAt']),
    );
  }

  final String id;
  final String taskTitle;
  final String childId;
  final String childName;
  final int rewardPoints;
  final AssignmentStatus status;
  final DateTime? dueDate;
  final DateTime? submittedAt;

  DateTime? get sortDate => submittedAt ?? dueDate;
}

class _SubmissionRecord {
  const _SubmissionRecord({
    required this.id,
    required this.assignmentId,
    required this.objectKey,
    required this.fileName,
    required this.contentType,
    required this.proofType,
    required this.note,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory _SubmissionRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _SubmissionRecord(
      id: snapshot.id,
      assignmentId: _readString(data['assignmentId']),
      objectKey: _readString(data['objectKey']),
      fileName: _readString(data['fileName'], fallback: 'attachment'),
      contentType: _readString(
        data['contentType'],
        fallback: 'application/octet-stream',
      ),
      proofType: _readString(data['proofType'], fallback: 'file'),
      note: _readString(data['note']),
      sizeBytes: _readInt(data['sizeBytes']),
      uploadedAt: _readDateTime(data['uploadedAt']),
    );
  }

  final String id;
  final String assignmentId;
  final String objectKey;
  final String fileName;
  final String contentType;
  final String proofType;
  final String note;
  final int sizeBytes;
  final DateTime? uploadedAt;

  String get proofTypeLabel => switch (proofType) {
    'photo' => 'Photo',
    'video' => 'Video',
    'audio' => 'Audio',
    'text' => 'Note',
    _ => 'File',
  };
}

class _ReviewMetricCard extends StatelessWidget {
  const _ReviewMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: VanavilSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: VanavilPalette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewInfoChip extends StatelessWidget {
  const _ReviewInfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: VanavilPalette.ink,
        ),
      ),
    );
  }
}

class _ReviewsErrorState extends StatelessWidget {
  const _ReviewsErrorState({required this.title, required this.message});

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

class _ReviewsEmptyState extends StatelessWidget {
  const _ReviewsEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Uri _buildS3ApiUri(String path) {
  final configuredBaseUrl = _s3ApiBaseUrl.trim();
  if (configuredBaseUrl.isEmpty) {
    throw Exception(
      'VANAVIL_S3_API_BASE_URL is not configured. Start the Python API and pass --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000.',
    );
  }

  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return Uri.parse('$configuredBaseUrl$normalizedPath');
}

Future<Map<String, String>> _buildS3ApiJsonHeaders() async {
  final headers = await _buildS3ApiAuthHeaders();
  return <String, String>{...headers, 'content-type': 'application/json'};
}

Future<Map<String, String>> _buildS3ApiAuthHeaders() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw Exception('The current session expired. Sign in again.');
  }

  final idToken = await currentUser.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw Exception('Unable to authorize the API request. Sign in again.');
  }

  return <String, String>{'authorization': 'Bearer $idToken'};
}

Map<String, dynamic> _decodeJsonObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  throw Exception('Unexpected response from the API.');
}

void _throwIfS3ApiFailed(
  http.Response response, {
  required String fallbackMessage,
}) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return;
  }

  try {
    final payload = _decodeJsonObject(response.body);
    final detail = _readString(payload['detail']);
    if (detail.isNotEmpty) {
      throw Exception(detail);
    }
  } on FormatException {
    // Fall back to the generic message below.
  }

  throw Exception('$fallbackMessage HTTP ${response.statusCode}.');
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

String _readString(dynamic value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
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
    return 'Due today, $timeLabel';
  }
  if (dateOnly == tomorrow) {
    return 'Due tomorrow, $timeLabel';
  }
  return 'Due ${dateTime.day} ${_monthLabel(dateTime.month)}, $timeLabel';
}

String _formatDateTime(BuildContext context, DateTime? dateTime) {
  if (dateTime == null) {
    return 'just now';
  }

  final timeLabel = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));
  return '${dateTime.day} ${_monthLabel(dateTime.month)}, $timeLabel';
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

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }

  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) {
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  final gigabytes = megabytes / 1024;
  return '${gigabytes.toStringAsFixed(1)} GB';
}

String _attachmentActionLabel(String contentType) {
  if (contentType.startsWith('image/') ||
      contentType.startsWith('video/') ||
      contentType.startsWith('audio/')) {
    return 'Open';
  }

  return 'Download';
}

IconData _attachmentActionIcon(String contentType) {
  if (contentType.startsWith('image/') ||
      contentType.startsWith('video/') ||
      contentType.startsWith('audio/')) {
    return Icons.open_in_new;
  }

  return Icons.download_outlined;
}

IconData _attachmentIcon(String contentType) {
  if (contentType.startsWith('image/')) {
    return Icons.image_outlined;
  }
  if (contentType.startsWith('video/')) {
    return Icons.video_library_outlined;
  }
  if (contentType.startsWith('audio/')) {
    return Icons.audio_file_outlined;
  }
  if (contentType == 'application/pdf') {
    return Icons.picture_as_pdf_outlined;
  }
  return Icons.insert_drive_file_outlined;
}
