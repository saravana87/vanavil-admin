# child_app

VANAVIL child mobile application.

## Current backend contract

This app now expects:

- Firebase Auth configured for the app
- Firestore configured for the app
- Python API running for child PIN verification and attachment downloads

The Python API endpoints used by the child app are:

- `POST /child-auth/verify-pin`
- `POST /attachments/child-download-url`

## Run locally

1. Run `flutterfire configure` for `apps/child_app`.
2. Ensure the Python API is running from `services/s3_signer_api`.
3. Launch the app with the API base URL:

```bash
flutter run --dart-define=VANAVIL_API_BASE_URL=http://127.0.0.1:8000
```
