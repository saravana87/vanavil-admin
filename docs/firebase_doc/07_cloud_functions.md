# Firebase Cloud Functions (VANAVIL)

## Overview
Cloud Functions handle server-side logic for VANAVIL:
- **Child PIN verification** and custom token generation
- **Task approval workflow** — update statuses, award points
- **Firestore triggers** — send notifications on data changes
- **Scheduled tasks** — recurring daily task assignment

---

## Setup

### Install Firebase Functions

```bash
firebase init functions
```

Choose **JavaScript** or **TypeScript**. This creates a `functions/` directory.

### Install Dependencies

```bash
cd functions
npm install firebase-admin firebase-functions bcrypt
```

Use a currently supported Node.js runtime for Functions. As of the latest official docs, Node.js 20 and 22 are supported, while Node 18 has already been deprecated.

### Deploy

```bash
firebase deploy --only functions
```

Deploying Cloud Functions requires the project to be on the Blaze plan.

---

## Flutter Client Setup

```bash
flutter pub add cloud_functions
```

```dart
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instance;
```

---

## Callable Functions

### 1. Child PIN Verification

```javascript
// functions/index.js
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const bcrypt = require("bcrypt");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

exports.verifyChildPin = onCall(async (request) => {
  const { childId, pin } = request.data;

  if (!childId || !pin) {
    throw new HttpsError("invalid-argument", "childId and pin are required");
  }

  const db = getFirestore();
  const childDoc = await db.collection("children").doc(childId).get();

  if (!childDoc.exists) {
    throw new HttpsError("not-found", "Child not found");
  }

  const child = childDoc.data();

  if (child.status !== "active") {
    throw new HttpsError("permission-denied", "Account is deactivated");
  }

  const pinMatch = await bcrypt.compare(pin, child.pinCodeHash);
  if (!pinMatch) {
    throw new HttpsError("unauthenticated", "Invalid PIN");
  }

  const customToken = await getAuth().createCustomToken(`child_${childId}`, {
    role: "child",
    childId: childId,
  });

  return { token: customToken };
});
```

**Flutter call:**
```dart
try {
  final result = await functions.httpsCallable('verifyChildPin').call({
    'childId': selectedChildId,
    'pin': enteredPin,
  });
  await FirebaseAuth.instance.signInWithCustomToken(result.data['token']);
} on FirebaseFunctionsException catch (e) {
  print('Error: ${e.code} - ${e.message}');
}
```

### 2. Approve Task Submission

```javascript
exports.approveSubmission = onCall(async (request) => {
  // Verify caller is an admin
  const adminDoc = await getFirestore().collection("admins").doc(request.auth.uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Only admins can approve submissions");
  }

  const { assignmentId, comment, pointsAwarded } = request.data;
  const db = getFirestore();
  const batch = db.batch();

  // Update assignment status
  const assignmentRef = db.collection("assignments").doc(assignmentId);
  batch.update(assignmentRef, {
    status: "completed",
    approvedAt: new Date(),
  });

  // Create review record
  const reviewRef = db.collection("reviews").doc();
  batch.set(reviewRef, {
    assignmentId,
    adminId: request.auth.uid,
    decision: "approved",
    comment: comment || "",
    pointsAwarded,
    reviewedAt: new Date(),
  });

  // Get child ID from assignment
  const assignment = (await assignmentRef.get()).data();

  // Add to points ledger
  const ledgerRef = db.collection("points_ledger").doc();
  batch.set(ledgerRef, {
    childId: assignment.childId,
    assignmentId,
    points: pointsAwarded,
    reason: "Task approved",
    createdAt: new Date(),
  });

  // Update child's total points
  const childRef = db.collection("children").doc(assignment.childId);
  batch.update(childRef, {
    totalPoints: require("firebase-admin/firestore").FieldValue.increment(pointsAwarded),
  });

  await batch.commit();

  return { success: true };
});
```

### 3. Reject Task Submission

```javascript
exports.rejectSubmission = onCall(async (request) => {
  const adminDoc = await getFirestore().collection("admins").doc(request.auth.uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Only admins can reject submissions");
  }

  const { assignmentId, comment } = request.data;
  const db = getFirestore();
  const batch = db.batch();

  batch.update(db.collection("assignments").doc(assignmentId), {
    status: "rejected",
    rejectedAt: new Date(),
  });

  batch.set(db.collection("reviews").doc(), {
    assignmentId,
    adminId: request.auth.uid,
    decision: "rejected",
    comment: comment || "Please try again",
    pointsAwarded: 0,
    reviewedAt: new Date(),
  });

  await batch.commit();

  return { success: true };
});
```

