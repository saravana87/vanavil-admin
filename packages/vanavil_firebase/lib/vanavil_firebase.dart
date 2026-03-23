library;

class FirestoreCollections {
  static const admins = 'admins';
  static const children = 'children';
  static const tasks = 'tasks';
  static const assignments = 'assignments';
  static const submissions = 'submissions';
  static const reviews = 'reviews';
  static const pointsLedger = 'points_ledger';
  static const badges = 'badges';
  static const childBadges = 'child_badges';
  static const announcements = 'announcements';
  static const notifications = 'notifications';
}

class CloudFunctionNames {
  static const verifyChildPin = 'verifyChildPin';
  static const setChildPin = 'setChildPin';
  static const approveSubmission = 'approveSubmission';
  static const rejectSubmission = 'rejectSubmission';
  static const awardBadge = 'awardBadge';
}

class VanavilFirebaseBootstrap {
  const VanavilFirebaseBootstrap({required this.isConfigured});

  final bool isConfigured;

  String get statusLabel =>
      isConfigured ? 'Firebase configured' : 'Firebase setup pending';
}

class VanavilSetupGuide {
  static const adminSteps = <String>[
    'Create the Firebase project',
    'Enable Email/Password auth',
    'Run flutterfire configure inside apps/admin_web',
    'Create the admins collection and first admin user',
  ];

  static const childSteps = <String>[
    'Run flutterfire configure inside apps/child_app',
    'Run the Python auth API with /child-auth/verify-pin and /admin/children/set-pin',
    'Create active child profiles in Firestore',
    'Connect FCM and S3-backed attachments after auth is working',
  ];
}

class AuthActionNotReady implements Exception {
  const AuthActionNotReady(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminAuthGateway {
  const AdminAuthGateway();

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    throw const AuthActionNotReady(
      'Firebase sign-in is not wired yet. Finish flutterfire configure first.',
    );
  }
}

class ChildAuthGateway {
  const ChildAuthGateway();

  Future<void> verifyChildPin({
    required String childId,
    required String pin,
  }) async {
    throw const AuthActionNotReady(
      'Child PIN verification now runs through the Python API, not Firebase Functions.',
    );
  }
}
