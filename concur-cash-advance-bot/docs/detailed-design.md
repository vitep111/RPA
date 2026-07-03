# Detailed Design — Concur Cash Advance Auto-Submit Bot

**Status:** Phase 4 — in progress. Confirming one phase at a time.
**Platform:** Power Automate Desktop (primary), UiPath (fallback).

---

## PA Desktop Syntax Conventions (read first)

These conventions apply to **every** step table in this document. They reflect how Power Automate Desktop actually parses fields — different from UiPath/VB.NET.

| Concept | PA Desktop (correct) | NOT (UiPath/VB.NET style) |
|---|---|---|
| Reference a variable in a field | `%MyVar%` | `MyVar` |
| Literal text in a value field | `Hello World` (no quotes) | `"Hello World"` |
| Build a path/string with variables | `%FolderPath%\File_%Stamp%.xlsx` | `FolderPath + "\File_" + Stamp + ".xlsx"` |
| Set a **Number** variable | `%3%` (the `%%` forces numeric evaluation) | `3` (this becomes text "3") |
| Expression / calculation | wrap in `%...%`, e.g. `%RetryCount + 1%` | bare `RetryCount + 1` |
| `If` condition | First operand `%RetryCount%` · Operator `Less than` · Second operand `%MaxRetry%` | `RetryCount < MaxRetry` in one box |

**Subflows have NO parameters.** In PA Desktop, all variables are **global** across the main flow and every subflow — there is no local scope or argument passing. To "pass" data to a subflow, the caller **sets global variables first**, then runs the subflow, which reads those globals. This is the single biggest difference from UiPath's invoked workflows and it shapes how `WriteLogRow` (below) is called everywhere.

---

## Shared Subflow: `WriteLogRow`

Appends one row to the rolling daily Excel log. Built once, called everywhere.

**Reads these global variables (caller must set them before calling):**

| Global variable | Meaning |
|---|---|
| `LogUserID` | User being processed (empty for run-level rows) |
| `LogRequestID` | Request ID/Name (empty for run-level rows) |
| `LogOutcome` | "Submitted" / "Skipped" / "Failed" / "Fatal" / "No items" / "Run Summary" |
| `LogReason` | Human-readable detail |
| `RunTimestamp` | Set once in Phase 1; used as the RunID column |
| `ExcelLogInstance` | The open Excel log instance |

**Subflow steps:**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Get current date and time | Get Row Timestamp | — | `RowTimestamp` (DateTime) |
| Convert datetime to text | Format Row Timestamp | Input: `%RowTimestamp%` · Format: `yyyy-MM-dd HH:mm:ss` | `RowTimestampText` (Text) |
| Get first free column/row from Excel worksheet | Find Next Empty Row | Instance: `%ExcelLogInstance%` | `FirstFreeRow` (Number) |
| Write to Excel worksheet | Write Row - Timestamp | Column: `1` · Row: `%FirstFreeRow%` · Value: `%RowTimestampText%` | — |
| Write to Excel worksheet | Write Row - RunID | Column: `2` · Row: `%FirstFreeRow%` · Value: `%RunTimestamp%` | — |
| Write to Excel worksheet | Write Row - UserID | Column: `3` · Row: `%FirstFreeRow%` · Value: `%LogUserID%` | — |
| Write to Excel worksheet | Write Row - RequestID | Column: `4` · Row: `%FirstFreeRow%` · Value: `%LogRequestID%` | — |
| Write to Excel worksheet | Write Row - Outcome | Column: `5` · Row: `%FirstFreeRow%` · Value: `%LogOutcome%` | — |
| Write to Excel worksheet | Write Row - Reason | Column: `6` · Row: `%FirstFreeRow%` · Value: `%LogReason%` | — |

> **Why single-cell writes:** "Write to Excel worksheet" writes to **one cell**. Passing a list to a single cell writes its text form (`["Timestamp", ...]`) into that one cell rather than spreading across columns. Each column is written individually.
>
> **Caller pattern:** every call site does — `Set variable LogUserID` → `Set variable LogRequestID` → `Set variable LogOutcome` → `Set variable LogReason` → `Run subflow WriteLogRow`.
>
> **UiPath portability note:** UiPath forbids Invoke Workflow, so there this becomes a reusable **named Sequence** inlined in Main, and the globals become normal UiPath variables passed by scope. Logic is identical.

---

## Phase 1 of 6: Initialize & Load Settings

**Section name (flow comment):** `>> SECTION: Initialize & Load Settings`

### Step-by-Step Actions

