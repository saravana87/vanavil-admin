import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vanavil_core/vanavil_core.dart';

// ---------------------------------------------------------------------------
// Defensive field readers (same pattern as admin_web)
// ---------------------------------------------------------------------------

String readString(dynamic value, {String fallback = ''}) {
  if (value is String) return value;
  return fallback;
}

int readInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return 0;
}

DateTime? readDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

AssignmentStatus assignmentStatusFromString(String value) {
  return switch (value) {
    'assigned' => AssignmentStatus.assigned,
    'submitted' => AssignmentStatus.submitted,
    'approved' => AssignmentStatus.approved,
    'completed' => AssignmentStatus.completed,
    'rejected' => AssignmentStatus.rejected,
    _ => AssignmentStatus.assigned,
  };
}

List<TaskAttachmentRecord> readAttachments(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(TaskAttachmentRecord.fromMap)
      .toList();
}

// ---------------------------------------------------------------------------
// Display helpers
// ---------------------------------------------------------------------------

String formatDueLabel(DateTime? dateTime) {
  if (dateTime == null) return 'No due date';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final diff = due.difference(today).inDays;

  final time =
      '${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';

  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Tomorrow, $time';
  if (diff == -1) return 'Yesterday, $time';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}, $time';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

IconData iconForContentType(String contentType) {
  final ct = contentType.toLowerCase();
  if (ct.startsWith('image/')) return Icons.image_rounded;
  if (ct.startsWith('video/')) return Icons.videocam_rounded;
  if (ct.startsWith('audio/')) return Icons.audiotrack_rounded;
  if (ct.contains('pdf')) return Icons.picture_as_pdf_rounded;
  if (ct.contains('word') || ct.contains('document')) {
    return Icons.description_rounded;
  }
  if (ct.contains('sheet') || ct.contains('excel')) {
    return Icons.table_chart_rounded;
  }
  if (ct.contains('presentation') || ct.contains('powerpoint')) {
    return Icons.slideshow_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

// ---------------------------------------------------------------------------
// Record: Assignment (from 'assignments' collection)
// ---------------------------------------------------------------------------

class ChildAssignmentRecord {
  ChildAssignmentRecord({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.childId,
    required this.childName,
    required this.assignedBy,
    required this.dueDate,
    required this.status,
    required this.rewardPoints,
    required this.assignedAt,
    required this.submittedAt,
    required this.createdAt,
  });

  factory ChildAssignmentRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final d = snapshot.data();
    return ChildAssignmentRecord(
      id: snapshot.id,
      taskId: readString(d['taskId']),
      taskTitle: readString(d['taskTitle'], fallback: 'Untitled Task'),
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

  final String id;
  final String taskId;
  final String taskTitle;
  final String childId;
  final String childName;
  final String assignedBy;
  final DateTime? dueDate;
  final AssignmentStatus status;
  final int rewardPoints;
  final DateTime? assignedAt;
  final DateTime? submittedAt;
  final DateTime? createdAt;
}

// ---------------------------------------------------------------------------
// Record: Task detail (from 'tasks' collection)
// ---------------------------------------------------------------------------

class TaskDetailRecord {
  TaskDetailRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.comments,
    required this.rewardPoints,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskDetailRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final d = snapshot.data() ?? {};
    return TaskDetailRecord(
      id: snapshot.id,
      title: readString(d['title'], fallback: 'Untitled Task'),
      description: readString(d['description']),
      comments: readString(d['comments']),
      rewardPoints: readInt(d['rewardPoints']),
      attachments: readAttachments(d['attachments']),
      createdAt: readDateTime(d['createdAt']),
      updatedAt: readDateTime(d['updatedAt']),
    );
  }

  final String id;
  final String title;
  final String description;
  final String comments;
  final int rewardPoints;
  final List<TaskAttachmentRecord> attachments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

// ---------------------------------------------------------------------------
// Record: Task attachment (from attachments[] array inside a task document)
// ---------------------------------------------------------------------------

class TaskAttachmentRecord {
  TaskAttachmentRecord({
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.objectKey,
    required this.storagePath,
  });

  factory TaskAttachmentRecord.fromMap(Map<String, dynamic> m) {
    return TaskAttachmentRecord(
      fileName: readString(m['fileName'], fallback: 'unknown'),
      contentType: readString(
        m['contentType'],
        fallback: 'application/octet-stream',
      ),
      sizeBytes: readInt(m['sizeBytes']),
      objectKey: readString(m['objectKey']),
      storagePath: readString(m['storagePath']),
    );
  }

  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String objectKey;
  final String storagePath;
}

/// Maps common file extensions to MIME types.
String contentTypeFromFileName(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'avi' => 'video/x-msvideo',
    'webm' => 'video/webm',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    'ogg' => 'audio/ogg',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

/// Maps a MIME content type to the proof type expected by the Firestore schema.
String contentTypeToProofType(String contentType) {
  final ct = contentType.toLowerCase();
  if (ct.startsWith('image/')) return 'photo';
  if (ct.startsWith('video/')) return 'video';
  if (ct.startsWith('audio/')) return 'audio';
  return 'file';
}

/// Lightweight data class describing one uploaded proof file.
class SubmissionFileEntry {
  const SubmissionFileEntry({
    required this.objectKey,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String objectKey;
  final String fileName;
  final String contentType;
  final int sizeBytes;
}

// ---------------------------------------------------------------------------
// Record: Points ledger entry (from 'points_ledger' collection)
// ---------------------------------------------------------------------------

class PointsLedgerRecord {
  PointsLedgerRecord({
    required this.id,
    required this.childId,
    required this.assignmentId,
    required this.reviewId,
    required this.points,
    required this.reason,
    required this.createdAt,
  });

  factory PointsLedgerRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final d = snapshot.data();
    return PointsLedgerRecord(
      id: snapshot.id,
      childId: readString(d['childId']),
      assignmentId: readString(d['assignmentId']),
      reviewId: readString(d['reviewId']),
      points: readInt(d['points']),
      reason: readString(d['reason']),
      createdAt: readDateTime(d['createdAt']),
    );
  }

  final String id;
  final String childId;
  final String assignmentId;
  final String reviewId;
  final int points;
  final String reason;
  final DateTime? createdAt;
}

// ---------------------------------------------------------------------------
// Record: Child badge award (from 'child_badges' collection)
// ---------------------------------------------------------------------------

class ChildBadgeRecord {
  ChildBadgeRecord({
    required this.id,
    required this.childId,
    required this.badgeId,
    required this.badgeTitle,
    required this.awardedBy,
    required this.awardedAt,
    required this.reason,
  });

  factory ChildBadgeRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final d = snapshot.data();
    return ChildBadgeRecord(
      id: snapshot.id,
      childId: readString(d['childId']),
      badgeId: readString(d['badgeId']),
      badgeTitle: readString(d['badgeTitle'], fallback: 'Badge'),
      awardedBy: readString(d['awardedBy']),
      awardedAt: readDateTime(d['awardedAt']),
      reason: readString(d['reason']),
    );
  }

  final String id;
  final String childId;
  final String badgeId;
  final String badgeTitle;
  final String awardedBy;
  final DateTime? awardedAt;
  final String reason;
}

// ---------------------------------------------------------------------------
// Record: Announcement (from 'announcements' collection)
// ---------------------------------------------------------------------------

class AnnouncementRecord {
  AnnouncementRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.createdBy,
    required this.status,
    required this.visibilityDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final d = snapshot.data();
    return AnnouncementRecord(
      id: snapshot.id,
      title: readString(d['title'], fallback: 'Announcement'),
      message: readString(d['message']),
      createdBy: readString(d['createdBy']),
      status: readString(d['status'], fallback: 'draft'),
      visibilityDate: readDateTime(d['visibilityDate']),
      createdAt: readDateTime(d['createdAt']),
      updatedAt: readDateTime(d['updatedAt']),
    );
  }

  final String id;
  final String title;
  final String message;
  final String createdBy;
  final String status;
  final DateTime? visibilityDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished => status == 'published';

  bool get isVisible {
    if (!isPublished) return false;
    if (visibilityDate == null) return true;
    return !visibilityDate!.isAfter(DateTime.now());
  }
}
