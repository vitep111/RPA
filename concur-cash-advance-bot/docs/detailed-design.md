# Detailed Design — Concur Cash Advance Auto-Submit Bot

**Status:** Phase 4 — in progress. Confirming one phase at a time.
**Platform:** Power Automate Desktop (primary), UiPath (fallback).

---

## Shared Subflow: `WriteLogRow`

Used by every phase to append one row to the rolling daily Excel log. Built once, called everywhere, so the 6-column write logic (see note below) only needs to be correct in one place.

**Parameters (input):** `UserID` (Text), `RequestID` (Text), `Outcome` (Text), `Reason` (Text)
**Uses flow-level variables:** `RunTimestamp` (for RunID column), `ExcelLogInstance`

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Get current date and time | Get Row Timestamp | — | `RowTimestamp` (DateTime) |
| Convert datetime to text | Format Row Timestamp | Format: `yyyy-MM-dd HH:mm:ss` | `RowTimestampText` (Text) |
| Get first free row/column on Excel worksheet | Find Next Empty Row | Instance: `ExcelLogInstance` | `NextRow` (Number) |
| Write to Excel worksheet | Write Row - Timestamp | Column: `1` · Row: `NextRow` · Value: `RowTimestampText` | — |
| Write to Excel worksheet | Write Row - RunID | Column: `2` · Row: `NextRow` · Value: `RunTimestamp` | — |
| Write to Excel worksheet | Write Row - UserID | Column: `3` · Row: `NextRow` · Value: `UserID` | — |
| Write to Excel worksheet | Write Row - RequestID | Column: `4` · Row: `NextRow` · Value: `RequestID` | — |
| Write to Excel worksheet | Write Row - Outcome | Column: `5` · Row: `NextRow` · Value: `Outcome` | — |
| Write to Excel worksheet | Write Row - Reason | Column: `6` · Row: `NextRow` · Value: `Reason` | — |

> **Why single-cell writes:** PA Desktop's "Write to Excel worksheet" action writes to **one cell**. Passing a list/array value writes its text representation (e.g. `["Timestamp", "RunID", ...]`) into that single cell rather than spreading it across columns — a mistake caught during design review. Each column is written individually instead.
>
> **UiPath portability note:** In PA Desktop this is a **Subflow** — a distinct callable unit, which PA Desktop supports natively with no restriction. If the platform switches to UiPath, per the platform's hard constraint of **no Invoke Workflow / everything in Main.xaml**, this would instead become a reusable **named Sequence** inlined within Main (called only via placement, not invocation) — the 9-step logic stays identical, only the container mechanism changes.

---

## Phase 1 of 6: Initialize & Load Settings

**Section name (flow comment):** `>> SECTION: Initialize & Load Settings`

### Step-by-Step Actions

Each action is one row: **Action** is the PA Desktop action type, **Display Name** is what shows in the flow, **Properties** are the inputs/settings, **Output** is the variable produced.

---

**Step 1.1 — Set Config Values** *(7 actions, one per value)*

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Set Config - Concur Base URL | Value: `"https://www.concursolutions.com"` | `ConcurBaseUrl` (Text) |
| Set variable | Set Config - Credential File Path | Value: `"C:\Bots\Concur\credentials.txt"` | `CredentialFilePath` (Text) |
| Set variable | Set Config - Export Folder Path | Value: `"C:\Bots\Concur\Exports"` | `ExportFolderPath` (Text) |
| Set variable | Set Config - Log Folder Path | Value: `"C:\Bots\Concur\Logs"` | `LogFolderPath` (Text) |
| Set variable | Set Config - Max Retry | Value: `3` | `MaxRetry` (Number) |
| Set variable | Set Config - Timeout Seconds | Value: `30` | `TimeoutSeconds` (Number) |
| Set variable | Set Config - Retry Delay Seconds | Value: `3` | `RetryDelaySeconds` (Number) |

> **Note:** In v1, config values are hardcoded as flow variables at the top of the flow, grouped together as one "config block." Kept isolated here so it can be relocated into a settings file / UiPath `Config.xlsx` later without restructuring the flow.

---

**Step 1.2 — Get Run Start Time**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Get current date and time | Get Run Start Time | — | `RunStartDateTime` (DateTime) |

---

**Step 1.3 — Format Run Timestamp**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Convert datetime to text | Format Run Timestamp | Input: `RunStartDateTime` · Format: Custom `yyyyMMdd_HHmmss` | `RunTimestamp` (Text) |

---

**Step 1.4 — Format Log Date**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Convert datetime to text | Format Log Date | Input: `RunStartDateTime` · Format: Custom `yyyyMMdd` | `LogDateText` (Text) |

---

**Step 1.5 — Build Log File Path**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Build Log File Path | Value: `LogFolderPath + "\ConcurLog_" + LogDateText + ".xlsx"` | `LogFilePath` (Text) |

---