Each action is one row: **Action** = PA Desktop action type · **Display Name** = label shown in the flow · **Properties** = field inputs (following the conventions above) · **Output** = variable produced.

---

**Step 1.1 — Set Config Values** *(7 actions, one per value)*

| Action | Display Name | Properties (value typed into field) | Output |
|---|---|---|---|
| Set variable | Set Config - Concur Base URL | `https://www.concursolutions.com` | `ConcurBaseUrl` (Text) |
| Set variable | Set Config - Credential File Path | `C:\Bots\Concur\credentials.txt` | `CredentialFilePath` (Text) |
| Set variable | Set Config - Export Folder Path | `C:\Bots\Concur\Exports` | `ExportFolderPath` (Text) |
| Set variable | Set Config - Log Folder Path | `C:\Bots\Concur\Logs` | `LogFolderPath` (Text) |
| Set variable | Set Config - Max Retry | `%3%` | `MaxRetry` (Number) |
| Set variable | Set Config - Timeout Seconds | `%30%` | `TimeoutSeconds` (Number) |
| Set variable | Set Config - Retry Delay Seconds | `%3%` | `RetryDelaySeconds` (Number) |

> **Note:** Config values are hardcoded as flow variables grouped at the top of the flow (the "config block"), so they can be relocated into a settings file / UiPath `Config.xlsx` later without restructuring the flow.

---

**Step 1.2 — Get Run Start Time**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Get current date and time | Get Run Start Time | — | `RunStartDateTime` (DateTime) |

---

**Step 1.3 — Format Run Timestamp**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Convert datetime to text | Format Run Timestamp | Input: `%RunStartDateTime%` · Format: Custom `yyyyMMdd_HHmmss` | `RunTimestamp` (Text) |

---

**Step 1.4 — Format Log Date**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Convert datetime to text | Format Log Date | Input: `%RunStartDateTime%` · Format: Custom `yyyyMMdd` | `LogDateText` (Text) |

---

**Step 1.5 — Build Log File Path**

| Action | Display Name | Properties (value typed into field) | Output |
|---|---|---|---|
| Set variable | Build Log File Path | `%LogFolderPath%\ConcurLog_%LogDateText%.xlsx` | `LogFilePath` (Text) |

---

**Step 1.6 — Build Export File Path**

| Action | Display Name | Properties (value typed into field) | Output |
|---|---|---|---|
| Set variable | Build Export File Path | `%ExportFolderPath%\PendingExport_%RunTimestamp%.xlsx` | `ExportFilePath` (Text) |

---

**Step 1.7 — Check Log File Exists**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| If file exists | Check Log File Exists | File path: `%LogFilePath%` | (branch — see Step 1.8) |

> PA Desktop's file check is the **"If file exists"** action (a conditional block), not a boolean-returning action. Step 1.8 nests inside its "if file does NOT exist" form.

---

**Step 1.8 — Create Log File (conditional)**

Use **"If file exists"** with condition *"if file does not exist"* → `%LogFilePath%`, containing:

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch Excel | Launch Excel - New Log | Document: blank/new workbook · Visible: No | `ExcelLogInstance` |
| Write to Excel worksheet | Write Log Header - Timestamp | Column: `1` · Row: `1` · Value: `Timestamp` | — |
| Write to Excel worksheet | Write Log Header - RunID | Column: `2` · Row: `1` · Value: `RunID` | — |
| Write to Excel worksheet | Write Log Header - UserID | Column: `3` · Row: `1` · Value: `UserID` | — |
| Write to Excel worksheet | Write Log Header - RequestID | Column: `4` · Row: `1` · Value: `RequestID` | — |
| Write to Excel worksheet | Write Log Header - Outcome | Column: `5` · Row: `1` · Value: `Outcome` | — |
| Write to Excel worksheet | Write Log Header - Reason | Column: `6` · Row: `1` · Value: `Reason` | — |
| Close Excel | Close Log After Create | Save mode: Save document as → `%LogFilePath%` | — |

> Header values are typed as plain literals (no quotes). The file is created and closed here; Step 1.9 reopens it for the run.

---

**Step 1.9 — Launch Excel with Log File**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch Excel | Launch Excel - Open Log | Open document: `%LogFilePath%` · Visible: No | `ExcelLogInstance` |

---

**Step 1.10 — Read Credential File**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Read text from file | Read Credential File | File path: `%CredentialFilePath%` · Store as: Single text value | `AdminPassword` (Text, **Sensitive** — never logged) |

