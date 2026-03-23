# Firestore Security Rules (VANAVIL)

## Overview
Security rules control who can read/write data in Firestore. VANAVIL needs role-based rules: **Admin** has full access, **Child** has limited read/write access to their own data.

---

## Basic Structure

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Rules go here
  }
}
```

## Key Concepts

- Rules **do not cascade** — subcollection rules must be defined separately
- `request.auth` contains the authenticated user's info
- `request.auth.token` contains custom claims (e.g., `role`, `childId`)
- Use `resource.data` to access existing document fields
- Use `request.resource.data` to access incoming write data

---

## VANAVIL Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ============================================
    // Helper Functions
    // ============================================

    function isAuthenticated() {
      return request.auth != null;
    }

    function isAdmin() {
      return isAuthenticated() &&
             exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }

    function isChild(childId) {
      return isAuthenticated() &&
             request.auth.token.role == 'child' &&
             request.auth.token.childId == childId;
    }

    function isOwnerChild() {
      return isAuthenticated() &&
             request.auth.token.role == 'child';
    }

    function assignmentBelongsToChild(assignmentId) {
      return get(/databases/$(database)/documents/assignments/$(assignmentId)).data.childId == request.auth.token.childId;
    }

    // ============================================
    // Admin Collection
    // ============================================
    match /admins/{adminId} {
      allow read: if isAuthenticated() && request.auth.uid == adminId;
      allow write: if isAuthenticated() && request.auth.uid == adminId;
    }

    // ============================================
    // Children Collection
    // ============================================
    match /children/{childId} {
      // Admin can read/write all children
      allow read, write: if isAdmin();
      // Child can read their own profile
      allow read: if isChild(childId);
    }

    // ============================================
    // Tasks Collection
    // ============================================
    match /tasks/{taskId} {
      // Only admin can create/edit/delete tasks
      allow read, write: if isAdmin();
      // Children can read tasks (to view task details)
      allow read: if isOwnerChild();
    }

    // ============================================
    // Assignments Collection
    // ============================================
    match /assignments/{assignmentId} {
      // Admin has full access
      allow read, write: if isAdmin();
      // Child can read their own assignments
      allow read: if isOwnerChild() &&
                     resource.data.childId == request.auth.token.childId;
      // Child can update only their own status transition to 'submitted'
      allow update: if isOwnerChild() &&
                       resource.data.childId == request.auth.token.childId &&
                       request.resource.data.childId == resource.data.childId &&
                       request.resource.data.taskId == resource.data.taskId &&
                       request.resource.data.assignedBy == resource.data.assignedBy &&
                       request.resource.data.assignedAt == resource.data.assignedAt &&
                       request.resource.data.dueDate == resource.data.dueDate &&
                       request.resource.data.status == 'submitted' &&
                       resource.data.status in ['assigned', 'rejected'] &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'submittedAt']);
    }

    // ============================================
    // Submissions Collection
    // ============================================
    match /submissions/{submissionId} {
      // Admin can read all submissions
      allow read: if isAdmin();
      // Child can create submissions for themselves
      allow create: if isOwnerChild() &&
                       request.resource.data.childId == request.auth.token.childId &&
                       assignmentBelongsToChild(request.resource.data.assignmentId);
      // Child can read their own submissions
      allow read: if isOwnerChild() &&
                     resource.data.childId == request.auth.token.childId;
    }

    // ============================================
    // Reviews Collection
    // ============================================
    match /reviews/{reviewId} {
      // Only admin can create reviews
      allow read, write: if isAdmin();
      // Child can read reviews of their assignments
      allow read: if isOwnerChild() &&
                     assignmentBelongsToChild(resource.data.assignmentId);
    }

    // ============================================
    // Points Ledger
    // ============================================
    match /points_ledger/{ledgerId} {
      // Admin can read/write
      allow read, write: if isAdmin();
      // Child can read their own points
      allow read: if isOwnerChild() &&
                     resource.data.childId == request.auth.token.childId;
    }

    // ============================================
    // Badges Collection
    // ============================================
    match /badges/{badgeId} {
      // Admin can manage badges
      allow read, write: if isAdmin();
      // Children can read badge definitions
      allow read: if isOwnerChild();
    }

    // ============================================
    // Child Badges
    // ============================================
    match /child_badges/{childBadgeId} {
      // Admin can award badges
      allow read, write: if isAdmin();
      // Child can read their own badges
      allow read: if isOwnerChild() &&
                     resource.data.childId == request.auth.token.childId;
    }

    // ============================================
    // Announcements
    // ============================================
    match /announcements/{announcementId} {
      // Admin can manage announcements
      allow read, write: if isAdmin();
      // Children can read announcements
      allow read: if isOwnerChild();
    }

    // ============================================
    // Notifications
    // ============================================
    match /notifications/{notificationId} {
      // Admin can create notifications
      allow create: if isAdmin();
      // Child can read and update (mark as read) their own notifications
      allow read: if isOwnerChild() &&
                     resource.data.childId == request.auth.token.childId;
      allow update: if isOwnerChild() &&
                       resource.data.childId == request.auth.token.childId &&
                       request.resource.data.childId == resource.data.childId &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']);
    }
  }
}
```

This sample intentionally keeps approval, rejection, badge awards, and points writes admin-only. In VANAVIL, child clients should never be able to mutate reward totals or directly transition an assignment to `completed`.

---

## Deploying Rules

```bash
# Save rules to firestore.rules file, then:
firebase deploy --only firestore:rules
```

---

## Testing Rules

Use the Firebase Emulator Suite to test rules locally:

```bash
firebase emulators:start --only firestore
```

Or use the [Rules Playground](https://console.firebase.google.com/) in the Firebase Console under Firestore → Rules → Rules Playground.

---

## Official Documentation Links
- [Get Started with Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Structuring Security Rules](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Writing Conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Secure Queries](https://firebase.google.com/docs/firestore/security/rules-query)
- [Field-Level Access Control](https://firebase.google.com/docs/firestore/security/rules-fields)
- [Role-Based Access](https://firebase.google.com/docs/firestore/solutions/role-based-access)
- [Security Rules Codelab](https://firebase.google.com/codelabs/firebase-rules)
