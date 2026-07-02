# Detailed Design — Concur Cash Advance Auto-Submit Bot

**Status:** Phase 4 — in progress. Confirming one phase at a time.
**Platform:** Power Automate Desktop (primary), UiPath (fallback).

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
| Write to Excel worksheet | Write Log Header Row | Cell: `A1` · Values: `["Timestamp", "RunID", "UserID", "RequestID", "Outcome", "Reason"]` | — |
| Save Excel | Save New Log File | Save as: `LogFilePath` | — |
| Close Excel | Close Log After Create | — | — |

`Else:` no action — file already exists, opened fresh in Step 1.9.

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

**On error in Step 1.10 (credential file read) — fatal, no retry:**

| Action | Display Name | Properties |
|---|---|---|
| Write to Excel worksheet | Log Fatal - Credential Read Failed | Append row: Timestamp, RunID=`RunTimestamp`, UserID="", RequestID="", Outcome="Fatal", Reason="Credential file missing or unreadable" |
| Close Excel | Save and Close Log | Save: Yes |
| Terminate flow | Stop Run - Fatal Error | — |

**On error in Steps 1.11–1.12 (browser/page load) — retry then fatal:**

| Action | Display Name | Properties |
|---|---|---|
| Increment variable | Increment Retry Count | `RetryCount + 1` |
| If | Check Retry Count | `RetryCount < MaxRetry` |
| → Then: Wait | Wait Before Retry | Duration: `RetryDelaySeconds` |
| → Then: Go to | Retry Browser Launch | Go to Step 1.11 |
| → Else: Write to Excel worksheet | Log Fatal - Browser Launch Failed | Reason="Browser/login page failed to load after retries" |
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
