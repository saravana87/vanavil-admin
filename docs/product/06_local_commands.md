# VANAVIL Local Commands

## Python API

Start the shared Python API used for:

- admin S3 uploads
- child attachment download URLs
- child PIN verification
- admin child PIN updates

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r services/s3_signer_api/requirements.txt
uvicorn main:app --reload --app-dir services/s3_signer_api
```

## Admin Web

Run the admin app against the Python API:

```bash
cd apps/admin_web
flutter pub get
flutter run -d chrome --dart-define=VANAVIL_S3_API_BASE_URL=http://127.0.0.1:8000
```

## Docker Deployment

Run the Python API and admin web together with Docker Compose:

```bash
docker compose up --build
```

The compose file exposes:

- Python API on `http://127.0.0.1:8000`
- Admin web on `http://127.0.0.1:8080`

For a real server deployment, set `VANAVIL_S3_API_BASE_URL` to the public API URL before building the admin web image.

Example:

```bash
$env:VANAVIL_S3_API_BASE_URL='https://api.yourdomain.com'
docker compose up --build -d
```

The admin web uses the Python API for:

- `POST /attachments/upload`
- `POST /attachments/download-url`
- `POST /admin/children/set-pin`

## Child App

Configure Firebase for the child app first, then run it against the same Python API:

```bash
cd apps/child_app
flutter pub get
flutter run --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000
```

The child app uses the Python API for:

- `POST /attachments/child-upload`
- `POST /child-submissions/submit`
- `POST /child-auth/verify-pin`
- `POST /attachments/child-download-url`

## Validation

Run Flutter analysis:

```bash
cd apps/admin_web
flutter analyze
```

```bash
cd apps/child_app
flutter analyze
```

Run Firestore rules tests:

```bash
cd functions
npm run test:firestore-rules
```

Run local Python auth API test:

```bash
cd services/s3_signer_api
..\..\.venv\Scripts\python.exe test_child_auth_api.py
```

## Android Emulator

```bash
flutter emulators --launch Pixel_7_Pro_API_34
flutter run -d emulator-5554
```

(.venv) (base) PS D:\Saravana\Madhu\vanavil\apps\child_app> flutter run -d chrome --dart-define=VANAVIL_API_BASE_URL=http://10.0.2.2:8000