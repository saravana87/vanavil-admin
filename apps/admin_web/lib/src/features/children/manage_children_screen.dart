import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vanavil_firebase/vanavil_firebase.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../app/admin_access.dart';

const String _adminApiBaseUrl = String.fromEnvironment(
  'VANAVIL_S3_API_BASE_URL',
);

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key, required this.access});

  final AdminAccess access;

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Sign in again to continue.'));
    }

    Query<Map<String, dynamic>> childrenQuery = FirebaseFirestore.instance
        .collection(FirestoreCollections.children);
    if (!widget.access.isSuperAdmin) {
      childrenQuery = childrenQuery.where(
        'adminId',
        isEqualTo: currentUser.uid,
      );
    }

    final childrenStream = childrenQuery.snapshots();

    return Padding(
      padding: const EdgeInsets.all(28),
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
                      'Manage children',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create child profiles, review status, and control access from one screen.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _isCreating ? null : _showAddChildDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: VanavilPalette.sky,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                child: const Text('Add Child'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: childrenStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: VanavilSectionCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unable to load children',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              snapshot.error.toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final children =
                    snapshot.data?.docs
                        .map(_ManagedChildRecord.fromSnapshot)
                        .toList() ??
                    <_ManagedChildRecord>[];
                children.sort((left, right) => left.name.compareTo(right.name));

                final activeChildren = children
                    .where((child) => child.isActive)
                    .length;
                final inactiveChildren = children.length - activeChildren;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _ChildrenMetricCard(
                          label: 'Total Children',
                          value: '${children.length}',
                          accent: VanavilPalette.sky,
                        ),
                        _ChildrenMetricCard(
                          label: 'Active',
                          value: '$activeChildren',
                          accent: VanavilPalette.leaf,
                        ),
                        _ChildrenMetricCard(
                          label: 'Inactive',
                          value: '$inactiveChildren',
                          accent: VanavilPalette.coral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: VanavilSectionCard(
                        child: children.isEmpty
                            ? Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'No child profiles yet',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Create the first child profile to start assigning tasks and tracking points.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton(
                                        onPressed: _isCreating
                                            ? null
                                            : _showAddChildDialog,
                                        child: const Text('Add Child'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: children.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final child = children[index];
                                  return Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: VanavilPalette.cream,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: VanavilPalette.sky
                                              .withValues(alpha: 0.14),
                                          foregroundColor: VanavilPalette.ink,
                                          child: Text(child.avatar),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                child.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: VanavilPalette.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Age ${child.age} • ${child.totalPoints} pts • ${child.badgeCount} badges',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                child.lastLoginAt == null
                                                    ? 'No child login yet'
                                                    : 'Last login ${_formatDate(context, child.lastLoginAt!)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: child.isActive
                                                    ? VanavilPalette.leaf
                                                          .withValues(
                                                            alpha: 0.16,
                                                          )
                                                    : VanavilPalette.coral
                                                          .withValues(
                                                            alpha: 0.16,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                child.isActive
                                                    ? 'Active'
                                                    : 'Inactive',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: VanavilPalette.ink,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showSetPinDialog(child),
                                              icon: const Icon(
                                                Icons.pin_rounded,
                                              ),
                                              label: const Text('Set PIN'),
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Access',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                ),
                                                Switch(
                                                  value: child.isActive,
                                                  onChanged: (isActive) {
                                                    _updateChildStatus(
                                                      child: child,
                                                      isActive: isActive,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddChildDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final avatarController = TextEditingController();
    var isActive = true;
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

              final name = nameController.text.trim();
              final age = int.parse(ageController.text.trim());
              final avatar = avatarController.text.trim().isEmpty
                  ? name.characters.first.toUpperCase()
                  : avatarController.text.trim().characters.first.toUpperCase();

              setDialogState(() {
                isSaving = true;
                errorMessage = null;
              });
              setState(() {
                _isCreating = true;
              });

              try {
                await FirebaseFirestore.instance
                    .collection(FirestoreCollections.children)
                    .add({
                      'adminId': currentUser.uid,
                      'name': name,
                      'avatar': avatar,
                      'age': age,
                      'status': isActive ? 'active' : 'inactive',
                      'totalPoints': 0,
                      'badgeCount': 0,
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
              } finally {
                if (mounted) {
                  setState(() {
                    _isCreating = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Add child profile'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Child name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the child name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = int.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed < 1 || parsed > 18) {
                            return 'Enter an age between 1 and 18';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: avatarController,
                        decoration: const InputDecoration(
                          labelText: 'Avatar letter',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 1,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active profile'),
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
                  child: Text(isSaving ? 'Creating...' : 'Create Child'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    ageController.dispose();
    avatarController.dispose();
  }

  Future<void> _updateChildStatus({
    required _ManagedChildRecord child,
    required bool isActive,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.children)
          .doc(child.id)
          .update({
            'status': isActive ? 'active' : 'inactive',
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

  Future<void> _showSetPinDialog(_ManagedChildRecord child) async {
    final formKey = GlobalKey<FormState>();
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
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

              final scaffoldMessenger = ScaffoldMessenger.of(this.context);

              setDialogState(() {
                isSaving = true;
                errorMessage = null;
              });

              try {
                await _setChildPin(
                  childId: child.id,
                  pin: pinController.text.trim(),
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('PIN updated for ${child.name}.')),
                );
              } catch (error) {
                setDialogState(() {
                  errorMessage = error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  );
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Set PIN for ${child.name}'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'New 4-digit PIN',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: (value) {
                          final pin = (value ?? '').trim();
                          if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                            return 'PIN must be exactly 4 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Confirm PIN',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        validator: (value) {
                          final confirmPin = (value ?? '').trim();
                          if (confirmPin != pinController.text.trim()) {
                            return 'PIN values do not match';
                          }
                          return null;
                        },
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
                  child: Text(isSaving ? 'Saving...' : 'Save PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmPinController.dispose();
  }

  Future<void> _setChildPin({
    required String childId,
    required String pin,
  }) async {
    final response = await http.post(
      _buildAdminApiUri('/admin/children/set-pin'),
      headers: await _buildAdminApiJsonHeaders(),
      body: jsonEncode(<String, dynamic>{'childId': childId, 'pin': pin}),
    );
    _throwIfAdminApiFailed(
      response,
      fallbackMessage: 'Unable to save the child PIN.',
    );
  }
}

Uri _buildAdminApiUri(String path) {
  final configuredBaseUrl = _adminApiBaseUrl.trim();
  if (configuredBaseUrl.isEmpty) {
    throw Exception(
      'VANAVIL_S3_API_BASE_URL is not configured. Start the admin API and pass --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000.',
    );
  }

  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return Uri.parse('$configuredBaseUrl$normalizedPath');
}

Future<Map<String, String>> _buildAdminApiJsonHeaders() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw Exception('The current session expired. Sign in again.');
  }

  final idToken = await currentUser.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    throw Exception('Unable to authorize the API request. Sign in again.');
  }

  return <String, String>{
    'authorization': 'Bearer $idToken',
    'content-type': 'application/json',
  };
}

Map<String, dynamic> _decodeAdminApiJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  throw Exception('Unexpected response from the Python API.');
}

void _throwIfAdminApiFailed(
  http.Response response, {
  required String fallbackMessage,
}) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return;
  }

  try {
    final payload = _decodeAdminApiJson(response.body);
    final detail = _readString(payload['detail']);
    if (detail.isNotEmpty) {
      throw Exception(detail);
    }
  } on FormatException {
    // Fall through to the generic message.
  }

  throw Exception('$fallbackMessage HTTP ${response.statusCode}.');
}

class _ChildrenMetricCard extends StatelessWidget {
  const _ChildrenMetricCard({
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

class _ManagedChildRecord {
  const _ManagedChildRecord({
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.isActive,
    required this.totalPoints,
    required this.badgeCount,
    required this.lastLoginAt,
  });

  factory _ManagedChildRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final name = _readString(data['name'], fallback: 'Child');

    return _ManagedChildRecord(
      id: snapshot.id,
      name: name,
      avatar: _readString(
        data['avatar'],
        fallback: name.characters.first.toUpperCase(),
      ),
      age: _readInt(data['age']),
      isActive: _readString(data['status'], fallback: 'active') == 'active',
      totalPoints: _readInt(data['totalPoints']),
      badgeCount: _readInt(data['badgeCount']),
      lastLoginAt: _readDateTime(data['lastLoginAt']),
    );
  }

  final String id;
  final String name;
  final String avatar;
  final int age;
  final bool isActive;
  final int totalPoints;
  final int badgeCount;
  final DateTime? lastLoginAt;
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

String _formatDate(BuildContext context, DateTime dateTime) {
  final now = DateUtils.dateOnly(DateTime.now());
  final date = DateUtils.dateOnly(dateTime);
  if (date == now) {
    return 'today';
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