**Step 1.6 — Build Export File Path**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Build Export File Path | Value: `ExportFolderPath + "\PendingExport_" + RunTimestamp + ".xlsx"` | `ExportFilePath` (Text) |

---

**Step 1.7 — Check Log File Exists**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Check if file exists | Check Log File Exists | Input: `LogFilePath` | `LogFileExists` (Boolean) |

---

**Step 1.8 — Create Log File (conditional)**

`If LogFileExists = False:`

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch Excel | Launch Excel - New Log | Document: blank/new workbook | `ExcelLogInstance` |
| Write to Excel worksheet | Write Log Header - Timestamp | Column: `1` · Row: `1` · Value: `"Timestamp"` | — |
| Write to Excel worksheet | Write Log Header - RunID | Column: `2` · Row: `1` · Value: `"RunID"` | — |
| Write to Excel worksheet | Write Log Header - UserID | Column: `3` · Row: `1` · Value: `"UserID"` | — |
| Write to Excel worksheet | Write Log Header - RequestID | Column: `4` · Row: `1` · Value: `"RequestID"` | — |
| Write to Excel worksheet | Write Log Header - Outcome | Column: `5` · Row: `1` · Value: `"Outcome"` | — |
| Write to Excel worksheet | Write Log Header - Reason | Column: `6` · Row: `1` · Value: `"Reason"` | — |
| Save Excel | Save New Log File | Save as: `LogFilePath` | — |
| Close Excel | Close Log After Create | — | — |

`Else:` no action — file already exists, opened fresh in Step 1.9.

> **Note (correction):** "Write to Excel worksheet" writes to a **single cell**. Passing a list to one cell (e.g., `A1`) writes its text representation (`["Timestamp", "RunID", ...]`) into that cell rather than spreading values across columns — this was an error in the original design. Each header is written to its own cell using Column/Row coordinates instead, one action per header.

---

**Step 1.9 — Launch Excel with Log File**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch Excel | Launch Excel - Open Log | Document path: `LogFilePath` | `ExcelLogInstance` |

---

**Step 1.10 — Read Credential File**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Read text from file | Read Credential File | File: `CredentialFilePath` | `AdminPassword` (Text, **Sensitive** — never logged) |

> **Note:** File contains only the admin password (or `user:pass` if the username also needs externalizing later). Use PA Desktop's "Sensitive" data type toggle so the value never appears in the flow variables pane or logs.

---

**Step 1.11 — Launch Browser**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch new Microsoft Edge (or Chrome) | Launch Browser at Concur Login | Initial URL: `ConcurBaseUrl` · Mode: Maximized, new instance · Clear browsing data on close: No · Timeout: `TimeoutSeconds` | `Browser` (Browser instance) |

> Clear-browsing-data is set to **No** to avoid wiping shared profile data on a shared bot machine.

---

**Step 1.12 — Verify Login Page Loaded**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Wait for web page content / element | Wait for Login Page Element | Target: username input field (or page title contains "Sign In") · Timeout: `TimeoutSeconds` | Flow continues on success; failure routes to error handler below |

### Error Handling (this section)

Steps 1.10–1.12 are wrapped in an **"On block error"** error handler.

> **Reusable pattern — "Write Log Row" subflow:** Since every log entry (fatal or per-item, used throughout this design) writes the same 6 columns, it's built once as a PA Desktop **Subflow** called `WriteLogRow`, taking 5 input parameters (`UserID`, `RequestID`, `Outcome`, `Reason` — `Timestamp` and `RunID` are read from flow-level variables) and writing one row using 6 single-cell "Write to Excel worksheet" actions (one per column, at the next empty row) — same technique as the header row in Step 1.8. All later phases call this subflow instead of repeating 6 write actions inline.

**On error in Step 1.10 (credential file read) — fatal, no retry:**

| Action | Display Name | Properties |
|---|---|---|
| Run subflow | Log Fatal - Credential Read Failed | Call `WriteLogRow` — UserID="", RequestID="", Outcome="Fatal", Reason="Credential file missing or unreadable" |
| Close Excel | Save and Close Log | Save: Yes |
| Terminate flow | Stop Run - Fatal Error | — |

**On error in Steps 1.11–1.12 (browser/page load) — retry then fatal:**

| Action | Display Name | Properties |
|---|---|---|
| Increment variable | Increment Retry Count | `RetryCount + 1` |
| If | Check Retry Count | `RetryCount < MaxRetry` |
| → Then: Wait | Wait Before Retry | Duration: `RetryDelaySeconds` |
| → Then: Go to | Retry Browser Launch | Go to Step 1.11 |
| → Else: Run subflow | Log Fatal - Browser Launch Failed | Call `WriteLogRow` — Reason="Browser/login page failed to load after retries" |
| → Else: Close browser | Close Browser if Open | — |
| → Else: Close Excel | Save and Close Log | Save: Yes |
| → Else: Terminate flow | Stop Run - Fatal Error | — |

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
