# Firebase Cloud Messaging — Push Notifications (VANAVIL)

## Overview
FCM is used in VANAVIL to notify children about:
- New task assigned
- Submission approved
- Submission rejected
- Badge received
- New announcement posted

---

## Setup

```bash
flutter pub add firebase_messaging
```

### Android Setup

In `android/app/build.gradle`, ensure `minSdkVersion` is at least 21.

### iOS Setup

1. In Xcode, enable **Push Notifications** capability
2. Enable **Background Modes** → **Remote notifications**
3. Upload APNs key to Firebase Console → Project Settings → Cloud Messaging

---

## Initialize FCM in Flutter

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const VanavilApp());
}
```

---

## Request Permission

```dart
final messaging = FirebaseMessaging.instance;

final settings = await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
  announcement: false,
  carPlay: false,
  criticalAlert: false,
  provisional: false,
);

if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  print('User granted permission');
} else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
  print('User granted provisional permission');
} else {
  print('User declined permission');
}
```

---

## Get Device Token

Store the token in Firestore to send targeted notifications:

```dart
// On Apple platforms, wait for APNs before requesting the FCM token.
final apnsToken = await FirebaseMessaging.instance.getAPNSToken();

// Get the token
final token = await FirebaseMessaging.instance.getToken();

// Save token to child's document in Firestore
if (token != null) {
  await FirebaseFirestore.instance.collection('children').doc(childId).update({
    'fcmToken': token,
  });
}

// Listen for token refresh
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  FirebaseFirestore.instance.collection('children').doc(childId).update({
    'fcmToken': newToken,
  });
});
```

Notes:
- On iOS and iPadOS, ensure the APNs token is available before depending on FCM token calls
- If you later add web push for the admin site, `getToken()` needs a VAPID public key

---

## Receiving Messages

### Foreground Messages

```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Foreground message: ${message.notification?.title}');

  // In production, route this through app state or a local notification service.
  // Avoid trying to use an arbitrary BuildContext directly inside the stream callback.
});
```

### Message Opened (App in Background, User Taps Notification)

```dart
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('User tapped notification: ${message.data}');

  // Navigate based on notification type
  final type = message.data['type'];
  switch (type) {
    case 'new_task':
      Navigator.pushNamed(context, '/my-tasks');
      break;
    case 'submission_approved':
    case 'submission_rejected':
      Navigator.pushNamed(context, '/task-details', arguments: message.data['assignmentId']);
      break;
    case 'badge_received':
      Navigator.pushNamed(context, '/my-badges');
      break;
    case 'announcement':
      Navigator.pushNamed(context, '/announcements');
      break;
  }
});
```

### App Opened from Terminated State via Notification

```dart
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  // Handle navigation based on initialMessage.data
}
```

---

## Sending Notifications via Cloud Functions

### When Admin Assigns a Task

```javascript
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

exports.onAssignmentCreated = onDocumentCreated("assignments/{assignmentId}", async (event) => {
  const assignment = event.data.data();
  const childDoc = await getFirestore().collection("children").doc(assignment.childId).get();
  const child = childDoc.data();

  if (!child.fcmToken) return;

  const taskDoc = await getFirestore().collection("tasks").doc(assignment.taskId).get();
  const task = taskDoc.data();

  await getMessaging().send({
    token: child.fcmToken,
    notification: {
      title: "New Task Assigned!",
      body: `You have a new task: ${task.title}`,
    },
    data: {
      type: "new_task",
      assignmentId: event.params.assignmentId,
    },
  });

  // Save notification record
  await getFirestore().collection("notifications").add({
    childId: assignment.childId,
    type: "new_task",
    title: "New Task Assigned!",
    message: `You have a new task: ${task.title}`,
    isRead: false,
    createdAt: new Date(),
  });
});
```

### When Admin Approves/Rejects Submission

```javascript
exports.onReviewCreated = onDocumentCreated("reviews/{reviewId}", async (event) => {
  const review = event.data.data();
  const assignmentDoc = await getFirestore().collection("assignments").doc(review.assignmentId).get();
  const assignment = assignmentDoc.data();
  const childDoc = await getFirestore().collection("children").doc(assignment.childId).get();
  const child = childDoc.data();

  if (!child.fcmToken) return;

  const isApproved = review.decision === "approved";
  const title = isApproved ? "Task Approved!" : "Task Needs Revision";
  const body = isApproved
    ? `Great job! You earned ${review.pointsAwarded} points!`
    : `Your submission needs changes: ${review.comment}`;

  await getMessaging().send({
    token: child.fcmToken,
    notification: { title, body },
    data: {
      type: isApproved ? "submission_approved" : "submission_rejected",
      assignmentId: review.assignmentId,
    },
  });
});
```

---

## VANAVIL Notification Types Summary

| Type                  | Trigger                          | Recipient |
|-----------------------|----------------------------------|-----------|
| `new_task`            | Assignment created               | Child     |
| `submission_approved` | Admin approves submission        | Child     |
| `submission_rejected` | Admin rejects submission         | Child     |
| `badge_received`      | Admin awards badge               | Child     |
| `announcement`        | Admin posts announcement         | All children |

---

## Official Documentation Links
- [Cloud Messaging Overview](https://firebase.google.com/docs/cloud-messaging)
- [FCM Flutter — Get Started](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [FCM Flutter — Client Setup](https://firebase.google.com/docs/cloud-messaging/flutter/client)
- [FCM Flutter — Receive Messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [FCM Flutter Codelab](https://firebase.google.com/codelabs/firebase-fcm-flutter)