---

## Firestore Triggers

### On Assignment Created → Notify Child

```javascript
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");

exports.onAssignmentCreated = onDocumentCreated("assignments/{assignmentId}", async (event) => {
  const assignment = event.data.data();
  const db = getFirestore();

  const childDoc = await db.collection("children").doc(assignment.childId).get();
  const child = childDoc.data();
  const taskDoc = await db.collection("tasks").doc(assignment.taskId).get();
  const task = taskDoc.data();

  // Send push notification
  if (child.fcmToken) {
    await getMessaging().send({
      token: child.fcmToken,
      notification: {
        title: "New Task!",
        body: task.title,
      },
      data: {
        type: "new_task",
        assignmentId: event.params.assignmentId,
      },
    });
  }

  // Save notification record
  await db.collection("notifications").add({
    childId: assignment.childId,
    type: "new_task",
    title: "New Task!",
    message: task.title,
    isRead: false,
    createdAt: new Date(),
  });
});
```

### On Announcement Created → Notify All Children

```javascript
exports.onAnnouncementCreated = onDocumentCreated("announcements/{announcementId}", async (event) => {
  const announcement = event.data.data();
  const db = getFirestore();

  const childrenSnapshot = await db.collection("children")
    .where("status", "==", "active")
    .get();

  const promises = childrenSnapshot.docs.map(async (childDoc) => {
    const child = childDoc.data();

    // Send push notification
    if (child.fcmToken) {
      await getMessaging().send({
        token: child.fcmToken,
        notification: {
          title: announcement.title,
          body: announcement.message,
        },
        data: { type: "announcement" },
      });
    }

    // Save notification record
    await db.collection("notifications").add({
      childId: childDoc.id,
      type: "announcement",
      title: announcement.title,
      message: announcement.message,
      isRead: false,
      createdAt: new Date(),
    });
  });

  await Promise.all(promises);
});
```

### On Badge Awarded → Notify Child

```javascript
exports.onBadgeAwarded = onDocumentCreated("child_badges/{childBadgeId}", async (event) => {
  const childBadge = event.data.data();
  const db = getFirestore();

  const childDoc = await db.collection("children").doc(childBadge.childId).get();
  const child = childDoc.data();
  const badgeDoc = await db.collection("badges").doc(childBadge.badgeId).get();
  const badge = badgeDoc.data();

  if (child.fcmToken) {
    await getMessaging().send({
      token: child.fcmToken,
      notification: {
        title: "New Badge!",
        body: `You earned the "${badge.title}" badge!`,
      },
      data: { type: "badge_received" },
    });
  }

  await db.collection("notifications").add({
    childId: childBadge.childId,
    type: "badge_received",
    title: "New Badge!",
    message: `You earned the "${badge.title}" badge!`,
    isRead: false,
    createdAt: new Date(),
  });
});
```

---

## Error Handling in Flutter

```dart
try {
  final result = await functions.httpsCallable('approveSubmission').call({
    'assignmentId': assignmentId,
    'comment': 'Great work!',
    'pointsAwarded': 10,
  });
  print('Success: ${result.data}');
} on FirebaseFunctionsException catch (e) {
  switch (e.code) {
    case 'permission-denied':
      print('You do not have permission');
      break;
    case 'not-found':
      print('Resource not found');
      break;
    default:
      print('Error: ${e.message}');
  }
}
```

---

## Local Testing with Emulator

Use the Emulator Suite during development for callable PIN verification, task approval flows, and notification trigger testing before deploying.

```dart
// Connect to local emulator (add before any function calls)
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

// For Android emulator, use:
FirebaseFunctions.instance.useFunctionsEmulator('10.0.2.2', 5001);
```

```bash
# Start emulator
firebase emulators:start --only functions
```

---

## Official Documentation Links
- [Cloud Functions Overview](https://firebase.google.com/docs/functions)
- [Get Started with Cloud Functions](https://firebase.google.com/docs/functions/get-started)
- [Callable Functions](https://firebase.google.com/docs/functions/callable)
- [HTTP Functions](https://firebase.google.com/docs/functions/http-events)
- [Firestore Triggers](https://firebase.google.com/docs/functions/firestore-events)
- [Connect to Functions Emulator](https://firebase.google.com/docs/emulator-suite/connect_functions)
