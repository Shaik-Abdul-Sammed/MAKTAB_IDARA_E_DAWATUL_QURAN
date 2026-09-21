## Step 0 — Pre-flight: Verify Teacher Accounts Exist in RTDB

**Do this BEFORE running any device test.** It takes 2 minutes and can save hours.

### 0A — Firebase Console → Authentication → Users

Open **Firebase Console → Authentication → Users**.

Search for each of the following emails:
- `teacher_MAKTAB-001_2018@maktab.app`
- `teacher_MAKTAB-001_20261@maktab.app`

For each email:

| Email | Present in Auth? | UID | Last sign-in |
|-------|----------------|-----|-------------|
| `teacher_MAKTAB-001_2018@maktab.app` | YES / NO | (copy) | (timestamp) |
| `teacher_MAKTAB-001_20261@maktab.app` | YES / NO | (copy) | (timestamp) |

> **If any email is MISSING from Authentication → Users:**  
> `provisionTeacherAuthAccount` never ran successfully for that teacher.  
> **Stop here. Do not run the device tests. Tell the AI: "Teacher 2018 not in Firebase Auth."**  
> The AI will apply Fix 1 (secondary-app write) and rebuild.

### 0B — Firebase Console → Realtime Database → Data → /users

For each UID found in Step 0A, navigate to `/users/{uid}` in RTDB Data view.

Confirm the following fields exist with correct values:

| Field | Expected | Actual |
|-------|---------|--------|
| `role` | `teacher` | |
| `maktabId` | `MAKTAB-001` | |
| `active` | `true` | |
| `teacherId` | `2018` or `20261` (NOT `1`) | |
| `pinHash` | 64-character hex string (present) | |

> **If the Auth account exists (0A = YES) but `/users/{uid}` node is MISSING or incomplete:**  
> This is Root Cause D1 confirmed — the provisioning write was silently rejected.  
> **Stop here. Tell the AI: "Auth exists, RTDB node missing for teacher 2018."**  
> The AI will inspect why provisioning failed.

> **If both Auth account and RTDB node exist, but `teacherId` = `1` or `pinHash` is missing:**  
> This is Root Cause D2 confirmed — self-provision wrote wrong teacherId or missed pinHash.  
> **Tell the AI: "RTDB node exists but teacherId=1 or pinHash missing for teacher 2018."**  

> **If all fields are correct for all teachers:** Continue to Step 1.

# Sync Diagnostics Runbook

## Prerequisites

- **Manager account credentials:** email & password used for Firebase Email/Password login (the admin account provisioned in Firebase Console)
- **Teacher 1 credentials:** teacherId=`2018`, PIN=`123456`
- **Teacher 2 credentials:** teacherId=`20261`, PIN=`123456`
- **Firebase project:** `maktab-management-99001`
- **RTDB URL:** `https://maktab-management-99001-default-rtdb.asia-southeast1.firebasedatabase.app`
- **Expected maktabId:** `MAKTAB-001` (verify with `[MAKTAB FINGERPRINT]` log)
- Both devices on the same network OR both online with cellular/WiFi

> **Build requirement:** The APK must be a **debug build** (`flutter build apk --debug`) for `kDebugMode` to be `true` and the "Sync Diagnostics" entry to appear under Settings.

---

## Step 1 — Manager Diagnostic

1. Launch the **Manager debug build** on Device A.
2. Log in with **email & password**.
3. Wait for the dashboard to fully load (≥ 3 seconds).
4. Navigate to **Settings → Diagnostics & Sync**.
5. Tap **"Re-run Probe"**. Wait for the snackbar "Startup probe completed".
6. Tap **"Copy to Clipboard"**.
7. Paste the clipboard output in the chat as:

```
=== MANAGER DIAGNOSTIC ===
<paste here>
```

---

## Step 2 — Manager Write Test

