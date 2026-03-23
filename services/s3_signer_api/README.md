# VANAVIL S3 Signer API

This FastAPI service replaces the Firebase callable presign flow for task attachments.

## What it does

- verifies the Firebase ID token from the admin web app
- checks that the caller exists in the `admins` Firestore collection
- verifies child PINs and mints Firebase custom tokens without Firebase Functions
- hashes and stores child PINs for admin-owned child profiles
- uploads task files to S3 on behalf of the admin app
- creates presigned S3 download URLs
- creates child-authorized presigned S3 download URLs for assigned task attachments
- deletes uploaded S3 objects if the task save is rolled back

## Setup

1. Create a Python virtual environment.
2. Install dependencies from `requirements.txt`.
3. Copy `.env.example` to `.env` and update the values.
4. Make sure Firebase Admin can access your project using `FIREBASE_SERVICE_ACCOUNT_PATH` or Application Default Credentials.

## Run

```bash
uvicorn main:app --reload --app-dir services/s3_signer_api
```

The API loads `services/s3_signer_api/.env` automatically.

For local Flutter web development, the API now accepts `http://localhost:<any-port>` and `http://127.0.0.1:<any-port>` by default. Use `S3_API_ALLOWED_ORIGINS` and `S3_API_ALLOWED_ORIGIN_REGEX` only when you need to allow extra non-local origins.

Because uploads now go through this API, the S3 bucket does not need browser CORS enabled for task file uploads.

## Docker

Build and run the API container from the repository root:

```bash
docker build -t vanavil-s3-api ./services/s3_signer_api
docker run --rm -p 8000:8000 --env-file ./services/s3_signer_api/.env -v ./services/s3_signer_api/vanavil-2c565-firebase-adminsdk-fbsvc-9773c8b670.json:/run/secrets/firebase-service-account.json:ro -e FIREBASE_SERVICE_ACCOUNT_PATH=/run/secrets/firebase-service-account.json vanavil-s3-api
```

If you deploy on a server, keep the Firebase service-account file mounted as a secret and set `FIREBASE_SERVICE_ACCOUNT_PATH` to that mounted path.

## Child PIN auth

This API now replaces Firebase Functions for child PIN authentication so the project does not need Blaze just to mint custom tokens.

Use `POST /child-auth/verify-pin` with:

- `childId`
- `pin`

The API verifies the stored `pinCodeHash`, confirms the child is active, updates `lastLoginAt`, and returns a Firebase custom token with `role=child` and `childId` claims.

Use `POST /admin/children/set-pin` with an admin Firebase Bearer token and:

- `childId`
- `pin`

The API verifies the admin owns that child profile, hashes the 4-digit PIN with bcrypt, and updates the child document.

## Child attachment downloads

The child app should not read S3 directly and should not rely on a permanent URL stored in Firestore.

Use `POST /attachments/child-download-url` with:

- `childId`
- `assignmentId`
- `taskId`
- `objectKey`

The API verifies the Firebase child token, confirms the assignment belongs to that child, confirms the assignment references the requested task, and confirms the task contains the requested attachment before returning a short-lived signed download URL.

## Flutter admin web

Run the admin app with:

```bash
flutter run -d chrome --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000
```