> File contains only the admin password (or `user:pass` if the username also needs externalizing later). Use PA Desktop's "Sensitive" toggle so the value never appears in the variables pane or logs.

---

**Step 1.11 — Launch Browser**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch new Microsoft Edge (or Chrome) | Launch Browser at Concur Login | Initial URL: `%ConcurBaseUrl%` · Window state: Maximized · Clear cache/cookies: No · Timeout: `%TimeoutSeconds%` | `Browser` (Browser instance) |

> Clear-cache/cookies set to **No** to avoid wiping shared profile data on a shared bot machine.

---

**Step 1.12 — Verify Login Page Loaded**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Wait for web page content (element appears) | Wait for Login Page Element | UI element: username input field · Timeout: `%TimeoutSeconds%` | Flow continues on success; timeout raises an error → handler below |

### Error Handling (this section)

Steps 1.10–1.12 sit inside an **"On block error"** handler. Both branches set the `Log*` globals, then call `WriteLogRow` (per the caller pattern).

**On error in Step 1.10 (credential file read) — fatal, no retry:**

| Action | Display Name | Properties |
|---|---|---|
| Set variable | Set Log Fields - Credential Fail | `LogUserID` = (empty) · `LogRequestID` = (empty) · `LogOutcome` = `Fatal` · `LogReason` = `Credential file missing or unreadable` |
| Run subflow | Log Fatal - Credential Read Failed | Run subflow `WriteLogRow` |
| Close Excel | Save and Close Log | Save mode: Save document |
| Stop flow | Stop Run - Fatal Error | (ends the run) |

**On error in Steps 1.11–1.12 (browser/page load) — retry then fatal:**

| Action | Display Name | Properties |
|---|---|---|
| Increment variable | Increment Retry Count | Variable: `%RetryCount%` · Increment by: `1` |
| If | Check Retry Count | First operand: `%RetryCount%` · Operator: `Less than or equal to` · Second operand: `%MaxRetry%` |
| → Then: Wait | Wait Before Retry | Duration (seconds): `%RetryDelaySeconds%` |
| → Then: Go to | Retry Browser Launch | Label at Step 1.11 |
| → Else: Set variable | Set Log Fields - Browser Fail | `LogOutcome` = `Fatal` · `LogReason` = `Browser/login page failed to load after retries` |
| → Else: Run subflow | Log Fatal - Browser Launch Failed | Run subflow `WriteLogRow` |
| → Else: Close browser | Close Browser if Open | Instance: `%Browser%` |
| → Else: Close Excel | Save and Close Log | Save mode: Save document |
| → Else: Stop flow | Stop Run - Fatal Error | (ends the run) |

### Variables Declared / Used in This Section

| Variable | Type | Scope | Default / Source |
|---|---|---|---|
| `ConcurBaseUrl` | Text | Global | Config (Step 1.1) |
| `CredentialFilePath` | Text | Global | Config (Step 1.1) |
| `ExportFolderPath` | Text | Global | Config (Step 1.1) |
| `LogFolderPath` | Text | Global | Config (Step 1.1) |
| `MaxRetry` | Number | Global | `%3%` |
| `TimeoutSeconds` | Number | Global | `%30%` |
| `RetryDelaySeconds` | Number | Global | `%3%` |
| `RunStartDateTime` | DateTime | Global | Step 1.2 |
| `RunTimestamp` | Text | Global | Step 1.3 |
| `LogDateText` | Text | Global | Step 1.4 |
| `LogFilePath` | Text | Global | Step 1.5 |
| `ExportFilePath` | Text | Global | Step 1.6 |
| `ExcelLogInstance` | Excel instance | Global | Step 1.8 / reopened 1.9 |
| `AdminPassword` | Text (Sensitive) | Global | Step 1.10 |
| `Browser` | Browser instance | Global | Step 1.11 |
| `RetryCount` | Number | Global | Init `%0%` before Step 1.11; used in error handler |
| `LogUserID` / `LogRequestID` / `LogOutcome` / `LogReason` | Text | Global | Set by callers of `WriteLogRow` |

### Notes for Implementation
- The log file is opened once (Step 1.9) and **kept open for the whole run**; only saved/closed in Phase 6. (In an error abort it's saved/closed in the handler.)
- `AdminUser` is **deferred to Phase 2's detailed design** — the login mechanism (SSO vs magic link) decides whether a username variable is needed.
- File paths assume a Windows bot machine with **local** folders. If `ExportFolderPath` / `LogFolderPath` live on a **network drive**, flag it — network drops need extra retry handling.
