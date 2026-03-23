# Firebase Project Setup for Flutter (VANAVIL)

## Overview
This guide covers setting up Firebase for the VANAVIL project — a Flutter app with both Web (Admin) and Mobile (Child) targets.

---

## Prerequisites
- Flutter SDK installed (`flutter --version`)
- A Google account
- Node.js installed (for Firebase CLI)

---

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

## Step 2: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

## Step 3: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add Project**
3. Name it `vanavil` (or your preferred name)
4. Enable/disable Google Analytics as needed
5. Click **Create Project**

## Step 4: Add Firebase Dependencies

Install plugins from the project root so you get the latest compatible versions for your current Flutter SDK:

```bash
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging
flutter pub add cloud_functions
```

Then run:

```bash
flutter pub get
```

## Step 5: Configure FlutterFire

From your Flutter project root:

```bash
flutterfire configure
```

This will:
- Ask you to select your Firebase project
- Ask which platforms to configure (Android, iOS, Web)
- Generate `lib/firebase_options.dart` with platform-specific config
- Update platform-specific integration files when you add supported Firebase products

Re-run `flutterfire configure` whenever you add a new platform or start using a Firebase product that needs additional native/web configuration.

## Step 6: Initialize Firebase in `main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VanavilApp());
}
```

## Step 7: Understanding `firebase_options.dart`

The generated file contains a `DefaultFirebaseOptions` class with:
- `web` — config for Flutter Web (Admin website)
- `android` — config for Android (Child app)
- `ios` — config for iOS (Child app)
- `currentPlatform` — auto-selects based on runtime platform

`firebase_options.dart` usually contains client configuration, not server secrets. It is typically fine to commit it. Security must come from Firebase Auth, Security Rules, App Check where applicable, and keeping server credentials out of the client app.

---

## VANAVIL-Specific Notes
- **Admin Website**: Uses Flutter Web — ensure Web platform is selected during `flutterfire configure`
- **Child Mobile App**: Uses Flutter Mobile — ensure Android and/or iOS are selected
- Both share the same Firebase project and Firestore database
- For a production rollout, add Firebase Emulator Suite support early so admin auth, child PIN flows, and rules can be tested locally

---

## Official Documentation Links
- [Add Firebase to Flutter App](https://firebase.google.com/docs/flutter/setup)
- [Firebase for Flutter Overview](https://firebase.google.com/docs/flutter)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Get to Know Firebase for Flutter (Codelab)](https://firebase.google.com/codelabs/firebase-get-to-know-flutter)
