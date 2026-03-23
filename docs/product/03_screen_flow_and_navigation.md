# VANAVIL Screen Flow And Navigation

## Navigation Principles

- child app should require minimal reading and minimal taps
- admin web should prioritize quick task review and visibility
- every screen should have a single clear primary action
- task state should be visually obvious through badges and card colors

---

## Admin Web Flow

### Primary Navigation

Use a left navigation rail or sidebar on desktop:

- Dashboard
- Children
- Tasks
- Reviews
- Reports
- Badges
- Announcements
- Settings

### Route Map

```text
/login
/dashboard
/children
/children/new
/children/:childId
/children/:childId/edit
/tasks
/tasks/new
/tasks/:taskId
/reviews
/reviews/:assignmentId
/reports
/badges
/announcements
```

### Admin Journey

1. Login
2. Land on dashboard
3. See pending reviews and daily metrics
4. Navigate to child management or task creation
5. Assign tasks
6. Review submitted proof
7. Approve or reject
8. Publish announcements and badges

### Screen Breakdown

#### Login

- email field
- password field
- sign-in button
- error banner

#### Dashboard

- summary cards
- pending review list
- recent announcements
- points by child widget

#### Children List

- child cards or data table
- add child button
- quick status toggle
- search and filter

#### Child Detail

- profile header
- stats strip
- assigned tasks table
- points summary
- badges earned
- set/reset PIN action

#### Task Creation

- title
- description
- comments
- due date
- recurring toggle
- reward points
- save template
- assign now action

#### Review Submission

- task summary
- child info
- proof preview area
- review comment box
- points confirm field
- approve button
- reject button

---

## Child Mobile Flow

### Bottom Navigation

Use 4 tabs for MVP:

- Home
- My Tasks
- Rewards
- Announcements

Completed tasks can live inside Rewards or a dedicated subpage from Home.

### Route Map

```text
/profile-select
/pin-login
/home
/tasks
/tasks/:assignmentId
/upload-proof/:assignmentId
/rewards
/completed
/announcements
```

### Child Journey

1. Select profile
2. Enter PIN
3. View Home dashboard
4. Open assigned task
5. Upload proof
6. Submit task
7. Wait for review update
8. See points, badges, and announcements

### Screen Breakdown

#### Profile Selection

- avatar grid
- child name labels
- active/inactive guard

#### PIN Login

- selected avatar header
- 4-digit keypad or PIN input
- simple retry message

#### Home

- new tasks carousel
- review updates card
- latest badge highlight
- announcement teaser list

#### My Tasks

- segmented filters: Assigned, Needs Fix, Submitted
- large task cards
- due date badge
- reward points chip

#### Task Detail

- title
- description
- comments from admin
- due date
- reward points
- upload proof button
- submit button

#### Upload Proof

- choose photo/video/audio
- preview panel
- note field
- upload action

#### Rewards

- points total hero card
- recent points list
- badge gallery
- completed tasks shortcut

#### Completed Tasks

- completed task timeline
- badge chips
- earned points per task

#### Announcements

- announcement cards with publish date

---

## Recommended Routing Approach

### Admin Web

- use guarded routes based on admin auth state
- keep route paths readable for browser history and deep links
- use shell layout around authenticated admin routes

### Child Mobile

- use auth gate after profile + PIN token exchange
- keep nested navigation shallow
- pass assignment IDs through typed route arguments

---

## Empty States And Error States

### Admin Empty States

- no children yet
- no tasks yet
- no submissions to review
- no announcements yet

### Child Empty States

- no tasks assigned
- no badges yet
- no announcements yet
- submission failed upload

Every empty state should provide one direct next action or explanation.
