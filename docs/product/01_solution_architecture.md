# VANAVIL Solution Architecture

## Product Goal

VANAVIL is an MVP with two client surfaces backed by one Firebase project:

- Admin web app: manage children, create tasks, review submissions, award points and badges, publish announcements
- Child mobile app: sign in with profile + PIN, view tasks, upload proof, track rewards, receive updates

The MVP should optimize for:

- fast delivery
- safe task lifecycle enforcement
- simple child experience
- clean admin operations
- shared domain logic where it reduces duplication

---

## Recommended Architecture Shape

Use a Flutter monorepo with two apps and shared packages.

```text
vanavil/
  apps/
    admin_web/
    child_app/
  packages/
    vanavil_core/
    vanavil_ui/
    vanavil_firebase/
  functions/
  firebase/
  docs/
```

Why this shape fits the MVP:

- admin and child surfaces stay clearly separated
- models, enums, validation, and Firebase repositories can be reused
- web-specific and mobile-specific routing/UI remain isolated
- Cloud Functions can own sensitive writes and lifecycle transitions

---

## Runtime Responsibilities

### Admin Web App

Primary responsibilities:

- email/password sign-in
- child profile management
- task creation and assignment
- review workflow
- points and badge management
- dashboard reporting
- announcement publishing

Rules:

- runs only on Flutter Web
- uses Firebase Auth admin accounts
- never hashes child PIN locally
- performs approval and rejection through callable Cloud Functions

### Child Mobile App

Primary responsibilities:

- profile selection
- PIN login using custom token flow
- task viewing
- proof upload
- submission action
- reward and badge tracking
- notification handling

Rules:

- runs only on Android and iOS for MVP
- child cannot complete tasks directly
- child can only move eligible assignments to `submitted`

### Firebase Backend

Services used:

- Firebase Authentication
- Cloud Firestore
- AWS S3
- Firebase Cloud Messaging
- Firebase Cloud Functions
- Firebase Hosting for admin web

Sensitive responsibilities owned by Cloud Functions:

- child PIN verification
- child PIN hashing
- assignment approval
- assignment rejection
- points ledger writes
- badge awards
- FCM fanout and targeted sends
- recurring task generation if enabled later

---

## Application Layers

Each Flutter app should follow the same four-layer structure.

### 1. Presentation

Contains:

- screens
- widgets
- app shell
- navigation
- view models / controllers

Responsibilities:

- render UI
- map user actions to use cases
- perform local form validation
- subscribe to streams from repositories

### 2. Domain

Contains:

- entities
- enums
- value objects
- use cases
- repository contracts

Responsibilities:

- define task lifecycle rules
- define role capabilities
- keep business rules independent from Firebase SDK specifics

### 3. Data

Contains:

- DTOs / document mappers
- repository implementations
- query builders
- local formatting helpers

Responsibilities:

- convert Firestore documents to typed models
- isolate collection names and field names
- keep query and write behavior consistent across both apps

### 4. Platform / Integration

Contains:

- Firebase initialization
- messaging setup
- storage upload adapters
- emulator wiring

Responsibilities:

- bootstrap environment-specific dependencies
- isolate web-vs-mobile integration differences

---

## Domain Modules

Recommended shared domain modules:

- auth
- children
- tasks
- assignments
- submissions
- reviews
- points
- badges
- announcements
- notifications
- dashboard

Each module should expose:

- typed model classes
- repository contract
- one or more use cases
- status enums
- serializers or mappers in the data layer

---

## Core Lifecycle Rules

### Assignment Statuses

Use one canonical enum across apps and backend:

- `assigned`
- `submitted`
- `approved`
- `completed`
- `rejected`
- `inactive`

Recommended operational meaning:

- `assigned`: visible to child, actionable
- `submitted`: waiting for admin review
- `approved`: admin accepted the proof
- `completed`: terminal success state after approval side effects finish
- `rejected`: child must resubmit
- `inactive`: optional soft-stop for cancelled or archived assignments

For MVP simplicity, you can collapse `approved` and `completed` into a single terminal write in the backend, but keep both enum values reserved in the shared model so the workflow can grow later.

### Source of Truth for Lifecycle Transitions

- child app may create submission documents and mark eligible assignments as `submitted`
- admin app never writes final approval state directly from the client
- Cloud Functions own approve and reject transitions
- only backend logic writes points ledger and total point increments

---

## Recommended Firebase Write Boundaries

Client-safe direct writes:

- admin profile create/update
- child profile create/update except PIN hash
- task create/update
- assignment create
- announcement create
- child submission create
- child notification read-state update

Backend-only writes:

- `pinCodeHash`
- assignment approval / rejection terminal transitions
- points ledger records
- total points increment
- badge awards
- system notifications

---

## Dashboard Strategy

For MVP, compute dashboard cards from Firestore queries instead of building a separate analytics pipeline.

Dashboard cards:

- tasks created today
- pending reviews
- approved tasks today
- rejected tasks today
- per-child points total
- announcements posted today

When these queries become expensive, add denormalized aggregates under a dedicated collection such as `dashboard_daily/{yyyy_mm_dd}`.

---

## Deployment Topology

### Admin Web

- deploy static Flutter Web build to Firebase Hosting
- use preview channels for UI review
- use the same Firebase project as the child app

### Child Mobile

- distribute through Android and iOS build pipelines
- share Firebase project configuration with the admin surface

### Cloud Functions

- use 2nd gen callable and Firestore trigger functions
- keep one named function per business action
- test locally with Emulator Suite before deployment

---

## MVP Delivery Order

### Phase 1

- Firebase project setup
- shared models and enums
- admin auth
- child custom token auth
- basic Firestore collections

### Phase 2

- child management
- task creation
- assignment creation
- child task list and task details

### Phase 3

- proof upload
- submission review
- approval / rejection callable functions
- points ledger

### Phase 4

- badges
- announcements
- push notifications
- dashboard summaries

This keeps the first build working end-to-end before polishing secondary features.
