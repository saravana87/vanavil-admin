Build a full MVP product called “VANAVIL”.

Goal:
Create a system where an admin uses a website to manage children and assign tasks, while children use a mobile app to view tasks, submit proof, and track points, badges, and announcements.

Tech stack:
- Flutter for frontend
- Flutter Web for Admin Website
- Flutter Mobile for Child App
- Firebase Authentication
- Cloud Firestore
- AWS S3
- Firebase Cloud Messaging
- Firebase Cloud Functions

Product roles:
1. Admin
- Admin can log in only on the website using email and password
- Admin can add and manage child profiles
- Admin can create tasks
- Admin can assign tasks to one or more children
- Admin can review child submissions
- Admin can approve or reject submissions
- Admin can award points
- Admin can give badges
- Admin can post announcements
- Admin can view dashboard reports

2. Child
- Child uses only the mobile app
- Child does not have email login
- Child logs in by selecting profile and entering a 4-digit PIN
- Child can view assigned tasks
- Child can view task details
- Child can upload proof using photo, video, or audio
- Child can submit task status
- Child can view points
- Child can view badges
- Child can view announcements
- Child can view completed tasks

Core task flow:
Assigned → Submitted → Approved → Completed
If rejected:
Submitted → Rejected → Resubmit

Important rule:
- Child cannot directly mark a task as completed
- Only admin approval changes the flow to completed

Admin website screens:
1. Login
- Email
- Password

2. Dashboard
Include summary cards for:
- total tasks created today
- pending reviews
- approved tasks
- rejected tasks
- points earned by each child
- announcements posted today

3. Manage Children
- add child
- edit child
- activate/deactivate child
- assign avatar
- set PIN
- view child stats

4. Create Task
Fields:
- task name
- description
- comments
- due date
- recurring daily or not
- reward points
- create button
- previous task templates

5. Task List
- task name
- due date
- reward points
- assigned child
- status

6. Review Submission
- list of submitted files
- preview uploaded proof
- approve button
- reject button
- add comment
- add or confirm points

7. Child Report / Points Summary
- completed task list
- review comments
- total reward points assigned
- total reward points earned
- badge count

8. Special Appreciation / Give Badge
- choose child
- choose badge
- add appreciation message
- save

9. Announcements
- create announcement
- list announcements
- set visibility date

Child mobile app screens:
1. Profile Selection / PIN Login
- select child profile
- enter PIN

2. Dashboard
Show:
- newly assigned tasks
- review updates
- recently received badges
- latest announcements

3. My Tasks
- list all assigned tasks
- due date
- task status
- reward points

4. Task Details
- task name
- description
- comments
- due date
- reward points
- upload proof button
- submit button

5. Upload Proof
- choose photo, video, or audio
- preview selected file
- submit proof

6. My Points
- points table
- task name
- points earned
- total points

7. Completed Tasks
- completed task list
- badges received
- total points earned

8. Announcements
- list admin announcements

Notifications:
- new task assigned
- submission approved
- submission rejected
- badge received
- new announcement posted

Design requirements:
- Bright, colorful, child-friendly UI
- Clean and simple admin website
- Child mobile app should feel playful and rewarding
- Use large buttons, rounded cards, colorful badges, and simple navigation
- Keep the child app extremely easy to use
- Admin dashboard should be more structured and clean

Firebase requirements:
Use Firestore collections like:
- admins
- children
- tasks
- assignments
- submissions
- reviews
- points_ledger
- badges
- child_badges
- announcements
- notifications

Suggested fields:
children:
- childId
- adminId
- name
- avatar
- pinCodeHash
- age
- status
- totalPoints
- createdAt

tasks:
- taskId
- title
- description
- comments
- rewardPoints
- recurringDaily
- createdBy
- createdAt

assignments:
- assignmentId
- taskId
- childId
- assignedBy
- dueDate
- status
- assignedAt
- submittedAt
- approvedAt
- rejectedAt

submissions:
- submissionId
- assignmentId
- childId
- proofType
- fileUrl
- note
- uploadedAt

reviews:
- reviewId
- assignmentId
- adminId
- decision
- comment
- pointsAwarded
- reviewedAt

points_ledger:
- ledgerId
- childId
- assignmentId
- points
- reason
- createdAt

badges:
- badgeId
- title
- icon
- description

child_badges:
- childBadgeId
- childId
- badgeId
- awardedBy
- awardedAt
- reason

announcements:
- announcementId
- title
- message
- createdBy
- createdAt

notifications:
- notificationId
- childId
- type
- title
- message
- isRead
- createdAt

Development expectations:
- Generate a proper project structure
- Separate admin web and child mobile modules clearly
- Use reusable widgets/components
- Add Firebase integration setup
- Add role-based routing
- Add Firestore model classes
- Add service layer for Firebase
- Add sample UI screens
- Add clean navigation flow
- Add form validation
- Add secure PIN handling for child login
- Add status management for task lifecycle
- Add comments where needed for future extension

Output needed:
1. Full project architecture
2. Folder structure
3. Firestore schema
4. Screen flow
5. Flutter widget/module breakdown
6. Firebase integration plan
7. Starter code for admin website
8. Starter code for child mobile app
9. Reusable models and services
10. MVP-first implementation approach

Important:
Keep the solution MVP-friendly, scalable, and easy to understand.
Do not overcomplicate the first version.
Focus on a working product with clean architecture.