# Firebase Hosting — Admin Web App (VANAVIL)

## Overview
Firebase Hosting is used to deploy the VANAVIL Admin website (Flutter Web) with a fast CDN, SSL certificate, and custom domain support.

---

## Setup

### Step 1: Initialize Hosting

```bash
firebase init hosting
```

When prompted:
- **Public directory**: `build/web`
- **Single-page app**: **Yes** (rewrite all URLs to `/index.html`)
- **Automatic builds with GitHub**: Optional (set up later for CI/CD)

### Step 2: Build the Flutter Web App

```bash
flutter build web --release
```

This outputs the built app to `build/web/`.

### Step 3: Deploy

```bash
firebase deploy --only hosting
```

After deployment, Firebase provides a URL like:
```
https://vanavil-xxxxx.web.app
```

---

## Configuration (`firebase.json`)

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=604800"
          }
        ]
      },
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=604800"
          }
        ]
      }
    ]
  }
}
```

---

## Custom Domain

1. Go to **Firebase Console → Hosting → Add custom domain**
2. Enter your domain (e.g., `admin.vanavil.com`)
3. Update DNS records as instructed
4. Firebase automatically provisions an SSL certificate

---

## Preview Channels (Staging)

Test changes before deploying to production:

```bash
# Create a preview channel
firebase hosting:channel:deploy staging

# This gives you a temporary URL like:
# https://vanavil-xxxxx--staging-abc123.web.app
```

---

## Deploying with GitHub Actions (CI/CD)

```yaml
# .github/workflows/deploy.yml
name: Deploy Admin Web

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - run: flutter pub get
      - run: flutter build web --release

      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: your-vanavil-project-id
```

---

## Build Optimization Tips

```bash
# Default release build is the safest baseline
flutter build web --release
```

Only add custom renderer or build flags after measuring startup time, download size, and rendering quality on your actual admin devices and browsers.

## Self-Hosted Alternative

If you are deploying to your own server instead of Firebase Hosting, use the repo-level `docker-compose.yml` to build:

- the Python S3 signer API from `services/s3_signer_api`
- the Flutter admin web app from `apps/admin_web`

Set `VANAVIL_S3_API_BASE_URL` to the public API URL before building the admin web image.

---

## VANAVIL-Specific Notes

- Only the **Admin website** is hosted on Firebase Hosting
- The **Child mobile app** is distributed via app stores (Google Play / App Store)
- The admin site uses the same Firebase project, so Firestore, Auth, and Storage work seamlessly
- Use **preview channels** to let stakeholders review admin UI changes before going live

---

## Official Documentation Links
- [Firebase Hosting Quickstart](https://firebase.google.com/docs/hosting/quickstart)
- [Firebase Hosting Overview](https://firebase.google.com/docs/hosting)
- [Deploy to Live & Preview Channels](https://firebase.google.com/docs/hosting/test-preview-deploy)
- [Hosting Configuration](https://firebase.google.com/docs/hosting/full-config)
- [GitHub Integration](https://firebase.google.com/docs/hosting/github-integration)
- [Custom Domains](https://firebase.google.com/docs/hosting/custom-domain)
