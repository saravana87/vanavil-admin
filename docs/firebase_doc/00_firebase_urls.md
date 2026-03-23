# Firebase Documentation URLs for VANAVIL Project

All official Firebase documentation links relevant to this project, organized by feature.

---

## Firebase Console & General

| Resource | URL |
|----------|-----|
| Firebase Console | https://console.firebase.google.com/ |
| Firebase Documentation Home | https://firebase.google.com/docs |
| Firebase Pricing | https://firebase.google.com/pricing |
| Firebase CLI Reference | https://firebase.google.com/docs/cli |
| Firebase Status Dashboard | https://status.firebase.google.com/ |

---

## FlutterFire (Flutter + Firebase)

| Resource | URL |
|----------|-----|
| Add Firebase to Flutter App | https://firebase.google.com/docs/flutter/setup |
| FlutterFire GitHub | https://github.com/firebase/flutterfire |
| FlutterFire Pub.dev Packages | https://pub.dev/publishers/firebase.google.com/packages |
| Firebase Release Notes | https://firebase.google.com/support/releases |

> Note: Prefer `firebase.google.com/docs` and package pages on `pub.dev`. Older `firebase.flutter.dev` links are legacy references and should not be used as the primary source for current setup guidance.

---

## Firebase Authentication

| Resource | URL |
|----------|-----|
| Auth Overview | https://firebase.google.com/docs/auth |
| Flutter Auth (Getting Started) | https://firebase.google.com/docs/auth/flutter/start |
| Email/Password Sign-In | https://firebase.google.com/docs/auth/flutter/password-auth |
| Custom Auth (for PIN login) | https://firebase.google.com/docs/auth/flutter/custom-auth |
| Anonymous Auth (alternative for child) | https://firebase.google.com/docs/auth/flutter/anonymous-auth |
| Manage Users | https://firebase.google.com/docs/auth/flutter/manage-users |
| Auth State Listener | https://firebase.google.com/docs/auth/flutter/start |
| Firebase Admin SDK (server-side auth) | https://firebase.google.com/docs/auth/admin |

---

## Cloud Firestore

| Resource | URL |
|----------|-----|
| Firestore Overview | https://firebase.google.com/docs/firestore |
| Firestore Quickstart | https://firebase.google.com/docs/firestore/quickstart |
| Add & Manage Data | https://firebase.google.com/docs/firestore/manage-data/add-data |
| Read Data / Queries | https://firebase.google.com/docs/firestore/query-data/get-data |
| Realtime Listeners | https://firebase.google.com/docs/firestore/query-data/listen |
| Compound Queries | https://firebase.google.com/docs/firestore/query-data/queries |
| Order & Limit Data | https://firebase.google.com/docs/firestore/query-data/order-limit-data |
| Pagination | https://firebase.google.com/docs/firestore/query-data/query-cursors |
| Data Modeling / Structure | https://firebase.google.com/docs/firestore/data-model |
| Subcollections | https://firebase.google.com/docs/firestore/data-model#subcollections |
| Indexes | https://firebase.google.com/docs/firestore/query-data/indexing |
| Transactions & Batched Writes | https://firebase.google.com/docs/firestore/manage-data/transactions |
| Offline Data | https://firebase.google.com/docs/firestore/manage-data/enable-offline |
| Firestore Security Rules | https://firebase.google.com/docs/firestore/security/get-started |
| Security Rules Reference | https://firebase.google.com/docs/firestore/security/rules-structure |
| Security Rules Conditions | https://firebase.google.com/docs/firestore/security/rules-conditions |

---

## Firebase Storage

| Resource | URL |
|----------|-----|
| Storage Overview | https://firebase.google.com/docs/storage |
| Flutter Storage (Getting Started) | https://firebase.google.com/docs/storage/flutter/start |
| Upload Files | https://firebase.google.com/docs/storage/flutter/upload-files |
| Download Files | https://firebase.google.com/docs/storage/flutter/download-files |
| File Metadata | https://firebase.google.com/docs/storage/flutter/file-metadata |
| Delete Files | https://firebase.google.com/docs/storage/flutter/delete-files |
| Storage Security Rules | https://firebase.google.com/docs/storage/security |
| Handle Errors | https://firebase.google.com/docs/storage/flutter/handle-errors |