1. From the Manager dashboard, add a **new student**:
   - Name: `Diag Test 2026-09-21` (replace date with today's date)
   - Batch: any existing batch
   - Other required fields: use any valid values
2. After saving, return to **Settings → Diagnostics & Sync**.
3. Tap **"Re-run Probe"**, then **"Copy to Clipboard"**.
4. Paste as:

```
=== MANAGER POST-WRITE DIAGNOSTIC ===
<paste here>
```

5. Open **Firebase Console → Realtime Database → Data → `/maktabs/MAKTAB-001/students`**.
6. Report (with your paste):
   - **Does `Diag Test 2026-09-21` appear in the Console?** YES / NO
   - **If NO:** Copy the exact path you navigated to.

---

## Step 3 — Teacher Diagnostic

1. Launch the **Teacher debug build** on Device B.
2. Log in with **Teacher ID `2018`** and **PIN `123456`**.
3. Wait for the Teacher Portal to fully load (≥ 5 seconds — Firebase auth happens in background).
4. Navigate to **Settings → Diagnostics & Sync**.
5. Tap **"Re-run Probe"**. Wait for completion.
6. Tap **"Copy to Clipboard"**.
7. Paste as:

```
=== TEACHER DIAGNOSTIC ===
<paste here>
```

8. Check the **student list** screen:
   - **Does `Diag Test 2026-09-21` appear?** YES / NO

> If the Diagnostics entry does NOT appear in Settings, the app is running as a **release build**. Rebuild with `flutter build apk --debug`.

---

## Step 4 — Teacher Attendance Test

1. From the Teacher Portal, mark **attendance for any student** (present or absent).
2. Return to **Settings → Diagnostics & Sync**.
3. Tap **"Re-run Probe"**, then **"Copy to Clipboard"**.
4. Paste as:

```
=== TEACHER POST-ATTENDANCE DIAGNOSTIC ===
<paste here>
```

5. On the **Manager device**, navigate to the attendance screen and pull-to-refresh.
6. Report:
   - **Does the attendance record appear on the Manager?** YES / NO
   - **Attendance path probed:** `[RTDB Probe] /maktabs/.../attendance count:` (copy from diagnostic)

---

## Step 5 — Console Cross-Check

After all 4 diagnostic outputs are collected, verify manually in **Firebase Console → Realtime Database → Data**:

| Path | Expected |
|------|----------|
| `/users/{manager_uid}` | exists; `role=admin` or `manager`; `maktabId=MAKTAB-001`; `active=true` |
| `/users/{teacher_uid}` | exists; `role=teacher`; `maktabId=MAKTAB-001`; `active=true`; `teacherId=2018` (or `20261`); `pinHash` present |
| `/maktabs/MAKTAB-001/students/{id}` | new student `Diag Test ...` node exists |
| `/maktabs/MAKTAB-001/attendance/{studentId}_{date}` | attendance record node exists |

Report each as **EXISTS** / **MISSING** / **WRONG VALUE** with the actual value seen.

> [!IMPORTANT]
> **Rule Scope vs Query Scope**: In Firebase Realtime Database, `.read` rules cascade DOWN, never UP. An app listener or `.get()` query on `/maktabs/$maktabId/students` evaluates security rules at the collection level (`/students`). If `.read` is only defined at the `$studentId` child level, collection queries fail immediately with `[permission-denied]`. Security rules must be defined at the collection level to permit whole-collection queries.

---

## What to Paste to the AI

Paste all four blocks in this exact order:

```
=== MANAGER DIAGNOSTIC ===
...

=== MANAGER POST-WRITE DIAGNOSTIC ===
...
Console check: student visible = YES/NO

=== TEACHER DIAGNOSTIC ===
...
Student list: Diag Test visible = YES/NO

=== TEACHER POST-ATTENDANCE DIAGNOSTIC ===
...
Manager attendance visible = YES/NO

=== CONSOLE CROSS-CHECK ===
/users/{manager_uid}: EXISTS | role=... | maktabId=... | active=...
/users/{teacher_uid}: EXISTS | role=... | maktabId=... | active=...
/maktabs/MAKTAB-001/students: student visible = YES/NO
/maktabs/MAKTAB-001/attendance: attendance visible = YES/NO
```

The AI will then select and execute the correct Phase 3 fix branch without re-auditing the code.

---

## Step 5 Addendum — Authentication Session Check

After the two-device test, open **Firebase Console → Authentication → Users** and check the **Last sign-in** column for each email:

| Email | Expected "Last sign-in" |
|-------|------------------------|
| Manager email (e.g. `admin@maktab.app`) | Most recent — should be AFTER teacher's |
| `teacher_MAKTAB-001_2018@maktab.app` | Should be EARLIER than manager's (set during Teacher device login) |
| `teacher_MAKTAB-001_20261@maktab.app` | Same as above |

**Interpretation:**

- If **Manager's last sign-in is older than teacher's** on the same device timeline → session-switch bug (Root Cause C). However, static audit showed provisioning uses a secondary Firebase app correctly, so this should NOT occur.
- If **Manager's last sign-in is most recent** → provisioning is safe. Root Cause C confirmed ruled out.
- If **Teacher email does NOT appear at all** in Authentication Users → provisioning never ran; teacher cannot authenticate to Firebase; sync will fail.

> This check takes 30 seconds and definitively confirms whether teacher Firebase Auth accounts exist and were signed into.
