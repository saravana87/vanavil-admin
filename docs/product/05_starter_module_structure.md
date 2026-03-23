# VANAVIL Starter Module Structure

## Recommended Workspace Structure

```text
vanavil/
  apps/
    admin_web/
      lib/
        app/
        bootstrap/
        features/
        routes/
        screens/
      web/
      pubspec.yaml
    child_app/
      lib/
        app/
        bootstrap/
        features/
        routes/
        screens/
      android/
      ios/
      pubspec.yaml
  packages/
    vanavil_core/
      lib/
        enums/
        models/
        validators/
        utils/
    vanavil_firebase/
      lib/
        firestore/
        functions/
        repositories/
        storage/
        messaging/
    vanavil_ui/
      lib/
        theme/
        widgets/
        components/
  functions/
    src/
      auth/
      assignments/
      badges/
      notifications/
    package.json
  firebase/
    firestore.rules
    firestore.indexes.json
```

---

## Flutter Feature Breakdown

### Shared Core Package

Suggested models:

- `AdminProfile`
- `ChildProfile`
- `TaskTemplate`
- `Assignment`
- `Submission`
- `Review`
- `PointsLedgerEntry`
- `BadgeDefinition`
- `ChildBadge`
- `Announcement`
- `AppNotification`

Suggested enums:

- `AssignmentStatus`
- `SubmissionProofType`
- `ReviewDecision`
- `NotificationType`
- `ChildStatus`

Suggested validators:

- email validator
- 4-digit PIN validator
- task form validator
- announcement validator

### Admin Web Features

- `auth_admin`
- `dashboard`
- `children_management`
- `tasks_management`
- `assignment_review`
- `reports`
- `badges_management`
- `announcements_management`

### Child App Features

- `profile_select`
- `pin_auth`
- `child_dashboard`
- `my_tasks`
- `task_detail`
- `upload_proof`
- `rewards`
- `announcements`
- `notifications`

---

## Repositories

Recommended repository contracts:

- `AuthRepository`
- `ChildrenRepository`
- `TasksRepository`
- `AssignmentsRepository`
- `SubmissionsRepository`
- `ReviewsRepository`
- `PointsRepository`
- `BadgesRepository`
- `AnnouncementsRepository`
- `NotificationsRepository`

Recommended concrete Firebase implementations:

- `FirebaseAuthRepository`
- `FirestoreChildrenRepository`
- `FirestoreTasksRepository`
- `FirestoreAssignmentsRepository`
- `FirestoreSubmissionsRepository`
- `FirestorePointsRepository`
- `FirestoreBadgesRepository`
- `FirestoreAnnouncementsRepository`
- `FirestoreNotificationsRepository`

---

## Firebase Integration Plan

### Admin Web

1. initialize Firebase
2. observe admin auth session
3. load admin profile from `admins`
4. expose guarded routes
5. create and manage documents in Firestore
6. call Cloud Functions for protected actions

### Child App

1. load active child profiles
2. child selects profile
3. child enters PIN
4. call `verifyChildPin`
5. sign in with returned custom token
6. load assignment, announcement, badge, and points streams
7. register FCM token post-login

### Cloud Functions

Callable functions to implement first:

- `verifyChildPin`
- `setChildPin`
- `approveSubmission`
- `rejectSubmission`
- `awardBadge`

Triggers to implement after core flow works:

- `onAssignmentCreated`
- `onReviewCreated`
- `onAnnouncementCreated`
- `onChildBadgeCreated`

---

## Starter Code Skeletons

### Shared Model Example

```dart
enum AssignmentStatus {
  assigned,
  submitted,
  approved,
  completed,
  rejected,
}

class Assignment {
  const Assignment({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.childId,
    required this.childName,
    required this.rewardPoints,
    required this.status,
    required this.dueDate,
  });

  final String id;
  final String taskId;
  final String taskTitle;
  final String childId;
  final String childName;
  final int rewardPoints;
  final AssignmentStatus status;
  final DateTime dueDate;
}
```

### Repository Contract Example

```dart
abstract interface class AssignmentsRepository {
  Stream<List<Assignment>> watchChildActiveAssignments(String childId);
  Stream<List<Assignment>> watchPendingReviews();
  Future<void> submitAssignment({
    required String assignmentId,
  });
}
```

### Admin Route Guard Example

```dart
Future<bool> requireAdmin(User? user) async {
  if (user == null) return false;

  final doc = await FirebaseFirestore.instance
      .collection('admins')
      .doc(user.uid)
      .get();

  return doc.exists;
}
```

### Child PIN Login Flow Example

```dart
Future<void> signInChild({
  required String childId,
  required String pin,
}) async {
  final callable = FirebaseFunctions.instance.httpsCallable('verifyChildPin');
  final result = await callable.call({
    'childId': childId,
    'pin': pin,
  });

  final token = result.data['token'] as String;
  await FirebaseAuth.instance.signInWithCustomToken(token);
}
```

---

## MVP-First Implementation Approach

### Sprint 1

- bootstrap both apps
- shared theme tokens
- Firebase initialization
- admin auth
- child PIN auth

### Sprint 2

- children CRUD
- tasks CRUD
- assignment create and list
- child task listing and detail

### Sprint 3

- upload proof
- submit assignment
- review queue
- approve and reject functions

### Sprint 4

- points page
- completed tasks page
- badges
- announcements
- push notifications

### Sprint 5

- dashboard polish
- reports
- emulator tests
- rules and index validation

This order produces a usable end-to-end MVP before adding polish-heavy features.