---

## Firebase Cloud Messaging (FCM)

| Resource | URL |
|----------|-----|
| FCM Overview | https://firebase.google.com/docs/cloud-messaging |
| Flutter FCM (Getting Started) | https://firebase.google.com/docs/cloud-messaging/flutter/client |
| FCM Usage / Receive Messages | https://firebase.google.com/docs/cloud-messaging/flutter/receive |
| Send Messages (Server) | https://firebase.google.com/docs/cloud-messaging/send-message |
| Topic Messaging | https://firebase.google.com/docs/cloud-messaging/flutter/topic-messaging |
| FCM Notifications | https://firebase.google.com/docs/cloud-messaging/flutter/client |
| APNs Setup (iOS) | https://firebase.google.com/docs/cloud-messaging/flutter/client |
| Android Setup | https://firebase.google.com/docs/cloud-messaging/android/client |

---

## Firebase Cloud Functions

| Resource | URL |
|----------|-----|
| Cloud Functions Overview | https://firebase.google.com/docs/functions |
| Get Started | https://firebase.google.com/docs/functions/get-started |
| Write Functions | https://firebase.google.com/docs/functions/write-firebase-functions |
| Call Functions from Flutter | https://firebase.google.com/docs/functions/callable |
| Firestore Triggers | https://firebase.google.com/docs/functions/firestore-events |
| Auth Triggers | https://firebase.google.com/docs/functions/auth-events |
| HTTP Functions | https://firebase.google.com/docs/functions/http-events |
| Scheduled Functions | https://firebase.google.com/docs/functions/schedule-functions |
| Environment Config | https://firebase.google.com/docs/functions/config-env |

---

## Firebase Hosting (Admin Web Deployment)

| Resource | URL |
|----------|-----|
| Hosting Overview | https://firebase.google.com/docs/hosting |
| Get Started | https://firebase.google.com/docs/hosting/quickstart |
| Deploy Flutter Web | https://docs.flutter.dev/deployment/web |
| Custom Domain | https://firebase.google.com/docs/hosting/custom-domain |
| Preview Channels | https://firebase.google.com/docs/hosting/test-preview-deploy |

---

## VANAVIL-Specific Feature → Doc Mapping

| Project Feature | Key Docs |
|----------------|----------|
| Admin email/password login | Email/Password Sign-In, Manage Users |
| Child PIN login (no email) | Custom Auth + Cloud Functions to verify PIN & mint custom token |
| Firestore collections (tasks, children, etc.) | Add & Manage Data, Data Modeling, Security Rules |
| File upload (photo/video/audio proof) | Storage Upload Files, Storage Security Rules |
| Push notifications | FCM Flutter, Send Messages (Server), Topic Messaging |
| Task lifecycle (assigned→submitted→approved) | Firestore Triggers (Cloud Functions), Transactions |
| Dashboard reports | Compound Queries, Order & Limit, Pagination |
| Badge & points system | Transactions & Batched Writes |
| Announcements | Realtime Listeners, FCM Notifications |
| Deploy admin website | Firebase Hosting, Deploy Flutter Web |

---

## Pub.dev Packages (FlutterFire)

| Package | URL |
|---------|-----|
| firebase_core | https://pub.dev/packages/firebase_core |
| firebase_auth | https://pub.dev/packages/firebase_auth |
| cloud_firestore | https://pub.dev/packages/cloud_firestore |
| firebase_storage | https://pub.dev/packages/firebase_storage |
| firebase_messaging | https://pub.dev/packages/firebase_messaging |
| cloud_functions | https://pub.dev/packages/cloud_functions |
| firebase_analytics | https://pub.dev/packages/firebase_analytics |

---

## Additional Resources

| Resource | URL |
|----------|-----|
| Flutter Official Docs | https://docs.flutter.dev/ |
| Firebase YouTube Channel | https://www.youtube.com/@Firebase |
| FlutterFire Samples | https://github.com/firebase/flutterfire/tree/master/packages |
| Firebase Extensions | https://firebase.google.com/products/extensions |
| Google Cloud Console (for Functions) | https://console.cloud.google.com/ |
