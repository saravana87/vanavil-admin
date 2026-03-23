import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAccess {
  const AdminAccess({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
  });

  factory AdminAccess.fromSnapshot({
    required User user,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final email = _readString(data['email'], fallback: user.email ?? '');
    return AdminAccess(
      uid: user.uid,
      email: email,
      name: _readString(
        data['name'],
        fallback: email.isEmpty ? 'Admin User' : email.split('@').first,
      ),
      role: _normalizeRole(_readString(data['role'], fallback: 'admin')),
      status: _readString(data['status'], fallback: 'active').toLowerCase(),
    );
  }

  final String uid;
  final String email;
  final String name;
  final String role;
  final String status;

  bool get isSuperAdmin => role == 'super_admin';
  bool get isActive => status == 'active';
  String get roleLabel => isSuperAdmin ? 'Super Admin' : 'Admin';

  static String _normalizeRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'super-admin':
      case 'superadmin':
      case 'super_admin':
        return 'super_admin';
      default:
        return 'admin';
    }
  }
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return fallback;
}

const String reservedSuperAdminEmailLocalPart = 'saravana.genai';

bool isReservedSuperAdminEmail(String email) {
  final trimmed = email.trim().toLowerCase();
  if (trimmed.isEmpty || !trimmed.contains('@')) {
    return false;
  }

  return trimmed.split('@').first == reservedSuperAdminEmailLocalPart;
}
