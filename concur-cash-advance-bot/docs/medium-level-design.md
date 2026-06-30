# Medium-Level Design — Concur Cash Advance Auto-Submit Bot

**Status:** Phase 3 — in progress. Confirming one phase at a time.
**Platform:** Power Automate Desktop (primary), UiPath (fallback).

---

## Phase 1 of 6: Initialize & Load Settings

### Purpose & Scope
Prepare everything the run needs before touching Concur: load settings and credentials, set up the Excel run-log for this execution, and launch a clean browser session. If this phase fails, nothing else can run — so failures here are fatal (abort the run).

### Key Steps (logical)
1. **Read settings** — load the config values the bot needs (see variables below). In PA Desktop these come from flat variables / a small settings file; kept as one "config" group so it maps to a UiPath Config.xlsx later.
2. **Resolve run paths** — build the export file path and the run-log file path (with a date/time stamp so runs don't overwrite each other).
3. **Prepare the run log** — create or open the Excel log and ensure the header row exists (Timestamp, User ID, Request ID, Outcome, Reason).
4. **Launch browser** — open a fresh browser instance at the Concur login URL, maximized, with no leftover session/tabs.

### Variables & Data Structures

**Config group (the "settings"):**

| Variable | Type | Example / Notes |
|---|---|---|
| `ConcurBaseUrl` | Text | Login URL of the Concur web app |
| `AdminUser` | Text | Admin account username |
| `AdminPassword` | Text | Admin password (held as sensitive var, never logged) |
| `ExportFolderPath` | Text | Where Concur's Excel export lands |
| `LogFolderPath` | Text | Where the run log is written |
| `MaxRetry` | Number | Retry count for transient web failures (e.g., 3) |
| `TimeoutSeconds` | Number | Default wait for web elements (e.g., 30) |

**Run-state variables initialized here:**

| Variable | Type | Notes |
|---|---|---|
| `RunTimestamp` | Text | e.g., `yyyyMMdd_HHmmss`, used in file names |
| `LogFilePath` | Text | Resolved full path to this run's log |
| `Browser` | Browser handle | The launched browser instance |

### Error Handling
- Settings missing/empty (blank URL or credentials) → **fatal**: write a "config error" line to the log if possible, then stop the run.
- Browser fails to launch or the login page doesn't load → **retry up to `MaxRetry`**, then **fatal abort** with a logged error.
- All failures here go down the Phase 5 "Abort and Log Fatal Error" path — we never proceed to login with a broken setup.

### Decisions (confirmed)
1. **Credential storage:** external credential file (path stored in config; file read at startup, never logged).
2. **Log file style:** rolling daily file — one file per calendar day, each hourly run appends rows to it. File named e.g. `ConcurLog_20260630.xlsx`. Suits the daily email summary phase.

### Internal Flow

```mermaid
graph TD
    A[Start] --> B[Read Settings into Config group]
    B --> C{Settings valid?}
    C -->|No| F[Log Fatal Config Error] --> Z[Abort Run]
    C -->|Yes| D[Resolve Export and Log file paths]
    D --> E[Prepare Run Log header]
    E --> G[Launch Browser at Concur URL]
    G --> H{Browser and page loaded?}
    H -->|No| R{Retries left?}
    R -->|Yes| G
    R -->|No| F
    H -->|Yes| Y[Phase 1 complete — proceed to Login]
```

---

## Phase 2 of 6: Login to Concur

### Purpose & Scope
Authenticate the admin account in the browser and land on the Concur home/dashboard. A failed login is fatal — the bot cannot impersonate any user if it isn't logged in. Retries cover transient page-load issues; a true credential failure should abort immediately (no point retrying bad credentials).

### Key Steps (logical)
1. **Navigate to login page** — go to `ConcurBaseUrl` if not already there.
2. **Enter username** — type `AdminUser` into the username field and click Next (or press Enter) to proceed to page 2.
3. **Wait for password page** — confirm the password field appears before typing.
4. **Enter password** — read the password from the external credential file and type into the password field.
5. **Click Sign In** — submit the password form.
6. **Verify login success** — wait for the home/dashboard element to appear (e.g., the top navigation or user avatar). If it doesn't appear within `TimeoutSeconds`, treat as login failure.
7. **Confirm no MFA/SSO redirect** — if an unexpected page appears (not the dashboard), abort with a descriptive error.

### Variables introduced
| Variable | Type | Notes |
|---|---|---|
| `AdminPassword` | Text (sensitive) | Read from external credential file; never logged |
| `LoginSuccess` | Boolean | Set `true` once dashboard confirmed |

### Error Handling
- Credential file not found or unreadable → **fatal abort** (logged).
- Username/password field not found (page didn't load) → **retry up to `MaxRetry`**, then fatal abort.
- Dashboard element never appears after submit → **retry login sequence**, then fatal abort. Do not retry indefinitely on a bad password.
- Unexpected redirect (MFA, SSO, error page) → **fatal abort** with page URL logged so it's diagnosable.

### Internal Flow

```mermaid
graph TD
    A[Phase 2 Start] --> B[Read Password from Credential File]
    B --> C{File readable?}
    C -->|No| FATAL[Log Fatal Error - Abort Run]
    C -->|Yes| D[Navigate to Login Page]
    D --> E[Enter Username - Click Next]
    E --> F{Password page appeared?}
    F -->|No| H{Retries left?}
    H -->|Yes| D
    H -->|No| FATAL
    F -->|Yes| G[Enter Password - Click Sign In]
    G --> I{Dashboard appeared?}
    I -->|No| H2{Retries left?}
    H2 -->|Yes| D
    H2 -->|No| FATAL
    I -->|Yes| K{Expected page - no MFA redirect?}
    K -->|No| FATAL
    K -->|Yes| J[Phase 2 complete — proceed to Get Pending Report]
```

## Phase 3 of 6: Get Pending Report

### Purpose & Scope
Navigate to the admin grid of pending Cash Advance Requests, export it to Excel, read the exported file into a list the loop will iterate over, and decide whether there is any work to do. If the list is empty, the bot exits cleanly without touching any user account.

### Key Steps (logical)
1. **Navigate to the admin pending grid** — go to the Cash Advance Requests section and ensure the view is filtered to pending submission status only.
2. **Trigger the Excel export** — click the export button, wait for the browser download to complete and the file to appear in `ExportFolderPath`.
3. **Verify the export file exists** — confirm the file landed within `TimeoutSeconds`; if not, retry or abort.
4. **Read the export into a list** — open the Excel file and load all data rows into `PendingList` (one record per pending request). Each record carries at minimum: User ID, Request ID/Name.
5. **Check for empty list** — if `PendingCount = 0`, log "No pending items — run complete" and jump directly to Phase 6 (Cleanup), skipping the loop entirely.
6. **Delete or archive the export file** — remove the downloaded export so it doesn't accumulate or interfere with the next run.

### Variables introduced
| Variable | Type | Notes |
|---|---|---|
| `ExportFilePath` | Text | Full path to the downloaded export file |
| `PendingList` | List of records | One entry per pending request (User ID, Request ID/Name) |
| `PendingCount` | Number | Row count of `PendingList`; 0 triggers early exit |
| `CurrentIndex` | Number | Loop counter — initialized here to 0, used in Phase 4 |

### Error Handling
- Admin grid page fails to load → **retry up to `MaxRetry`**, then fatal abort.
- Export button not found or download times out → **retry**, then fatal abort.
- Export file unreadable or has no header row → **fatal abort** with file path logged.
- Empty list (`PendingCount = 0`) → **clean exit** (not an error): log "nothing to process" and proceed to Phase 6.

### Internal Flow

```mermaid
graph TD
    A[Phase 3 Start] --> B[Navigate to Admin Pending Grid]
    B --> C{Grid loaded?}
    C -->|No| R1{Retries left?}
    R1 -->|Yes| B
    R1 -->|No| FATAL[Log Fatal Error - Abort Run]
    C -->|Yes| D[Click Export to Excel]
    D --> E{File downloaded?}
    E -->|No| R2{Retries left?}
    R2 -->|Yes| D
    R2 -->|No| FATAL
    E -->|Yes| F[Read Export into PendingList]
    F --> G{PendingCount = 0?}
    G -->|Yes| H[Log - No Pending Items] --> SKIP[Jump to Phase 6 Cleanup]
    G -->|No| I[Delete Export File]
    I --> J[Phase 3 complete — proceed to Process Loop]
```

## Phase 4 of 6: Process Pending Requests (Loop)
*Pending confirmation of Phase 3.*

## Phase 5 of 6: Exception Handling
*Pending confirmation of Phase 4.*

## Phase 6 of 6: Cleanup & Reporting
*Pending confirmation of Phase 5.*
