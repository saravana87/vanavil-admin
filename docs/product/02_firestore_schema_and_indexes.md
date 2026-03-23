# VANAVIL Firestore Schema And Index Plan

## Schema Principles

- keep collections flat for simple queries
- denormalize display fields when it reduces joins in Flutter
- use server timestamps for audit fields
- use soft status flags instead of hard deletes for business records
- keep financial-style changes such as points in ledger form

---

## Canonical Collections

### `admins`

Document ID:

- Firebase Auth UID

Fields:

- `email`: string
- `name`: string
- `role`: string = `admin` or `super_admin`
- `status`: string = `active` or `disabled`
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `children`

Document ID:

- generated ID

Fields:

- `adminId`: string
- `name`: string
- `avatar`: string
- `pinCodeHash`: string
- `age`: number
- `status`: string = `active` or `inactive`
- `totalPoints`: number
- `badgeCount`: number
- `lastLoginAt`: timestamp?
- `pinUpdatedAt`: timestamp?
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `tasks`

Document ID:

- generated ID

Fields:

- `title`: string
- `description`: string
- `comments`: string
- `rewardPoints`: number
- `recurringDaily`: bool
- `templateStatus`: string = `active` or `archived`
- `createdBy`: string
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `assignments`

Document ID:

- generated ID

Fields:

- `taskId`: string
- `taskTitle`: string
- `childId`: string
- `childName`: string
- `assignedBy`: string
- `dueDate`: timestamp
- `status`: string
- `rewardPoints`: number
- `isRecurringInstance`: bool
- `assignedAt`: timestamp
- `submittedAt`: timestamp?
- `approvedAt`: timestamp?
- `completedAt`: timestamp?
- `rejectedAt`: timestamp?
- `lastReviewId`: string?
- `createdAt`: timestamp
- `updatedAt`: timestamp

Why denormalize `taskTitle`, `childName`, and `rewardPoints`:

- faster list rendering
- simpler dashboard queries
- fewer client-side joins

### `submissions`

Document ID:

- generated ID

Fields:

- `assignmentId`: string
- `childId`: string
- `proofType`: string = `photo` | `video` | `audio`
- `storagePath`: string
- `fileUrl`: string
- `contentType`: string
- `note`: string
- `uploadedAt`: timestamp

### `reviews`

Document ID:

- generated ID

Fields:

- `assignmentId`: string
- `childId`: string
- `adminId`: string
- `decision`: string = `approved` | `rejected`
- `comment`: string
- `pointsAwarded`: number
- `reviewedAt`: timestamp

### `points_ledger`

Document ID:

- generated ID

Fields:

- `childId`: string
- `assignmentId`: string
- `reviewId`: string?
- `points`: number
- `reason`: string
- `createdAt`: timestamp

### `badges`

Document ID:

- generated ID or slug

Fields:

- `title`: string
- `icon`: string
- `description`: string
- `colorKey`: string
- `sortOrder`: number
- `isActive`: bool

### `child_badges`

Document ID:

- generated ID

Fields:

- `childId`: string
- `badgeId`: string
- `badgeTitle`: string
- `awardedBy`: string
- `awardedAt`: timestamp
- `reason`: string

### `announcements`

Document ID:

- generated ID

Fields:

- `title`: string
- `message`: string
- `createdBy`: string
- `visibilityDate`: timestamp
- `status`: string = `draft` | `published`
- `createdAt`: timestamp
- `updatedAt`: timestamp

### `notifications`

Document ID:

- generated ID

Fields:

- `childId`: string
- `type`: string
- `title`: string
- `message`: string
- `referenceId`: string?
- `isRead`: bool
- `createdAt`: timestamp

---

## State Rules

### Assignment Transition Matrix

Allowed transitions:

- `assigned -> submitted`
- `rejected -> submitted`
- `submitted -> approved`
- `submitted -> rejected`
- `approved -> completed`

Forbidden from child client:

- `assigned -> completed`
- `submitted -> completed`
- `rejected -> completed`
- any points mutation

### Submission Rules

- a child may create multiple submission records over the life of one assignment
- latest review should reference the submission actually evaluated
- admin review comments should be preserved for reporting history

---

## Recommended Composite Indexes

Create these early because the UI depends on them.

### Admin Web

1. `assignments`
   Fields: `status ASC`, `submittedAt DESC`
   Use: pending review queue

2. `assignments`
   Fields: `childId ASC`, `dueDate ASC`
   Use: child detail report and admin child activity views

3. `assignments`
   Fields: `childId ASC`, `status ASC`, `dueDate ASC`
   Use: child app task list for assigned and rejected items

4. `tasks`
   Fields: `createdBy ASC`, `createdAt DESC`
   Use: admin task templates/history

5. `points_ledger`
   Fields: `childId ASC`, `createdAt DESC`
   Use: child points history

6. `child_badges`
   Fields: `childId ASC`, `awardedAt DESC`
   Use: badge history

7. `announcements`
   Fields: `status ASC`, `visibilityDate DESC`
   Use: announcement list and child feed

8. `notifications`
   Fields: `childId ASC`, `createdAt DESC`
   Use: child inbox

---

## Backend-Owned Transactions

### Approve Submission Function

One callable function should do all of this atomically or in one controlled batch:

- validate admin caller
- validate assignment exists and is in `submitted`
- create review document
- write points ledger document
- increment child `totalPoints`
- update assignment to `approved` or directly `completed`
- create notification record

### Reject Submission Function

One callable function should:

- validate admin caller
- validate assignment exists and is in `submitted`
- create review document
- set assignment to `rejected`
- create notification record

### Set Child PIN Function

One callable function should:

- validate admin caller
- validate child belongs to admin scope if needed
- bcrypt hash the PIN
- update `pinCodeHash`
- write `pinUpdatedAt`

---

## Schema Notes For Reporting

To keep the MVP simple, reports should use:

- `children.totalPoints`
- `children.badgeCount`
- `reviews` history
- `assignments` status and due dates

Do not build a separate analytics store until query cost or latency becomes visible.
