# vanavil-admin

Admin portal for VANAVIL with a Flutter web frontend, Python backend services, and Firebase integration.

## Included In This Repository

- `apps/admin_web`: Flutter web admin application
- `services/s3_signer_api`: FastAPI service for admin attachment uploads, signed download URLs, and child PIN management
- `packages/vanavil_core`: shared models and enums
- `packages/vanavil_ui`: shared UI primitives and theme
- `packages/vanavil_firebase`: shared Firebase collection names and helpers
- `firebase`: Firestore rules and indexes used by the admin app

This published repository intentionally excludes the mobile child app and local secret files.

## What The Admin App Uses

The admin app depends on:

- Firebase Auth for admin sign-in
- Cloud Firestore for application data
- the Python API for S3 attachment operations and child PIN updates

## Local Run

Start the Python API:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r services/s3_signer_api/requirements.txt
uvicorn main:app --reload --app-dir services/s3_signer_api
```

Run the admin web app:

```bash
cd apps/admin_web
flutter pub get
flutter run -d chrome --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000
```

## Docker Deploy

Build and run the admin web app and Python API together:

```bash
docker compose up --build -d
```

Before a real server deployment, set `VANAVIL_S3_API_BASE_URL` to the public URL of your Python API.

## Secrets

Do not commit:

- `.env` files
- AWS access keys
- Firebase service account JSON files
- local credential files such as `aws_cred`

## Next Commands

```bash
cd apps/admin_web
flutter pub get
flutter run -d chrome --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000
```

```bash
cd apps/child_app
flutter pub get
flutter run --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000
```


**Start emulator (Android):**
```bash
flutter emulators --launch Pixel_7_Pro_API_34
```
flutter run -d emulator-5554