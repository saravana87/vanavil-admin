# Firebase Authentication (VANAVIL)

## Overview
VANAVIL has two authentication flows:
1. **Admin** — Email/password login on the website
2. **Child** — Profile selection + 4-digit PIN login on the mobile app (no email required)

---

## Setup

### 1. Add Dependency

```bash
flutter pub add firebase_auth
```

### 2. Enable Auth Providers in Firebase Console

1. Go to **Firebase Console → Authentication → Sign-in method**
2. Enable **Email/Password** (for Admin)
3. Optionally enable **Anonymous** (for Child PIN-based auth)

---

## Admin Authentication (Email/Password)

### Sign Up (Create Admin Account)

```dart
try {
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  // Store admin profile in Firestore 'admins' collection
  await FirebaseFirestore.instance.collection('admins').doc(credential.user!.uid).set({
    'email': email,
    'name': name,
    'createdAt': FieldValue.serverTimestamp(),
  });
} on FirebaseAuthException catch (e) {
  if (e.code == 'weak-password') {
    // Handle weak password
  } else if (e.code == 'email-already-in-use') {
    // Handle duplicate email
  }
}
```

### Sign In

```dart
try {
  final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  // Navigate to admin dashboard
} on FirebaseAuthException catch (e) {
  if (e.code == 'user-not-found') {
    // No user found for that email
  } else if (e.code == 'wrong-password') {
    // Wrong password
  }
}
```

### Sign Out

```dart
await FirebaseAuth.instance.signOut();
```

### Monitor Auth State

```dart
FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    // User is signed out — show login screen
  } else {
    // User is signed in — show dashboard
  }
});
```

---

## Child Authentication (PIN-Based)

Children don't have email accounts. The recommended approach for VANAVIL:

### Approach: Cloud Function Custom Token + Firestore PIN Verification

1. Child selects their profile from a list
2. Child enters their 4-digit PIN
3. App calls a Cloud Function that:
   - Verifies the PIN against the hashed PIN in Firestore (`children` collection)
   - If valid, generates a custom Firebase Auth token using Admin SDK
   - Returns the token to the app
4. App signs in with the custom token

#### Cloud Function (Node.js)

```javascript
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const bcrypt = require("bcrypt");

exports.verifyChildPin = onCall(async (request) => {
  const { childId, pin } = request.data;

  const childDoc = await getFirestore().collection("children").doc(childId).get();
  if (!childDoc.exists) {
    throw new HttpsError("not-found", "Child not found");
  }

  const child = childDoc.data();
  if (child.status !== "active") {
    throw new HttpsError("permission-denied", "Child account is deactivated");
  }

  const pinMatch = await bcrypt.compare(pin, child.pinCodeHash);
  if (!pinMatch) {
    throw new HttpsError("unauthenticated", "Invalid PIN");
  }

  // Create custom token with child role
  const customToken = await getAuth().createCustomToken(`child_${childId}`, {
    role: "child",
    childId: childId,
  });

  return { token: customToken };
});
```

#### Flutter Client (Child App)

```dart
// Step 1: Call Cloud Function to verify PIN
final result = await FirebaseFunctions.instance
    .httpsCallable('verifyChildPin')
    .call({'childId': selectedChildId, 'pin': enteredPin});

// Step 2: Sign in with custom token
final token = result.data['token'];
await FirebaseAuth.instance.signInWithCustomToken(token);
```

### PIN Storage (When Admin Sets PIN)

Do not hash the PIN in the client app. The admin app should call a trusted backend function that hashes the PIN with `bcrypt` and stores only the hash.

```javascript
exports.setChildPin = onCall(async (request) => {
  const adminDoc = await getFirestore().collection("admins").doc(request.auth.uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Only admins can set PINs");
  }

  const { childId, pin } = request.data;
  if (!/^\d{4}$/.test(pin)) {
    throw new HttpsError("invalid-argument", "PIN must be exactly 4 digits");
  }

  const pinCodeHash = await bcrypt.hash(pin, 10);
  await getFirestore().collection("children").doc(childId).update({
    pinCodeHash,
    pinUpdatedAt: new Date(),
  });

  return { success: true };
});
```

Recommended hardening for VANAVIL:
- Track failed PIN attempts per child profile
- Add a short cooldown after repeated failures
- Reset sessions when a child profile is deactivated

---

## Role-Based Routing

```dart
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.idTokenChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (snapshot.hasData) {
      // For child logins using custom claims, idTokenChanges() is safer than
      // authStateChanges() because refreshed claims propagate through the ID token.
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('admins').doc(snapshot.data!.uid).get(),
        builder: (context, adminSnapshot) {
          if (adminSnapshot.data?.exists == true) {
            return const AdminDashboard();
          }
          return const ChildDashboard();
        },
      );
    }
    return const LoginScreen();
  },
);
```

---

## Official Documentation Links
- [Get Started with Firebase Auth on Flutter](https://firebase.google.com/docs/auth/flutter/start)
- [Password-Based Auth on Flutter](https://firebase.google.com/docs/auth/flutter/password-auth)
- [Custom Auth on Flutter](https://firebase.google.com/docs/auth/flutter/custom-auth)
- [Anonymous Auth on Flutter](https://firebase.google.com/docs/auth/flutter/anonymous-auth)
- [Firebase Auth Codelab for Flutter](https://firebase.google.com/codelabs/firebase-auth-in-flutter-apps)
