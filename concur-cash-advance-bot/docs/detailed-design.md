# Detailed Design — Concur Cash Advance Auto-Submit Bot

**Status:** Phase 4 — in progress. Confirming one phase at a time.
**Platform:** Power Automate Desktop (primary), UiPath (fallback).

---

## Phase 1 of 6: Initialize & Load Settings

**Section name (flow comment):** `>> SECTION: Initialize & Load Settings`

### Step-by-Step Actions

```
Step 1.1: Read Config Values
  Action: Set variable (x7, one per config value — see table below)
  Display name: "Set Config - <Name>"
  Notes: In v1, config values are hardcoded as flow variables at the top of
         the flow inside this section, grouped together as the "config block".
         This keeps them easy to relocate into a settings file/UiPath
         Config.xlsx later without restructuring the flow.

  Variables set here:
    ConcurBaseUrl      (Text)    e.g. "https://www.concursolutions.com"
    CredentialFilePath (Text)    e.g. "C:\Bots\Concur\credentials.txt"
    ExportFolderPath   (Text)    e.g. "C:\Bots\Concur\Exports"
    LogFolderPath      (Text)    e.g. "C:\Bots\Concur\Logs"
    MaxRetry           (Number)  3
    TimeoutSeconds     (Number)  30
    RetryDelaySeconds  (Number)  3

Step 1.2: Get Current Date and Time
  Action: Get current date and time
  Display name: "Get Run Start Time"
  Output: RunStartDateTime (DateTime)

Step 1.3: Format Run Timestamp
  Action: Convert datetime to text
  Display name: "Format Run Timestamp"
  Input: RunStartDateTime
  Format: Custom → yyyyMMdd_HHmmss
  Output: RunTimestamp (Text)

Step 1.4: Format Log Date
  Action: Convert datetime to text
  Display name: "Format Log Date"
  Input: RunStartDateTime
  Format: Custom → yyyyMMdd
  Output: LogDateText (Text)

Step 1.5: Build Log File Path
  Action: Set variable
  Display name: "Build Log File Path"
  Value: LogFolderPath + "\ConcurLog_" + LogDateText + ".xlsx"
  Output: LogFilePath (Text)

Step 1.6: Build Export File Path
  Action: Set variable
  Display name: "Build Export File Path"
  Value: ExportFolderPath + "\PendingExport_" + RunTimestamp + ".xlsx"
  Output: ExportFilePath (Text)

Step 1.7: Check If Log File Exists
  Action: Check if file exists
  Display name: "Check Log File Exists"
  Input: LogFilePath
  Output: LogFileExists (Boolean)

Step 1.8: Create Log File (conditional)
  Action: If → LogFileExists = False
    Then:
      Action: Launch Excel
        Display name: "Launch Excel - New Log"
        Document path: (blank / new workbook)
        Output: ExcelLogInstance
      Action: Write to Excel worksheet
        Display name: "Write Log Header Row"
        Cell: A1
        Values: ["Timestamp", "RunID", "UserID", "RequestID", "Outcome", "Reason"]
      Action: Save Excel
        Display name: "Save New Log File"
        Save as: LogFilePath
      Action: Close Excel
        Display name: "Close Log After Create"
    Else:
      (no action — file already exists, will be opened fresh in Step 1.9)
  End

Step 1.9: Launch Excel with Log File
  Action: Launch Excel
  Display name: "Launch Excel - Open Log"
  Document path: LogFilePath
  Output: ExcelLogInstance

Step 1.10: Read Credential File
  Action: Read from file (or "Read text from file")
  Display name: "Read Credential File"
  File: CredentialFilePath
  Output: AdminPassword (Text, marked sensitive — do not log)
  Notes: File contains only the admin password (or "user:pass" if the
         username also needs externalizing later). Value is never written
         to the log or printed to flow variables pane if avoidable —
         use the "Sensitive" data type toggle in PA Desktop.

Step 1.11: Launch Browser
  Action: Launch new Microsoft Edge (or Chrome)
  Display name: "Launch Browser at Concur Login"
  Initial URL: ConcurBaseUrl
  Launch mode: Maximized, new instance, clear browsing data on close: No
    (avoid clearing shared profile data on a shared bot machine)
  Timeout: TimeoutSeconds
  Output: Browser (Browser instance)

Step 1.12: Verify Page Loaded
  Action: Wait for web page content / element
  Display name: "Wait for Login Page Element"
  Target: username input field (or page title contains "Sign In")
  Timeout: TimeoutSeconds
  Output: LoginPageLoaded (Boolean, via "On error" branch — see below)
```

### Error Handling (this section)

```
Wrap Steps 1.10–1.12 in an "On block error" error handler:
  On error in Step 1.10 (credential file read):
    Action: Write to Excel worksheet — append Fatal row to LogFilePath
      Timestamp, RunID=RunTimestamp, UserID="", RequestID="",
      Outcome="Fatal", Reason="Credential file missing or unreadable"
    Action: Close Excel (save)
    Action: Terminate flow (stop run)

  On error in Steps 1.11–1.12 (browser/page load):
    Action: Increment RetryCount
    If RetryCount < MaxRetry:
      Action: Wait (RetryDelaySeconds)
      Go to Step 1.11 (retry launch)
    Else:
      Action: Write Fatal row to log (Reason="Browser/login page failed to load after retries")
      Action: Close browser if open
      Action: Close Excel (save)
      Action: Terminate flow
```

### Variables Declared in This Section

| Variable | Type | Scope | Default / Source |
|---|---|---|---|
| `ConcurBaseUrl` | Text | Flow | Hardcoded config (Step 1.1) |
| `CredentialFilePath` | Text | Flow | Hardcoded config (Step 1.1) |
| `ExportFolderPath` | Text | Flow | Hardcoded config (Step 1.1) |
| `LogFolderPath` | Text | Flow | Hardcoded config (Step 1.1) |
| `MaxRetry` | Number | Flow | 3 |
| `TimeoutSeconds` | Number | Flow | 30 |
| `RetryDelaySeconds` | Number | Flow | 3 |
| `RunStartDateTime` | DateTime | Flow | Step 1.2 |
| `RunTimestamp` | Text | Flow | Step 1.3 |
| `LogDateText` | Text | Flow | Step 1.4 |
| `LogFilePath` | Text | Flow | Step 1.5 |
| `ExportFilePath` | Text | Flow | Step 1.6 |
| `LogFileExists` | Boolean | Flow | Step 1.7 |
| `ExcelLogInstance` | Excel instance | Flow | Step 1.9 |
| `AdminPassword` | Text (Sensitive) | Flow | Step 1.10 |
| `Browser` | Browser instance | Flow | Step 1.11 |
| `RetryCount` | Number | Flow | Initialized to 0 before Step 1.11, used only in error handler |

### Notes for Implementation
- The log file is opened in Excel and **kept open for the duration of the run** (not reopened per write) so subsequent phases can append rows quickly. It is only saved/closed in Phase 6.
- `AdminUser` was in the original medium-level design's config table but is **deferred to Phase 2's detailed design**, since the login mechanism (SSO vs magic link) will determine whether a username variable is even needed here.
- File paths assume a Windows bot machine with local folders; no network share behavior has been designed yet — flag if `ExportFolderPath` / `LogFolderPath` will live on a network drive, as that changes error handling (network drops need extra retry handling).
