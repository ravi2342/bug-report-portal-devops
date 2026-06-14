# Bug Report Portal - Complete Functionality Guide

**Comprehensive guide explaining how the portal works, user workflows, data flow, and database relationships**

---

## 📋 Table of Contents

1. [Portal Overview](#portal-overview)
2. [Core Features](#core-features)
3. [User Workflows](#user-workflows)
4. [Database Data Model](#database-data-model)
5. [Application Architecture](#application-architecture)
6. [Detailed User Scenarios](#detailed-user-scenarios)
7. [Data Flow Examples](#data-flow-examples)
8. [Admin Features](#admin-features)

---

## 🎯 Portal Overview

### What is the Bug Report Portal?

A **web-based incident/bug tracking system** that allows teams to:
- ✅ Report bugs and incidents
- ✅ Track issue status and progress
- ✅ Collaborate through comments
- ✅ Maintain audit trail of all changes
- ✅ Assign issues to team members

### Key Stats

```
Pages:        5 main pages
Tables:       3 database tables
Users:        Multiple (admin account: admin/admin123)
Data Storage: PostgreSQL database
Access:       Web browser (http://localhost:8888)
```

---

## ✨ Core Features

### 1. Dashboard
```
Purpose: Overview of all bug reports
Shows:
  - Total number of incidents
  - Incidents by status (OPEN, IN_PROGRESS, DONE)
  - Quick links to all incidents
  - Filter/search capabilities
```

### 2. Create Incident
```
Purpose: Submit a new bug report
Fields:
  - Title: Brief description of issue
  - Description: Detailed explanation
  - Priority: Critical, High, Medium, Low
  - Reporter: Who reported it
  - Screenshot: Attachment/image
  - Status: Defaults to OPEN
```

### 3. View Incident Details
```
Purpose: See full incident information
Includes:
  - All incident details (title, description, etc.)
  - Current status
  - Reporter information
  - Comments section (conversation)
  - Activity log (all changes)
  - Edit button
  - Status change workflow
```

### 4. Comments & Collaboration
```
Purpose: Discuss and resolve issues
Features:
  - Add comments to incidents
  - Comments linked to specific incident
  - Each comment shows author and timestamp
  - Full audit trail of discussion
```

### 5. Activity Log
```
Purpose: Track all changes
Records:
  - When incident was created
  - When status changed (OPEN → IN_PROGRESS)
  - When comments added
  - Who made changes
  - What changed
  - When it changed (exact timestamp)
```

---

## 👤 User Workflows

### Workflow 1: Report a Bug

```
1. User opens portal
   └─ URL: http://localhost:8888
   └─ Sees: Dashboard with existing incidents

2. User clicks "Create Report" or "+" button
   └─ Form opens with fields:
      - Title (required)
      - Description (required)
      - Priority dropdown
      - Reporter name
      - Screenshot upload
      - Status (auto-set to OPEN)

3. User fills form
   └─ Title: "Login button not responding"
   └─ Description: "When I click login, nothing happens"
   └─ Priority: "High"
   └─ Reporter: "QA Team"
   └─ Screenshot: uploads screenshot

4. User clicks "Submit" / "Create"
   └─ Request sent to backend
   └─ Backend validates input
   └─ Database INSERT into BugReport table
   └─ Activity log created automatically
   └─ Response: "Incident #1 created successfully"

5. User redirected to incident details page
   └─ Shows: "Incident 1 - Login button not responding"
   └─ Status: OPEN
   └─ All details displayed
   └─ Comments section empty (no comments yet)
   └─ Activity log shows: "Created at 2026-06-14 10:45:00"

Data Flow:
User Form Input
    ↓
Express API (/api/reports POST)
    ↓
Prisma Client
    ↓
PostgreSQL Database (INSERT)
    ↓
BugReport table gets new row:
  {
    id: 1,
    title: "Login button not responding",
    description: "When I click login, nothing happens",
    priority: "High",
    reporter: "QA Team",
    status: "OPEN",
    createdAt: "2026-06-14 10:45:00",
    updatedAt: "2026-06-14 10:45:00"
  }

ActivityLog table gets:
  {
    id: 1,
    reportId: 1,
    actor: "system",
    action: "CREATED",
    createdAt: "2026-06-14 10:45:00"
  }
```

---

### Workflow 2: Add Comment to Incident

```
1. User views incident details page
   └─ Sees incident #1 information
   └─ Sees "Comments" section
   └─ Sees "Add Comment" text area

2. User types comment
   └─ Text: "I can reproduce this on Chrome and Firefox"

3. User clicks "Add Comment" button
   └─ Request sent to backend

4. Backend processes:
   └─ Validates: commentText not empty
   └─ Validates: reportId = 1 exists in BugReport table
   └─ Database INSERT into Comment table
   └─ Database INSERT into ActivityLog table

5. Page refreshes/updates
   └─ New comment appears in "Comments" section
   └─ Shows: "admin • 6/14/2026, 10:47:15 AM"
   └─ Shows: "I can reproduce this on Chrome and Firefox"
   └─ Activity tab updated

Data Flow:
User clicks "Add Comment"
    ↓
Express API (/api/reports/1/comments POST)
    ↓
Prisma Client
    ↓
PostgreSQL Database (INSERT × 2)
    ↓
1. Comment table gets:
  {
    id: 1,
    reportId: 1,
    author: "admin",
    text: "I can reproduce this on Chrome and Firefox",
    createdAt: "2026-06-14 10:47:15"
  }

2. ActivityLog table gets:
  {
    id: 2,
    reportId: 1,
    actor: "admin",
    action: "COMMENT_ADDED",
    details: "I can reproduce this on Chrome and Firefox",
    createdAt: "2026-06-14 10:47:15"
  }
```

---

### Workflow 3: Change Incident Status

```
1. User views incident details page
   └─ Current status: OPEN

2. User sees status workflow buttons:
   ┌─────────────┐    ┌──────────────┐    ┌────┐
   │    OPEN     │ -> │ IN_PROGRESS  │ -> │ DONE│
   └─────────────┘    └──────────────┘    └────┘

3. User clicks: OPEN → IN_PROGRESS
   └─ Confirms action (optional)

4. Backend processes:
   └─ Validates: incident exists
   └─ Database UPDATE BugReport table
   └─ Database INSERT into ActivityLog table

5. Page updates
   └─ Status now shows: "IN_PROGRESS"
   └─ Activity log updated

Data Flow:
User clicks "IN_PROGRESS"
    ↓
Express API (/api/reports/1 PATCH)
    ↓
Prisma Client
    ↓
PostgreSQL Database (UPDATE + INSERT)
    ↓
1. BugReport table (UPDATE row 1):
  {
    id: 1,
    ...
    status: "IN_PROGRESS",  ← Changed from OPEN
    updatedAt: "2026-06-14 10:48:30"
  }

2. ActivityLog table (INSERT):
  {
    id: 3,
    reportId: 1,
    actor: "admin",
    action: "STATUS_CHANGED",
    details: "OPEN → IN_PROGRESS",
    createdAt: "2026-06-14 10:48:30"
  }
```

---

### Workflow 4: Upload Screenshot

```
1. User creates/edits incident
   └─ Sees "Attachment" upload field

2. User clicks "Click to upload or drag and drop"
   └─ File picker opens

3. User selects image file (PNG, JPG, etc.)
   └─ File uploaded to backend

4. Backend processes:
   └─ Validates: file is image
   └─ Saves to: /app/uploads/[timestamp]-[filename]
   └─ Returns: URL to frontend

5. Frontend displays
   └─ Shows: Thumbnail of uploaded image
   └─ Shows: Download link

Example:
Filename: Screenshot.png
Uploaded as: /uploads/1781433985935-Screenshot.png
Displayed as: ![Incident screenshot](http://localhost:8888/uploads/1781433985935-Screenshot.png)
```

---

## 📊 Database Data Model

### Table 1: BugReport

**Purpose:** Stores all bug reports/incidents

```sql
CREATE TABLE "BugReport" (
  id          INT PRIMARY KEY AUTO_INCREMENT,
  title       VARCHAR NOT NULL,
  description VARCHAR NOT NULL,
  priority    VARCHAR,
  reporter    VARCHAR,
  screenshot  VARCHAR,
  status      ENUM('OPEN', 'IN_PROGRESS', 'DONE') DEFAULT 'OPEN',
  assignee    VARCHAR,
  createdAt   TIMESTAMP DEFAULT NOW(),
  updatedAt   TIMESTAMP DEFAULT NOW(),
  resolvedAt  TIMESTAMP
);
```

**Example Data:**
```
id | title                      | priority | status       | reporter  | createdAt
---|----------------------------|----------|--------------|-----------|-------------------
1  | Login button not working   | High     | IN_PROGRESS  | QA Team   | 2026-06-14 10:45
2  | Database connection timeout| Critical | OPEN         | Backend   | 2026-06-14 11:22
3  | UI layout broken on mobile | Medium   | DONE         | Frontend  | 2026-06-14 09:30
```

---

### Table 2: Comment

**Purpose:** Stores comments/discussion on incidents

```sql
CREATE TABLE "Comment" (
  id        INT PRIMARY KEY AUTO_INCREMENT,
  reportId  INT NOT NULL,
  author    VARCHAR NOT NULL,
  text      VARCHAR NOT NULL,
  createdAt TIMESTAMP DEFAULT NOW(),
  
  FOREIGN KEY (reportId) REFERENCES BugReport(id) ON DELETE CASCADE
);
```

**Example Data:**
```
id | reportId | author | text                                    | createdAt
---|----------|--------|----------------------------------------|-------------------
1  | 1        | admin  | I can reproduce this                   | 2026-06-14 10:47
2  | 1        | qa     | Also happens on Firefox                | 2026-06-14 10:50
3  | 2        | devops | Checking database logs                 | 2026-06-14 11:25
```

**Relationships:**
```
BugReport (1) ──────── (many) Comment
  id=1                    reportId=1 (3 comments)
  id=2                    reportId=2 (1 comment)
  id=3                    reportId=3 (0 comments)
```

---

### Table 3: ActivityLog

**Purpose:** Audit trail of all changes

```sql
CREATE TABLE "ActivityLog" (
  id        INT PRIMARY KEY AUTO_INCREMENT,
  reportId  INT NOT NULL,
  actor     VARCHAR NOT NULL,
  action    VARCHAR NOT NULL,
  details   VARCHAR,
  createdAt TIMESTAMP DEFAULT NOW(),
  
  FOREIGN KEY (reportId) REFERENCES BugReport(id) ON DELETE CASCADE
);
```

**Example Data:**
```
id | reportId | actor  | action            | details                  | createdAt
---|----------|--------|-------------------|--------------------------|-------------------
1  | 1        | system | CREATED           | -                        | 2026-06-14 10:45
2  | 1        | admin  | COMMENT_ADDED     | "I can reproduce"        | 2026-06-14 10:47
3  | 1        | qa     | COMMENT_ADDED     | "Also on Firefox"        | 2026-06-14 10:50
4  | 1        | admin  | STATUS_CHANGED    | "OPEN → IN_PROGRESS"     | 2026-06-14 10:48
5  | 2        | system | CREATED           | -                        | 2026-06-14 11:22
```

**Full Activity Trail for Incident #1:**
```
Timeline (chronological):
10:45 - System: Created incident
10:47 - Admin: Added comment "I can reproduce"
10:48 - Admin: Status changed OPEN → IN_PROGRESS
10:50 - QA: Added comment "Also on Firefox"
```

---

## 🏗️ Application Architecture

### Frontend (User Interface)

```
Pages:
├── Dashboard (/incidents)
│   └─ Shows all incidents
│   └─ Filter by status
│   └─ Search by title
│   └─ Quick stats (total, open, in progress, done)
│
├── Create Incident (/incidents/create)
│   └─ Form to submit new bug
│   └─ File upload for screenshot
│
├── Incident Details (/incidents/:id)
│   └─ Full incident information
│   └─ Comments section
│   └─ Activity log
│   └─ Status change buttons
│   └─ Edit button
│
├── Edit Incident (/incidents/:id/edit)
│   └─ Modify incident details
│
└── Login (/login)
    └─ Authentication
    └─ Username: admin
    └─ Password: admin123
```

### Backend (Express.js API)

```
API Endpoints:

GET /api/reports
  └─ Fetch all bug reports
  └─ Response: [{ id, title, description, status, ... }, ...]

GET /api/reports/:id
  └─ Fetch single incident + comments + activity
  └─ Response: { id, title, ..., comments: [], activities: [] }

POST /api/reports
  └─ Create new incident
  └─ Body: { title, description, priority, reporter, screenshot }
  └─ Response: { id, success: true }

PATCH /api/reports/:id
  └─ Update incident (status, title, description)
  └─ Body: { status, title, description }
  └─ Response: { id, updated: true }

POST /api/reports/:id/comments
  └─ Add comment to incident
  └─ Body: { text, author }
  └─ Response: { id, createdAt }

GET /api/reports/:id/activity
  └─ Fetch activity log for incident
  └─ Response: [{ action, actor, details, createdAt }, ...]
```

### Database (PostgreSQL)

```
Connected via:
  DATABASE_URL: postgresql://postgres:postgres@postgres:5432/bugreportportal

Tables:
  ├─ BugReport (incidents)
  ├─ Comment (discussion)
  └─ ActivityLog (audit trail)

Connections:
  BugReport (1) ←→ (many) Comment
  BugReport (1) ←→ (many) ActivityLog
```

---

## 📝 Detailed User Scenarios

### Scenario 1: Complete Incident Lifecycle

```
TIME: 10:45 AM - QA discovers bug

STEP 1: Report Bug
├─ User: QA Engineer
├─ Action: Create new incident
├─ Data:
│  - Title: "Login button not responding"
│  - Description: "Clicking login does nothing on Chrome"
│  - Priority: "High"
│  - Reporter: "QA Team"
│  - Screenshot: uploaded_screenshot.png
├─ Database: BugReport row inserted (id=1, status=OPEN)
└─ Result: Incident #1 created ✅

TIME: 10:47 AM - Admin acknowledges

STEP 2: Admin Reviews & Comments
├─ User: Admin
├─ Action: Views incident, adds comment
├─ Comment: "I can reproduce this on my machine"
├─ Database: Comment row inserted (id=1, reportId=1)
└─ Result: Comment visible on incident page ✅

TIME: 10:48 AM - Work begins

STEP 3: Change Status to "In Progress"
├─ User: Admin
├─ Action: Click "IN_PROGRESS" button
├─ Database: BugReport updated (status=IN_PROGRESS)
└─ Result: Status changed, activity logged ✅

TIME: 11:30 AM - Developer adds info

STEP 4: Another Comment
├─ User: Developer
├─ Comment: "Found issue in authentication module, fixing now"
├─ Database: Comment row inserted (id=2, reportId=1)
└─ Result: Team informed of progress ✅

TIME: 12:00 PM - Bug fixed

STEP 5: Change Status to "Done"
├─ User: Developer
├─ Action: Click "DONE" button
├─ Database: BugReport updated (status=DONE)
└─ Result: Incident marked resolved ✅

TIME: Any time - Full audit trail visible

STEP 6: View Activity Log
├─ User: Anyone
├─ Action: Click "Activity" tab on incident
├─ Sees:
│  - 10:45 AM: System created incident
│  - 10:47 AM: Admin added comment
│  - 10:48 AM: Admin changed status OPEN → IN_PROGRESS
│  - 11:30 AM: Developer added comment
│  - 12:00 PM: Developer changed status IN_PROGRESS → DONE
└─ Result: Complete history visible ✅
```

---

### Scenario 2: Complex Collaboration

```
Team: Frontend, Backend, QA, DevOps

INCIDENT #2: "Database connection timeout"

10:00 AM - QA Reports
├─ Creates incident
├─ Priority: Critical
├─ Description: "All API calls fail with connection timeout"

10:05 AM - Backend Comments
├─ Comment: "Can you provide error logs?"
├─ Comment: "What's the exact timestamp when it started?"

10:10 AM - QA Responds
├─ Comment: "Started at 10:00 AM exactly, logs attached"
├─ Uploads screenshot of error

10:15 AM - DevOps Investigates
├─ Comment: "Checking database server health..."
├─ Changes status: OPEN → IN_PROGRESS

10:20 AM - DevOps Updates
├─ Comment: "Found issue: database connections maxed out"
├─ Comment: "Restarting connection pool now"

10:25 AM - Backend Confirms
├─ Comment: "API working again! Thanks DevOps"

10:30 AM - Close Issue
├─ DevOps changes status: IN_PROGRESS → DONE
├─ Comment: "Connection pool restart resolved the issue"

Result:
- 5 people collaborated
- 6 comments in thread
- 2 status changes
- Complete audit trail of troubleshooting
- Next time, team knows exactly what happened
```

---

## 🔄 Data Flow Examples

### Flow 1: Creating an Incident

```
┌─────────────────────────────────────────────────┐
│ User opens browser                              │
│ http://localhost:8888                           │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Frontend (React/Vue)                            │
│ - Dashboard page loads                          │
│ - Shows all incidents                           │
│ - User clicks "+ Create Report"                 │
│ - Form opens                                    │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ User fills form                                 │
│ - Title: "Login button..."                      │
│ - Description: "..."                            │
│ - Priority: High                                │
│ - Screenshot: uploads file                      │
│ - Clicks "Create"                               │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Frontend sends HTTP POST                        │
│ POST /api/reports                               │
│ {                                               │
│   title: "Login button not working",            │
│   description: "...",                           │
│   priority: "High",                             │
│   reporter: "QA Team",                          │
│   screenshot: "file_path"                       │
│ }                                               │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Express Backend                                 │
│ - Receives POST request                         │
│ - Validates input                               │
│ - Generates timestamp                           │
│ - Prepares data                                 │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Prisma Client                                   │
│ - Builds SQL INSERT query                       │
│ - Executes query                                │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ PostgreSQL Database                             │
│ - Receives INSERT                               │
│ - Validates schema                              │
│ - Adds row to BugReport table                   │
│ - Generates auto-increment ID (id=5)            │
│ - Confirms: 1 row inserted                      │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ ActivityLog Table                               │
│ - Backend also inserts audit entry              │
│ - reportId: 5                                   │
│ - action: "CREATED"                             │
│ - actor: "system"                               │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Response sent to Frontend                       │
│ {                                               │
│   success: true,                                │
│   id: 5,                                        │
│   message: "Incident created successfully"      │
│ }                                               │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Frontend updates UI                             │
│ - Redirects to /incidents/5                     │
│ - Shows new incident details                    │
│ - User sees: "Incident #5 - Login button..."    │
│ - Status: OPEN                                  │
│ - Comments: none yet                            │
│ - Activity: Created 5 minutes ago               │
└─────────────────────────────────────────────────┘
```

---

### Flow 2: Adding a Comment

```
┌─────────────────────────────────────────────────┐
│ User viewing Incident #5                        │
│ Sees "Add Comment" text area                    │
│ Types: "I can also reproduce this on Firefox"   │
│ Clicks "Post Comment"                           │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Frontend validates                              │
│ - Check: text not empty ✓                       │
│ - Check: incident ID valid ✓                    │
│ - Get: current user (admin)                     │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Frontend sends HTTP POST                        │
│ POST /api/reports/5/comments                    │
│ {                                               │
│   text: "I can also reproduce on Firefox",      │
│   author: "admin"                               │
│ }                                               │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Express Backend                                 │
│ - Receives POST request                         │
│ - Validates: reportId 5 exists                  │
│ - Validates: text not empty                     │
│ - Prepares comment data                         │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Database Operations (2 operations)              │
│                                                 │
│ 1️⃣  INSERT into Comment table                   │
│  - id: auto-increment                           │
│  - reportId: 5                                  │
│  - author: "admin"                              │
│  - text: "I can also reproduce on Firefox"      │
│  - createdAt: current timestamp                 │
│                                                 │
│ 2️⃣  INSERT into ActivityLog table               │
│  - id: auto-increment                           │
│  - reportId: 5                                  │
│  - actor: "admin"                               │
│  - action: "COMMENT_ADDED"                      │
│  - details: "I can also reproduce on Firefox"   │
│  - createdAt: current timestamp                 │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Response sent to Frontend                       │
│ {                                               │
│   success: true,                                │
│   commentId: 12,                                │
│   message: "Comment added"                      │
│ }                                               │
└──────────────┬──────────────────────────────────┘
               │
               ↓
┌─────────────────────────────────────────────────┐
│ Frontend updates UI                             │
│ - Clears text area                              │
│ - Adds comment to comments section:             │
│   "admin • 2026-06-14, 10:52 AM"                │
│   "I can also reproduce on Firefox"             │
│ - Refreshes Activity tab                        │
│ - Shows: "admin added comment at 10:52 AM"      │
└─────────────────────────────────────────────────┘
```

---

## 🔐 Admin Features

### User Management

```
Current Setup:
  - Admin user: admin
  - Password: admin123
  - Stored in: bug-report-portal-secrets (Kubernetes Secret)
  - Authentication: Session-based
```

### Status Workflow

```
Valid Status Transitions:

OPEN
  ├─ Can change to: IN_PROGRESS
  └─ Meaning: Issue confirmed, work starting

IN_PROGRESS
  ├─ Can change to: DONE
  ├─ Can revert to: OPEN
  └─ Meaning: Actively being worked on

DONE
  ├─ Meaning: Issue resolved/fixed
  └─ Note: Can't add new incidents, but can view history

Workflow Diagram:
┌────────────┐
│   OPEN     │ ← Initial status for all incidents
└──────┬─────┘
       │
       ↓
┌──────────────────┐
│  IN_PROGRESS     │ ← Work being done
└──────┬────────┬──┘
       │        │
       ↓        ↓ (can revert)
    ┌──────┐  OPEN
    │ DONE │
    └──────┘ ← Final status
```

### Priority Levels

```
CRITICAL
  - System down, all users affected
  - Needs immediate attention
  - Example: "Database completely down"

HIGH
  - Major feature broken
  - Many users affected
  - Example: "Login button not working"

MEDIUM
  - Feature partially working
  - Some users affected
  - Example: "Search results slow"

LOW
  - Minor issue
  - Cosmetic or small functionality
  - Example: "Button color slightly off"
```

---

## 🔗 Relationships & Integrity

### Data Relationships

```
BugReport (parent) ──1:N──> Comment (child)
  - Delete incident → All comments deleted
  - Example: Delete incident #5 → Remove comments 1,2,3,4
  - Relationship type: CASCADE

BugReport (parent) ──1:N──> ActivityLog (child)
  - Delete incident → All activity logs deleted
  - Complete history removed with incident
  - Relationship type: CASCADE
```

### Referential Integrity

```
When user creates comment:
  ✓ Must reference existing BugReport (reportId)
  ✗ Cannot create comment for non-existent incident

When activity log created:
  ✓ reportId must reference existing BugReport
  ✗ Cannot log activity for non-existent incident

When incident deleted:
  ✓ All child records (comments, activity) deleted
  ✓ No orphaned records left
```

---

## 📊 Example Data State

### Current State (After Scenario 1)

```
BugReport Table:
┌───┬────────────────────────────┬──────────┬──────┐
│id │ title                      │ status   │ prio │
├───┼────────────────────────────┼──────────┼──────┤
│1  │ Login button not responding│ DONE     │ HIGH │
│2  │ DB connection timeout      │ OPEN     │ CRIT │
│3  │ UI broken on mobile        │ IN_PROG  │ MED  │
└───┴────────────────────────────┴──────────┴──────┘

Comment Table:
┌───┬──────────┬────────┬──────────────────────────┐
│id │reportId  │author  │ text                     │
├───┼──────────┼────────┼──────────────────────────┤
│1  │ 1        │admin   │ I can reproduce this     │
│2  │ 1        │qa      │ Also on Firefox          │
│3  │ 2        │devops  │ Checking DB health...    │
│4  │ 3        │front   │ Working on CSS media     │
│5  │ 3        │front   │ Fixed in latest build    │
└───┴──────────┴────────┴──────────────────────────┘

ActivityLog Table:
┌───┬──────────┬────────┬───────────────┬──────────────────┐
│id │reportId  │actor   │action         │ timestamp        │
├───┼──────────┼────────┼───────────────┼──────────────────┤
│1  │ 1        │system  │CREATED        │ 10:45 AM         │
│2  │ 1        │admin   │COMMENT_ADDED  │ 10:47 AM         │
│3  │ 1        │qa      │COMMENT_ADDED  │ 10:50 AM         │
│4  │ 1        │admin   │STATUS_CHANGED │ 10:48 AM         │
│5  │ 1        │dev     │STATUS_CHANGED │ 12:00 PM         │
│6  │ 2        │system  │CREATED        │ 11:22 AM         │
│7  │ 2        │devops  │COMMENT_ADDED  │ 11:35 AM         │
│8  │ 3        │system  │CREATED        │ 09:30 AM         │
└───┴──────────┴────────┴───────────────┴──────────────────┘
```

---

## 🎯 Summary

The Bug Report Portal is a **complete incident/bug tracking system** that:

✅ **Captures**: Issues with full details, screenshots, priority
✅ **Tracks**: Status through workflow (OPEN → IN_PROGRESS → DONE)
✅ **Collaborates**: Team comments with full audit trail
✅ **Maintains**: Complete history of all changes
✅ **Stores**: All data persistently in PostgreSQL
✅ **Scales**: Supports unlimited incidents, comments, activity

**Key Principle**: Every action is logged, every relationship maintained, every bit of data preserved for complete transparency and auditability.

