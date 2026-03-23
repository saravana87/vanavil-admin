# Firebase Cloud Storage (VANAVIL)

## Overview
Cloud Storage is used in VANAVIL for children to upload proof of task completion (photos, videos, audio) and for admins to preview those uploads during review.

---

## Setup

```bash
flutter pub add firebase_storage
flutter pub add image_picker
flutter pub add file_picker
```

```dart
import 'package:firebase_storage/firebase_storage.dart';

final storage = FirebaseStorage.instance;
```

---

## Storage Structure for VANAVIL

```
submissions/
  {childId}/
    {assignmentId}/
      proof_photo_1679012345.jpg
      proof_video_1679012345.mp4
      proof_audio_1679012345.m4a
avatars/
  {childId}/
    avatar.png
badges/
  badge_star.png
  badge_champion.png
```

---

## Creating Storage References

```dart
// Reference to a child's submission folder
final submissionRef = storage.ref()
    .child('submissions')
    .child(childId)
    .child(assignmentId);

// Reference to a specific file
final fileRef = submissionRef.child('proof_photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
```

---

## Uploading Files

### Upload from File (Mobile — Photo/Video/Audio)

```dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Pick an image
final picker = ImagePicker();
final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);

if (pickedFile != null) {
  final file = File(pickedFile.path);
  final fileName = 'proof_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final ref = storage.ref('submissions/$childId/$assignmentId/$fileName');

  // Upload with metadata
  final uploadTask = ref.putFile(
    file,
    SettableMetadata(contentType: 'image/jpeg'),
  );

  // Monitor upload progress
  uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
    final progress = snapshot.bytesTransferred / snapshot.totalBytes;
    print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
  });

  // Wait for completion
  await uploadTask;

  // Get download URL
  final downloadUrl = await ref.getDownloadURL();
  print('File available at: $downloadUrl');
}
```

### Upload Video

```dart
final XFile? videoFile = await picker.pickVideo(
  source: ImageSource.camera,
  maxDuration: const Duration(seconds: 30), // Limit video length for MVP
);

if (videoFile != null) {
  final file = File(videoFile.path);
  final fileName = 'proof_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
  final ref = storage.ref('submissions/$childId/$assignmentId/$fileName');

  await ref.putFile(
    file,
    SettableMetadata(contentType: 'video/mp4'),
  );

  final downloadUrl = await ref.getDownloadURL();
}
```

### Upload Audio

```dart
import 'package:file_picker/file_picker.dart';

final result = await FilePicker.platform.pickFiles(type: FileType.audio);

if (result != null) {
  final file = File(result.files.single.path!);
  final fileName = 'proof_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  final ref = storage.ref('submissions/$childId/$assignmentId/$fileName');

  await ref.putFile(
    file,
    SettableMetadata(contentType: 'audio/m4a'),
  );

  final downloadUrl = await ref.getDownloadURL();
}
```

### Upload from Bytes (Flutter Web)

```dart
// For web uploads where File paths aren't available
final uploadTask = ref.putData(
  fileBytes,
  SettableMetadata(contentType: 'image/jpeg'),
);
```

---

## Saving Upload Info to Firestore

After uploading, store the file URL in the `submissions` collection:

```dart
await FirebaseFirestore.instance.collection('submissions').add({
  'assignmentId': assignmentId,
  'childId': childId,
  'proofType': 'photo', // or 'video', 'audio'
  'storagePath': ref.fullPath,
  'fileUrl': downloadUrl,
  'note': 'Completed the task!',
  'contentType': 'image/jpeg',
  'uploadedAt': FieldValue.serverTimestamp(),
});
```

For an MVP, storing `fileUrl` is fine. For longer-term durability, also persist `storagePath` so the admin app can regenerate download URLs if tokenized URLs are rotated.

---

## Downloading / Displaying Files (Admin Review)

### Display Image

```dart
Image.network(submission['fileUrl']);
```

### Get Download URL for Existing File

```dart
final url = await storage.ref('submissions/$childId/$assignmentId/proof.jpg').getDownloadURL();
```

---

## Listing Files in a Folder

```dart
// List all proof files for a submission
final listResult = await storage.ref('submissions/$childId/$assignmentId').listAll();

for (var item in listResult.items) {
  final url = await item.getDownloadURL();
  print('${item.name}: $url');
}
```

---

## File Metadata

```dart
final metadata = await ref.getMetadata();
print('Content type: ${metadata.contentType}');
print('Size: ${metadata.size} bytes');
print('Created: ${metadata.timeCreated}');
```

---

## Storage Security Rules

Save as `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Submission proofs
    match /submissions/{childId}/{assignmentId}/{fileName} {
      // Admin can read all
      allow read: if request.auth != null &&
                     firestore.exists(/databases/(default)/documents/admins/$(request.auth.uid));
      // Child can upload their own proofs
      allow write: if request.auth != null &&
                      request.auth.token.childId == childId &&
                      request.resource.size < 50 * 1024 * 1024; // 50MB limit
      // Child can read their own proofs
      allow read: if request.auth != null &&
                     request.auth.token.childId == childId;
    }

    // Avatars
    match /avatars/{childId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      firestore.exists(/databases/(default)/documents/admins/$(request.auth.uid));
    }

    // Badges (read-only for all authenticated users)
    match /badges/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      firestore.exists(/databases/(default)/documents/admins/$(request.auth.uid));
    }
  }
}
```

Deploy:
```bash
firebase deploy --only storage
```

---

## Official Documentation Links
- [Cloud Storage Overview](https://firebase.google.com/docs/storage)
- [Get Started with Storage on Flutter](https://firebase.google.com/docs/storage/flutter/start)
- [Upload Files (Flutter)](https://firebase.google.com/docs/storage/flutter/upload-files)
- [Download Files (Flutter)](https://firebase.google.com/docs/storage/flutter/download-files)
- [Create References (Flutter)](https://firebase.google.com/docs/storage/flutter/create-reference)
- [File Metadata (Flutter)](https://firebase.google.com/docs/storage/flutter/file-metadata)
- [List Files (Flutter)](https://firebase.google.com/docs/storage/flutter/list-files)
