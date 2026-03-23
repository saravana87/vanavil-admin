# Cloud Firestore — Data Model & CRUD Operations (VANAVIL)

## Overview
Cloud Firestore is the primary database for VANAVIL. It stores all data for admins, children, tasks, assignments, submissions, reviews, points, badges, announcements, and notifications.

---

## Setup

```bash
flutter pub add cloud_firestore
```

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

final db = FirebaseFirestore.instance;
```

---

## VANAVIL Firestore Collections

| Collection       | Purpose                                    |
|------------------|--------------------------------------------|
| `admins`         | Admin user profiles                        |
| `children`       | Child profiles managed by admin            |
| `tasks`          | Task templates created by admin            |
| `assignments`    | Task assignments to specific children      |
| `submissions`    | Proof uploads from children                |
| `reviews`        | Admin review decisions                     |
| `points_ledger`  | Points transaction history                 |
| `badges`         | Badge definitions                          |
| `child_badges`   | Badges awarded to children                 |
| `announcements`  | Admin announcements                        |
| `notifications`  | Push notification records                  |

---

## CRUD Operations

### Create (Add Data)

#### Auto-generated ID

```dart
// Add a new task
final docRef = await db.collection('tasks').add({
  'title': 'Clean your room',
  'description': 'Organize toys and make the bed',
  'rewardPoints': 10,
  'recurringDaily': false,
  'createdBy': adminId,
  'createdAt': FieldValue.serverTimestamp(),
});
print('Task created with ID: ${docRef.id}');
```

#### Custom ID

```dart
// Add a child with a specific ID
await db.collection('children').doc(childId).set({
  'adminId': adminId,
  'name': 'Madhu',
  'avatar': 'avatar_01',
  'pinCodeHash': hashedPin,
  'age': 8,
  'status': 'active',
  'totalPoints': 0,
  'createdAt': FieldValue.serverTimestamp(),
});
```

### Read Data

#### Get a Single Document

```dart
final docSnapshot = await db.collection('children').doc(childId).get();
if (docSnapshot.exists) {
  final data = docSnapshot.data() as Map<String, dynamic>;
  print('Child name: ${data['name']}');
}
```

#### Get All Documents in a Collection

```dart
final querySnapshot = await db.collection('tasks').get();
for (var doc in querySnapshot.docs) {
  print('${doc.id} => ${doc.data()}');
}
```

#### Query with Filters

```dart
// Get all assignments for a specific child
final assignments = await db.collection('assignments')
    .where('childId', isEqualTo: childId)
    .where('status', isEqualTo: 'assigned')
    .orderBy('dueDate')
    .get();
```

#### Real-Time Listener (Snapshots)

```dart
// Listen for new assignments in real-time
db.collection('assignments')
    .where('childId', isEqualTo: childId)
    .where('status', isEqualTo: 'assigned')
    .snapshots()
    .listen((querySnapshot) {
      for (var change in querySnapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          print('New assignment: ${change.doc.data()}');
        }
      }
    });
```

### Update Data

```dart
// Update assignment status to 'submitted'
await db.collection('assignments').doc(assignmentId).update({
  'status': 'submitted',
  'submittedAt': FieldValue.serverTimestamp(),
});
```

#### Increment a Field

```dart
// Add points to a child's total
await db.collection('children').doc(childId).update({
  'totalPoints': FieldValue.increment(pointsAwarded),
});
```

### Delete Data

```dart
// Delete a notification
await db.collection('notifications').doc(notificationId).delete();
```

#### Delete a Field

```dart
await db.collection('tasks').doc(taskId).update({
  'comments': FieldValue.delete(),
});
```

---

## VANAVIL-Specific Query Examples

### Admin Dashboard — Pending Reviews

```dart
final pendingReviews = await db.collection('assignments')
    .where('status', isEqualTo: 'submitted')
    .orderBy('submittedAt', descending: true)
    .get();
```

### Admin Dashboard — Today's Tasks

```dart
final now = DateTime.now();
final startOfDay = DateTime(now.year, now.month, now.day);
final endOfDay = startOfDay.add(const Duration(days: 1));

final todaysTasks = await db.collection('tasks')
    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
    .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
    .get();
```

### Child Dashboard — My Assigned Tasks

```dart
final myTasks = await db.collection('assignments')
    .where('childId', isEqualTo: childId)
    .where('status', whereIn: ['assigned', 'rejected'])
    .orderBy('dueDate')
    .get();
```

### Child Points Summary

```dart
final pointsHistory = await db.collection('points_ledger')
    .where('childId', isEqualTo: childId)
    .orderBy('createdAt', descending: true)
    .get();

int totalPoints = 0;
for (var doc in pointsHistory.docs) {
  totalPoints += (doc.data()['points'] as num).toInt();
}
```

---

## Offline Persistence

Firestore has built-in offline support for mobile apps. Data is cached locally and synced when connectivity is restored.

For VANAVIL:
- Android and Apple platforms can rely on Firestore's built-in offline behavior by default
- Web persistence needs deliberate handling because cached data can survive browser sessions
- For shared admin devices, do not enable persistent web cache casually without validating the exact FlutterFire/Web SDK setup you are shipping

Use the current official offline docs before enabling persistent browser cache behavior:
- https://firebase.google.com/docs/firestore/manage-data/enable-offline

Also plan required composite indexes early. Queries like child assignments by status ordered by due date and dashboard review queues usually require Firestore indexes.

---

## Using Firestore with Flutter Widgets

```dart
StreamBuilder<QuerySnapshot>(
  stream: db.collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
    if (!snapshot.hasData) return const CircularProgressIndicator();

    final announcements = snapshot.data!.docs;
    return ListView.builder(
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        final data = announcements[index].data() as Map<String, dynamic>;
        return ListTile(
          title: Text(data['title']),
          subtitle: Text(data['message']),
        );
      },
    );
  },
);
```

---

## Official Documentation Links
- [Cloud Firestore Overview](https://firebase.google.com/docs/firestore)
- [Firestore Data Model](https://firebase.google.com/docs/firestore/data-model)
- [Add Data](https://firebase.google.com/docs/firestore/manage-data/add-data)
- [Get Data](https://firebase.google.com/docs/firestore/query-data/get-data)
- [Delete Data](https://firebase.google.com/docs/firestore/manage-data/delete-data)
- [Firestore Quickstart](https://firebase.google.com/docs/firestore/quickstart)
