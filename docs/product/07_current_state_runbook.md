# VANAVIL Current State Runbook

This document is the current source of truth for how VANAVIL works today in local development.

Use it when you need to:

- resume work after a break
- hand the project to another engineer
- verify which backend owns which responsibility
- remember which commands, environment variables, and flows are actually in use
- avoid reintroducing removed Firebase Functions or Firebase Storage assumptions

## Current Architecture

VANAVIL is currently split across four active layers:

1. `apps/admin_web`
   Flutter web admin experience for children, tasks, dashboard, and PIN management.

2. `apps/child_app`
   Flutter child experience for profile selection, PIN sign-in, assignments, rewards, and announcements.

3. `services/s3_signer_api`
   Python FastAPI backend that now owns child PIN auth and S3 attachment operations.

4. Firebase
   Firebase Auth and Cloud Firestore remain in use for identity, rules enforcement, and application data.

## Important Architecture Decisions

These are deliberate and should not be accidentally undone:

1. Child PIN auth is not handled by Firebase Functions.
   Reason: deployment to the current Firebase project requires Blaze for Functions-related deployment APIs.

2. Admin and child attachment flows no longer rely on Firebase Storage.
   Attachments are handled through AWS S3 using the Python API.

3. Firestore rules are child-aware and are the security boundary for data access.
   Flutter clients must query in ways that satisfy those rules.

4. Pre-login child profile selection is not read from Firestore.
   The child app loads active profiles from the Python API before Firebase child sign-in begins.

## Active Backend Responsibilities

### Python API

Path: `services/s3_signer_api`

The Python API currently owns:

- child profile directory for pre-login profile selection
- child PIN verification
- child proof upload
- child submission persistence and assignment transition to `submitted`
- admin download URLs for child submission proof files
- admin child PIN updates
- admin attachment upload
- admin attachment download URL generation
- admin attachment delete support
- child attachment signed download URL generation

Current endpoints in use:

- `GET /health`
- `GET /child-auth/active-children`
- `POST /child-auth/verify-pin`
- `POST /attachments/child-upload`
- `POST /child-submissions/submit`
- `POST /attachments/admin-submission-download-url`
- `POST /admin/children/set-pin`
- `POST /attachments/upload`
- `POST /attachments/upload-url`
- `POST /attachments/download-url`
- `POST /attachments/delete-objects`
- `POST /attachments/child-download-url`

### Firebase Auth

Firebase Auth currently owns:

- admin sign-in for admin web
- child signed-in session after the Python API returns a Firebase custom token

### Firestore

Firestore currently stores:

- admins
- children
- tasks
- assignments
- submissions
- reviews
- points ledger
- child badges
- announcements
- notifications

## App Flows

### Admin Web Flow

1. Admin signs in with Firebase Auth.
2. Admin access is confirmed by checking `admins/{uid}`.
3. Dashboard, children, and tasks are loaded from Firestore.
4. Admin reviews submitted proof from the Reviews screen.
5. Child proof files are opened through `POST /attachments/admin-submission-download-url`.
6. Admin approval/rejection writes `reviews`, updates `assignments`, and awards points through Firestore.
7. Child PIN updates go through `POST /admin/children/set-pin`.

### Child App Flow

1. App starts and initializes Firebase.
2. App loads active child profiles from `GET /child-auth/active-children`.
3. Child selects a profile.
4. Child enters PIN.
5. App calls `POST /child-auth/verify-pin`.
6. Python API returns a Firebase custom token.
7. App signs in with `FirebaseAuth.signInWithCustomToken`.
8. Child can open a task, tap Start Task or Fix And Resubmit, add proof, and optionally write an explanation.
9. Child proof files upload through `POST /attachments/child-upload`.
10. Submission metadata, written explanations, and assignment status transition are persisted through `POST /child-submissions/submit`.
11. After sign-in, child data is read from Firestore under child-aware rules.

## Environment Variables And Dart Defines

### Python API Environment

Expected in `services/s3_signer_api/.env` or environment:

- `AWS_S3_BUCKET`
- `AWS_S3_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_S3_PREFIX`
- `FIREBASE_SERVICE_ACCOUNT_PATH`
- `S3_API_ALLOWED_ORIGINS` or `S3_API_ALLOWED_ORIGIN_REGEX`

Current known S3 values in local development:

- bucket: `vanavil`
- region: `us-east-1`
- prefix: `task_attachments`

### Admin Web Define

Use:

- `VANAVIL_S3_API_BASE_URL`

Example:

```bash
flutter run -d chrome --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000
```

### Child App Define

Use:

- `VANAVIL_API_BASE_URL`

