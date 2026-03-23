import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:vanavil_core/vanavil_core.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../app/admin_access.dart';
import 'task_attachment_picker.dart';

const String _s3ApiBaseUrl = String.fromEnvironment('VANAVIL_S3_API_BASE_URL');

class ManageTasksScreen extends StatefulWidget {
  const ManageTasksScreen({super.key, required this.access});

  final AdminAccess access;

  @override
  State<ManageTasksScreen> createState() => _ManageTasksScreenState();
}

class _ManageTasksScreenState extends State<ManageTasksScreen> {
  bool _isCreatingTask = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Sign in again to continue.'));
    }

    Query<Map<String, dynamic>> tasksQuery = FirebaseFirestore.instance
        .collection(FirestoreCollections.tasks);
    if (!widget.access.isSuperAdmin) {
      tasksQuery = tasksQuery.where('createdBy', isEqualTo: currentUser.uid);
    }

    Query<Map<String, dynamic>> assignmentsQuery = FirebaseFirestore.instance
        .collection(FirestoreCollections.assignments);
    if (!widget.access.isSuperAdmin) {
      assignmentsQuery = assignmentsQuery.where(
        'assignedBy',
        isEqualTo: currentUser.uid,
      );
    }

    Query<Map<String, dynamic>> childrenQuery = FirebaseFirestore.instance
        .collection(FirestoreCollections.children)
        .where('status', isEqualTo: 'active');
    if (!widget.access.isSuperAdmin) {
      childrenQuery = childrenQuery.where(
        'adminId',
        isEqualTo: currentUser.uid,
      );
    }

    final tasksStream = tasksQuery.snapshots();
    final assignmentsStream = assignmentsQuery.snapshots();
    final childrenStream = childrenQuery.snapshots();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: tasksStream,
        builder: (context, tasksSnapshot) {
          if (tasksSnapshot.hasError) {
            return _TasksErrorState(
              title: 'Unable to load tasks',
              message: tasksSnapshot.error.toString(),
            );
          }

          if (tasksSnapshot.connectionState == ConnectionState.waiting &&
              !tasksSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks =
              tasksSnapshot.data?.docs
                  .map(_TaskTemplateRecord.fromSnapshot)
                  .toList() ??
              <_TaskTemplateRecord>[];
          tasks.sort((left, right) {
            final leftDate = left.updatedAt ?? left.createdAt;
            final rightDate = right.updatedAt ?? right.createdAt;
            if (leftDate == null && rightDate == null) {
              return left.title.compareTo(right.title);
            }
            if (leftDate == null) return 1;
            if (rightDate == null) return -1;
            return rightDate.compareTo(leftDate);
          });

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: assignmentsStream,
            builder: (context, assignmentsSnapshot) {
              if (assignmentsSnapshot.hasError) {
                return _TasksErrorState(
                  title: 'Unable to load assignments',
                  message: assignmentsSnapshot.error.toString(),
                );
              }

              final assignments =
                  assignmentsSnapshot.data?.docs
                      .map(_AssignedTaskRecord.fromSnapshot)
                      .toList() ??
                  <_AssignedTaskRecord>[];
              assignments.sort((left, right) {
                final leftDate = left.createdAt ?? left.dueDate;
                final rightDate = right.createdAt ?? right.dueDate;
                if (leftDate == null && rightDate == null) {
                  return left.taskTitle.compareTo(right.taskTitle);
                }
                if (leftDate == null) return 1;
                if (rightDate == null) return -1;
                return rightDate.compareTo(leftDate);
              });

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: childrenStream,
                builder: (context, childrenSnapshot) {
                  if (childrenSnapshot.hasError) {
                    return _TasksErrorState(
                      title: 'Unable to load children',
                      message: childrenSnapshot.error.toString(),
                    );
                  }

                  final children =
                      childrenSnapshot.data?.docs
                          .map(_ActiveChildRecord.fromSnapshot)
                          .toList() ??
                      <_ActiveChildRecord>[];
                  children.sort(
                    (left, right) => left.name.compareTo(right.name),
                  );

                  final activeTemplates = tasks
                      .where((task) => task.templateStatus == 'active')
                      .length;
                  final submittedAssignments = assignments
                      .where(
                        (assignment) =>
                            assignment.status == AssignmentStatus.submitted,
                      )
                      .length;

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
                                  'Manage tasks',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create reusable task templates and assign them to active child profiles.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: _isCreatingTask
                                ? null
                                : _showCreateTaskDialog,
                            style: FilledButton.styleFrom(
                              backgroundColor: VanavilPalette.sky,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            child: const Text('Create Task'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _TaskMetricCard(
                            label: 'Templates',
                            value: '${tasks.length}',
                            accent: VanavilPalette.sky,
                          ),
                          _TaskMetricCard(
                            label: 'Active Templates',
                            value: '$activeTemplates',
                            accent: VanavilPalette.leaf,
                          ),
                          _TaskMetricCard(
                            label: 'Assignments',
                            value: '${assignments.length}',
                            accent: VanavilPalette.berry,
                          ),
                          _TaskMetricCard(
                            label: 'Submitted',
                            value: '$submittedAssignments',
                            accent: VanavilPalette.sun,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                                            'Task templates',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                        ),
                                        Text(
                                          '${children.length} active children',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (tasks.isEmpty)
                                      _TasksEmptyState(
                                        title: 'No task templates yet',
                                        message:
                                            'Create the first task template to start assigning routines and one-off tasks.',
                                        actionLabel: 'Create Task',
                                        onPressed: _showCreateTaskDialog,
                                      )
                                    else
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: tasks.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final task = tasks[index];
                                            return Container(
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                color: VanavilPalette.cream,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          task.title,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                VanavilPalette
                                                                    .ink,
                                                          ),
                                                        ),
                                                      ),
                                                      _TemplateStatusChip(
                                                        status:
                                                            task.templateStatus,
                                                      ),
                                                    ],
                                                  ),
                                                  if (task
                                                      .description
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      task.description,
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodyMedium,
                                                    ),
                                                  ],
                                                  if (task
                                                      .comments
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Notes: ${task.comments}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodyMedium,
                                                    ),
                                                  ],
                                                  const SizedBox(height: 12),
                                                  Wrap(
                                                    spacing: 10,
                                                    runSpacing: 10,
                                                    children: [
                                                      _TaskInfoChip(
                                                        label:
                                                            '${task.rewardPoints} points',
                                                        color:
                                                            VanavilPalette.sky,
                                                      ),
                                                      _TaskInfoChip(
                                                        label:
                                                            task.recurringDaily
                                                            ? 'Daily recurring'
                                                            : 'One-time task',
                                                        color: VanavilPalette
                                                            .berry,
                                                      ),
                                                      if (task
                                                          .attachments
                                                          .isNotEmpty)
                                                        _TaskInfoChip(
                                                          label:
                                                              '${task.attachments.length} files',
                                                          color: VanavilPalette
                                                              .sun,
                                                        ),
                                                    ],
                                                  ),
                                                  if (task
                                                      .attachments
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 12),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        for (final attachment
                                                            in task.attachments
                                                                .take(4))
                                                          _AttachmentChip(
                                                            label: attachment
                                                                .fileName,
                                                          ),
                                                        if (task
                                                                .attachments
                                                                .length >
                                                            4)
                                                          _AttachmentChip(
                                                            label:
                                                                '+${task.attachments.length - 4} more',
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    OutlinedButton.icon(
                                                      onPressed: () =>
                                                          _showAttachmentDialog(
                                                            task,
                                                          ),
                                                      icon: const Icon(
                                                        Icons
                                                            .folder_open_outlined,
                                                      ),
                                                      label: const Text(
                                                        'View Files',
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 14),
                                                  Row(
                                                    children: [
                                                      FilledButton(
                                                        onPressed:
                                                            children.isEmpty ||
                                                                task.templateStatus !=
                                                                    'active'
                                                            ? null
                                                            : () =>
                                                                  _showAssignTaskDialog(
                                                                    task: task,
                                                                    children:
                                                                        children,
                                                                  ),
                                                        child: const Text(
                                                          'Assign Task',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      OutlinedButton(
                                                        onPressed: () =>
                                                            _toggleTemplateStatus(
                                                              task,
                                                            ),
                                                        child: Text(
                                                          task.templateStatus ==
                                                                  'active'
                                                              ? 'Archive'
                                                              : 'Activate',
                                                        ),
                                                      ),
                                                    ],
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
                              child: VanavilSectionCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recent assignments',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    if (assignments.isEmpty)
                                      const _TasksEmptyState(
                                        title: 'No assignments yet',
                                        message:
                                            'Assigned tasks will appear here with live status updates from Firestore.',
                                      )
                                    else
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: assignments.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final assignment =
                                                assignments[index];
                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: VanavilPalette.creamSoft,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    assignment.taskTitle,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                      VanavilStatusChip(
                                                        status:
                                                            assignment.status,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          _formatDueLabel(
                                                            context,
                                                            assignment.dueDate,
                                                          ),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodyMedium,
                                                          textAlign:
                                                              TextAlign.right,
                                                        ),
                                                      ),
                                                    ],
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
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateTaskDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final commentsController = TextEditingController();
    final rewardPointsController = TextEditingController(text: '10');
    final selectedAttachments = <_SelectedTaskAttachment>[];
    var recurringDaily = false;
    var isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                setDialogState(() {
                  errorMessage = 'The current session expired. Sign in again.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                errorMessage = null;
              });
              setState(() {
                _isCreatingTask = true;
              });

              final uploadedObjectKeys = <String>[];

              try {
                final taskDocument = FirebaseFirestore.instance
                    .collection(FirestoreCollections.tasks)
                    .doc();
                final attachmentRecords = <Map<String, dynamic>>[];
                String? attachmentUploadError;

                for (final attachment in selectedAttachments) {
                  final uploadPlan = await _uploadAttachmentThroughApi(
                    taskId: taskDocument.id,
                    attachment: attachment,
                  );

                  try {
                    uploadedObjectKeys.add(uploadPlan.objectKey);
                    attachmentRecords.add({
                      'fileName': attachment.fileName,
                      'contentType': attachment.contentType,
                      'sizeBytes': attachment.sizeBytes,
                      'provider': 's3',
                      'bucket': uploadPlan.bucket,
                      'region': uploadPlan.region,
                      'storagePath': uploadPlan.objectKey,
                      'objectKey': uploadPlan.objectKey,
                      'downloadUrl': '',
                    });
                  } catch (error) {
                    await _deleteUploadedS3Objects(uploadedObjectKeys);
                    uploadedObjectKeys.clear();
                    attachmentRecords.clear();
                    attachmentUploadError = _buildAttachmentUploadErrorMessage(
                      error,
                    );
                    break;
                  }
                }

                if (attachmentUploadError != null) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  final shouldSaveWithoutAttachments =
                      await _confirmSaveWithoutAttachments(
                        dialogContext,
                        attachmentUploadError,
                      );
                  if (!shouldSaveWithoutAttachments) {
                    setDialogState(() {
                      errorMessage = attachmentUploadError;
                      isSaving = false;
                    });
                    return;
                  }
                }

                await taskDocument.set({
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'comments': commentsController.text.trim(),
                  'rewardPoints': int.parse(rewardPointsController.text.trim()),
                  'recurringDaily': recurringDaily,
                  'templateStatus': 'active',
                  'attachments': attachmentRecords,
                  'createdBy': currentUser.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                if (attachmentUploadError != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(attachmentUploadError)),
                  );
                }
              } catch (error) {
                await _deleteUploadedS3Objects(uploadedObjectKeys);
                setDialogState(() {
                  errorMessage = error.toString();
                  isSaving = false;
                });
              } finally {
                if (mounted) {
                  setState(() {
                    _isCreatingTask = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Create task template'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Task title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a task title'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: commentsController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Comments for child',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: rewardPointsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reward points',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse(value?.trim() ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a positive reward point value';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Task attachments',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: isSaving
                                        ? null
                                        : () async {
                                            final result =
                                                await _pickTaskAttachments();
                                            if (!context.mounted) {
                                              return;
                                            }

                                            if (result.errorMessage != null) {
                                              setDialogState(() {
                                                errorMessage =
                                                    result.errorMessage;
                                              });
                                              return;
                                            }

                                            if (result.files.isEmpty) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'No files were selected.',
                                                    ),
                                                  ),
                                                );
                                              }
                                              return;
                                            }

                                            setDialogState(() {
                                              errorMessage = null;
                                              selectedAttachments.addAll(
                                                result.files,
                                              );
                                            });

                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${result.files.length} file(s) added. Files upload when you click Save Task.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Add Files'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload one or more photos, videos, audio files, or documents with this task template.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Files are selected first and kept locally in the form. They are uploaded to AWS S3 only after you click Save Task.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              if (selectedAttachments.isEmpty)
                                Text(
                                  'No files selected yet.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                )
                              else
                                Column(
                                  children: [
                                    for (final attachment
                                        in selectedAttachments)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .insert_drive_file_outlined,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  attachment.fileName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _formatFileSize(
                                                  attachment.sizeBytes,
                                                ),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                tooltip: 'Remove file',
                                                onPressed: isSaving
                                                    ? null
                                                    : () {
                                                        setDialogState(() {
                                                          selectedAttachments
                                                              .remove(
                                                                attachment,
                                                              );
                                                        });
                                                      },
                                                icon: const Icon(Icons.close),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: recurringDaily,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) {
                            setDialogState(() {
                              recurringDaily = value;
                            });
                          },
                          title: const Text('Recurring daily template'),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Saving...' : 'Save Task'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    commentsController.dispose();
    rewardPointsController.dispose();
  }

  Future<void> _showAssignTaskDialog({
    required _TaskTemplateRecord task,
    required List<_ActiveChildRecord> children,
  }) async {
    final formKey = GlobalKey<FormState>();
    final dueDateController = TextEditingController();
    _ActiveChildRecord? selectedChild = children.isEmpty
        ? null
        : children.first;
    DateTime? selectedDueDate;
    var isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDueDate() async {
              final today = DateTime.now();
              final date = await showDatePicker(
                context: dialogContext,
                firstDate: today,
                initialDate: selectedDueDate ?? today,
                lastDate: today.add(const Duration(days: 365)),
              );
              if (date == null || !context.mounted) {
                return;
              }

              final time = await showTimePicker(
                context: dialogContext,
                initialTime: TimeOfDay.fromDateTime(
                  selectedDueDate ?? today.add(const Duration(hours: 1)),
                ),
              );
              if (time == null) {
                return;
              }

              final combined = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );

              setDialogState(() {
                selectedDueDate = combined;
                dueDateController.text = _formatDueLabel(
                  dialogContext,
                  combined,
                );
              });
            }

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null ||
                  selectedChild == null ||
                  selectedDueDate == null) {
                setDialogState(() {
                  errorMessage =
                      'Select a child and due date before assigning.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                errorMessage = null;
              });

              try {
                await FirebaseFirestore.instance
                    .collection(FirestoreCollections.assignments)
                    .add({
                      'taskId': task.id,
                      'taskTitle': task.title,
                      'childId': selectedChild!.id,
                      'childName': selectedChild!.name,
                      'assignedBy': currentUser.uid,
                      'dueDate': Timestamp.fromDate(selectedDueDate!),
                      'status': 'assigned',
                      'rewardPoints': task.rewardPoints,
                      'isRecurringInstance': task.recurringDaily,
                      'assignedAt': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
              } catch (error) {
                setDialogState(() {
                  errorMessage = error.toString();
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Assign ${task.title}'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<_ActiveChildRecord>(
                        initialValue: selectedChild,
                        decoration: const InputDecoration(
                          labelText: 'Child',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final child in children)
                            DropdownMenuItem<_ActiveChildRecord>(
                              value: child,
                              child: Text(child.name),
                            ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedChild = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Select a child' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: dueDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Due date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: pickDueDate,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Select a due date'
                            : null,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Assigning...' : 'Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    dueDateController.dispose();
  }

  Future<void> _toggleTemplateStatus(_TaskTemplateRecord task) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.tasks)
          .doc(task.id)
          .update({
            'templateStatus': task.templateStatus == 'active'
                ? 'archived'
                : 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showAttachmentDialog(_TaskTemplateRecord task) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Files for ${task.title}'),
          content: SizedBox(
            width: 560,
            child: task.attachments.isEmpty
                ? const Text('No files attached to this task.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: task.attachments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final attachment = task.attachments[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: VanavilPalette.creamSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(_attachmentIcon(attachment.contentType)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attachment.fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: VanavilPalette.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${attachment.contentType.isEmpty ? 'Unknown type' : attachment.contentType} • ${_formatFileSize(attachment.sizeBytes)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => _openAttachment(attachment),
                              icon: Icon(
                                _attachmentActionIcon(attachment.contentType),
                              ),
                              label: Text(
                                _attachmentActionLabel(attachment.contentType),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmSaveWithoutAttachments(
    BuildContext dialogContext,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Attachments unavailable'),
          content: Text(
            '$message\n\nYou can still save the task template without files.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save Without Files'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _openAttachment(_TaskAttachmentRecord attachment) async {
    final resolvedUrl = attachment.downloadUrl.isNotEmpty
        ? attachment.downloadUrl
        : await _getAttachmentDownloadUrl(attachment);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid attachment URL.')));
      return;
    }

    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open ${attachment.fileName}.')),
      );
    }
  }

  Future<_AttachmentPickResult> _pickTaskAttachments() async {
    final result = await pickTaskAttachments();

    return _AttachmentPickResult(
      files: result.files
          .map(
            (file) => _SelectedTaskAttachment(
              fileName: file.name,
              bytes: Uint8List.fromList(file.bytes),
              sizeBytes: file.size,
              contentType: file.contentType.isEmpty
                  ? _inferContentTypeFromFileName(file.name)
                  : file.contentType,
            ),
          )
          .toList(),
      errorMessage: result.errorMessage,
    );
  }
}

class _TaskMetricCard extends StatelessWidget {
  const _TaskMetricCard({
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
      width: 220,
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

class _TaskTemplateRecord {
  const _TaskTemplateRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.comments,
    required this.attachments,
    required this.rewardPoints,
    required this.recurringDaily,
    required this.templateStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _TaskTemplateRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _TaskTemplateRecord(
      id: snapshot.id,
      title: _readString(data['title'], fallback: 'Untitled task'),
      description: _readString(data['description']),
      comments: _readString(data['comments']),
      attachments: _readAttachments(data['attachments']),
      rewardPoints: _readInt(data['rewardPoints']),
      recurringDaily: data['recurringDaily'] == true,
      templateStatus: _readString(data['templateStatus'], fallback: 'active'),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  final String id;
  final String title;
  final String description;
  final String comments;
  final List<_TaskAttachmentRecord> attachments;
  final int rewardPoints;
  final bool recurringDaily;
  final String templateStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class _AssignedTaskRecord {
  const _AssignedTaskRecord({
    required this.taskTitle,
    required this.childName,
    required this.rewardPoints,
    required this.status,
    required this.dueDate,
    required this.createdAt,
  });

  factory _AssignedTaskRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    return _AssignedTaskRecord(
      taskTitle: _readString(data['taskTitle'], fallback: 'Assigned task'),
      childName: _readString(data['childName'], fallback: 'Unknown child'),
      rewardPoints: _readInt(data['rewardPoints']),
      status: _assignmentStatusFromString(
        _readString(data['status'], fallback: 'assigned'),
      ),
      dueDate: _readDateTime(data['dueDate']),
      createdAt:
          _readDateTime(data['createdAt']) ?? _readDateTime(data['assignedAt']),
    );
  }

  final String taskTitle;
  final String childName;
  final int rewardPoints;
  final AssignmentStatus status;
  final DateTime? dueDate;
  final DateTime? createdAt;
}

class _ActiveChildRecord {
  const _ActiveChildRecord({required this.id, required this.name});

  factory _ActiveChildRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return _ActiveChildRecord(
      id: snapshot.id,
      name: _readString(data['name'], fallback: 'Child'),
    );
  }

  final String id;
  final String name;
}

class _TemplateStatusChip extends StatelessWidget {
  const _TemplateStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isActive ? VanavilPalette.leaf : VanavilPalette.coral)
            .withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Active' : 'Archived',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: VanavilPalette.ink,
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({required this.label, required this.color});

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

class _TasksErrorState extends StatelessWidget {
  const _TasksErrorState({required this.title, required this.message});

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

class _TasksEmptyState extends StatelessWidget {
  const _TasksEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

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
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedTaskAttachment {
  const _SelectedTaskAttachment({
    required this.fileName,
    required this.bytes,
    required this.sizeBytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final int sizeBytes;
  final String contentType;
}

class _AttachmentPickResult {
  const _AttachmentPickResult({required this.files, this.errorMessage});

  final List<_SelectedTaskAttachment> files;
  final String? errorMessage;
}

class _TaskAttachmentRecord {
  const _TaskAttachmentRecord({
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.provider,
    required this.bucket,
    required this.region,
    required this.objectKey,
    required this.storagePath,
    required this.downloadUrl,
  });

  factory _TaskAttachmentRecord.fromMap(Map<String, dynamic> map) {
    return _TaskAttachmentRecord(
      fileName: _readString(map['fileName'], fallback: 'attachment'),
      contentType: _readString(map['contentType']),
      sizeBytes: _readInt(map['sizeBytes']),
      provider: _readString(map['provider']),
      bucket: _readString(map['bucket']),
      region: _readString(map['region']),
      objectKey: _readString(
        map['objectKey'],
        fallback: _readString(map['storagePath']),
      ),
      storagePath: _readString(
        map['storagePath'],
        fallback: _readString(map['objectKey']),
      ),
      downloadUrl: _readString(map['downloadUrl']),
    );
  }

  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String provider;
  final String bucket;
  final String region;
  final String objectKey;
  final String storagePath;
  final String downloadUrl;
}

class _TaskAttachmentUploadPlan {
  const _TaskAttachmentUploadPlan({
    required this.bucket,
    required this.region,
    required this.objectKey,
    required this.contentType,
  });

  factory _TaskAttachmentUploadPlan.fromMap(Map<String, dynamic> map) {
    return _TaskAttachmentUploadPlan(
      bucket: _readString(map['bucket']),
      region: _readString(map['region']),
      objectKey: _readString(map['objectKey']),
      contentType: _readString(
        map['contentType'],
        fallback: 'application/octet-stream',
      ),
    );
  }

  final String bucket;
  final String region;
  final String objectKey;
  final String contentType;
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

List<_TaskAttachmentRecord> _readAttachments(dynamic value) {
  if (value is! List) {
    return const <_TaskAttachmentRecord>[];
  }

  return value
      .whereType<Map>()
      .map(
        (entry) => _TaskAttachmentRecord.fromMap(
          entry.map((key, item) => MapEntry(key.toString(), item)),
        ),
      )
      .toList();
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
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
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
    return 'Today, $timeLabel';
  }
  if (dateOnly == tomorrow) {
    return 'Tomorrow, $timeLabel';
  }
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

String _buildAttachmentUploadErrorMessage(Object error) {
  final rawMessage = error.toString();
  final normalized = rawMessage.toLowerCase();

  if (normalized.contains('vanavil_s3_api_base_url') ||
      normalized.contains('s3 api base url')) {
    return 'Task files were not uploaded because the S3 signing API URL is not configured for this admin app. Start the Python API and pass VANAVIL_S3_API_BASE_URL when running Flutter.';
  }

  if (normalized.contains('aws s3 is not configured') ||
      normalized.contains('aws_access_key_id') ||
      normalized.contains('aws_secret_access_key') ||
      normalized.contains('signature') ||
      normalized.contains('s3') && normalized.contains('cors')) {
    return 'Task files were not uploaded because AWS S3 is not fully configured for this project. Save the task without files or finish the S3 backend setup first.';
  }

  return 'Task files were not uploaded: $rawMessage';
}

Future<_TaskAttachmentUploadPlan> _uploadAttachmentThroughApi({
  required String taskId,
  required _SelectedTaskAttachment attachment,
}) async {
  final request = http.MultipartRequest(
    'POST',
    _buildS3ApiUri('/attachments/upload'),
  );
  request.headers.addAll(await _buildS3ApiAuthHeaders());
  request.fields['taskId'] = taskId;
  request.fields['fileName'] = attachment.fileName;
  request.fields['contentType'] = attachment.contentType;
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      attachment.bytes,
      filename: attachment.fileName,
    ),
  );

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  _throwIfS3ApiFailed(
    response,
    fallbackMessage: 'Unable to upload the file to S3.',
  );

  return _TaskAttachmentUploadPlan.fromMap(_decodeJsonObject(response.body));
}

Future<void> _deleteUploadedS3Objects(List<String> objectKeys) async {
  if (objectKeys.isEmpty) {
    return;
  }

  try {
    final response = await http.post(
      _buildS3ApiUri('/attachments/delete'),
      headers: await _buildS3ApiJsonHeaders(),
      body: jsonEncode(<String, dynamic>{'attachmentKeys': objectKeys}),
    );
    _throwIfS3ApiFailed(
      response,
      fallbackMessage: 'Unable to clean up uploaded S3 files.',
    );
  } catch (_) {
    // Keep the UI flow moving. Cleanup is best-effort only.
  }
}

Future<String> _getAttachmentDownloadUrl(
  _TaskAttachmentRecord attachment,
) async {
  if (attachment.objectKey.isEmpty) {
    throw Exception('Attachment is missing its S3 object key.');
  }

  final response = await http.post(
    _buildS3ApiUri('/attachments/download-url'),
    headers: await _buildS3ApiJsonHeaders(),
    body: jsonEncode(<String, dynamic>{
      'objectKey': attachment.objectKey,
      'fileName': attachment.fileName,
      'contentType': attachment.contentType,
    }),
  );
  _throwIfS3ApiFailed(
    response,
    fallbackMessage: 'Unable to open the S3 attachment.',
  );

  final data = _decodeJsonObject(response.body);
  return _readString(data['downloadUrl']);
}

Uri _buildS3ApiUri(String path) {
  final configuredBaseUrl = _s3ApiBaseUrl.trim();
  if (configuredBaseUrl.isEmpty) {
    throw Exception(
      'VANAVIL_S3_API_BASE_URL is not configured. Start the attachment API and pass --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000.',
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
    throw Exception('Unable to authorize the S3 API request. Sign in again.');
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

  throw Exception('Unexpected response from the S3 API.');
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

String _inferContentTypeFromFileName(String fileName) {
  final fileParts = fileName.split('.');
  final extension = fileParts.length > 1 ? fileParts.last.toLowerCase() : null;
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'avi':
      return 'video/x-msvideo';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'm4a':
      return 'audio/mp4';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'zip':
      return 'application/zip';
    default:
      return 'application/octet-stream';
  }
}