Example for desktop, Chrome, or same-machine execution:

```bash
flutter run --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000
```

Example for Android emulator:

```bash
flutter run --dart-define=VANAVIL_API_BASE_URL=http://10.0.2.2:8000
```

Example for physical device:

```bash
flutter run --dart-define=VANAVIL_API_BASE_URL=http://<your-lan-ip>:8000
```

## Commands

See `06_local_commands.md` for the command list.

The minimum working local startup sequence is:

1. Start the Python API.
2. Run `apps/admin_web` with `VANAVIL_S3_API_BASE_URL`.
3. Run `apps/child_app` with `VANAVIL_API_BASE_URL`.

## Known Gotchas

### 1. Admin Web Firestore Permission Errors

If the admin dashboard shows permission denied for the review queue, check whether the query is constrained by `assignedBy == currentUserId` on the Firestore side.

Current dashboard query behavior must stay rule-compatible.

### 2. Child App Pre-Login Permission Errors

If the child app shows a Firestore permission error before the PIN screen, something has regressed.

Pre-login profile selection must come from:

- `GET /child-auth/active-children`

It must not query Firestore directly before child sign-in.

### 3. Child App Connection Refused Errors

If the child app shows `Connection refused` for `127.0.0.1:8000`, then one of these is true:

- the Python API is not running
- the app is on Android emulator and should use `10.0.2.2`
- the app is on a physical device and should use the host machine LAN IP

### 4. Firestore Failed-Precondition Index Errors

If the child home/tasks screen shows a missing index error, check whether an `orderBy` was reintroduced on a child assignments query.

Current child screens avoid the index requirement by:

- querying by `childId`
- sorting by `dueDate` in Dart instead of Firestore

### 5. Child Submission Writes

The child app should not directly batch-write `submissions` docs and assignment status changes from the client.

Current expected path is:

- upload proof through the Python API
- submit proof through the Python API
- let the backend write `submissions` and update `assignments/{assignmentId}`

### 6. Firebase Functions Assumptions

Do not move child PIN auth back into Firebase Functions unless the billing/deployment constraint is intentionally revisited.

The current non-Blaze path depends on the Python API.

## Validation Checklist

Run this before calling the local setup healthy:

1. Python API health endpoint responds.
2. Admin web `flutter analyze` passes.
3. Child app `flutter analyze` passes.
4. Firestore rules tests pass.
5. Python auth API test passes.
6. Admin web dashboard loads without Firestore permission errors.
7. Admin can set a child PIN.
8. Child app loads profile list.
9. Child can sign in with PIN.
10. Child can upload proof and submit a task.
11. Child home screen loads assignments without index or permission errors.
12. Admin can open submitted proof or read written explanations from Reviews and approve or reject it.
13. Approving a submission updates child points and writes a `points_ledger` entry.

## Current Verified Commands

### Child App Analysis

```bash
cd apps/child_app
flutter analyze
```

### Admin Web Analysis

```bash
cd apps/admin_web
flutter analyze
```

### Firestore Rules Tests

```bash
cd functions
npm run test:firestore-rules
```

### Python API Test

```bash
cd services/s3_signer_api
..\..\.venv\Scripts\python.exe test_child_auth_api.py
```

## Files That Matter Most

### Python API

- `services/s3_signer_api/main.py`
- `services/s3_signer_api/test_child_auth_api.py`
- `services/s3_signer_api/requirements.txt`

### Firestore Security

- `firebase/firestore.rules`
- `firebase/firestore.indexes.json`

### Admin Web

- `apps/admin_web/lib/src/app/admin_app.dart`
- `apps/admin_web/lib/src/features/dashboard/admin_dashboard_screen.dart`
- `apps/admin_web/lib/src/features/children/manage_children_screen.dart`
- `apps/admin_web/lib/src/features/tasks/manage_tasks_screen.dart`

### Child App

- `apps/child_app/lib/src/app/child_app.dart`
- `apps/child_app/lib/src/data/child_auth_service.dart`
- `apps/child_app/lib/src/data/attachment_service.dart`
- `apps/child_app/lib/src/features/auth/child_pin_login_screen.dart`
- `apps/child_app/lib/src/features/home/child_home_screen.dart`
- `apps/child_app/lib/src/features/tasks/child_task_list_screen.dart`

## Recommendation For Future Updates

When a behavior changes, update this document in the same change set as the code.

Specifically update it when any of these change:

- backend ownership moves between Firebase and Python
- a new environment variable or Dart define is introduced
- an app flow changes
- a Firestore rule/query compatibility fix is made
- a new required index is introduced
- a new run or verification command becomes necessary

That keeps the project memory in the repo instead of in chat.