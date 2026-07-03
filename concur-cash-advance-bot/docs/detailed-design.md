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

## Flow & Subflow Structure (decision)

**Decision: one Main flow, one real subflow.**

- **`Main`** contains all 6 phases **inline**, in physical top-to-bottom order (Phase 1 → 2 → 3 → 4 → 5 → 6). Each phase is a visually distinct block marked by a comment action reading `>> SECTION: <phase name>` (see each phase's "Section name (flow comment)" line) — a label, not a call. Retries within a phase use in-flow `Go to` + `Label` pairs (e.g., `RetryBrowserLaunch`, `RetryPendingGridNav`), and Phase 3's empty-list branch (Step 3.14) jumps forward to a `Phase6CleanupStart` label in a *different* phase's block. **This cross-phase jump is only legal because every phase lives in one Main flow** — this is *why* the phases live in Main rather than as separate subflows, not merely a style choice: PA Desktop's `Go to`/`Label` are assumed to be scoped to a single flow and unable to jump between a flow and a subflow. **Unverified (see reference 9.1):** confirm this scoping behavior live before relying on it further; if `Go to` somehow can cross flow/subflow boundaries, this section's rationale weakens but the structure itself (one Main, one subflow) still stands on the "no reuse benefit" grounds in the next two bullets.
- **`WriteLogRow`** is the **only** actual subflow (`Run subflow` action). It is called from every phase via the global caller pattern (`Set LogUserID/LogRequestID/LogOutcome/LogReason` → `Run subflow WriteLogRow`) documented above.
- **Phase 4's per-item loop body is also inline in Main**, not its own subflow — iterating by index (`Loop Condition` while `%CurrentIndex%` `Less than` `%PendingCount%`, reading the current row via `%PendingList[CurrentIndex]%` **before** incrementing `CurrentIndex` for the next pass — read-then-increment, so row 0 isn't skipped), consistent with Phase 3 already initializing `CurrentIndex` (Step 3.12) for exactly this purpose — not a `For each`, which would leave `CurrentIndex` unused/dead. **Unverified:** the exact datatable row-indexing syntax (`%PendingList[CurrentIndex]%` assumed) is not yet a confirmed PA Desktop rule — pin it down and add it to `pa-desktop-reference.md` (e.g., rule 7.5) when Phase 4's detailed design is written. Keeping the loop body inline (rather than a `ProcessOneItem` subflow) is deliberate, not an oversight: since subflows carry no parameters, a `ProcessOneItem` subflow would read/write the exact same globals (`CurrentRecord`, `CurrentUserID`, etc.) that an inline loop body would — same global surface, zero encapsulation gained — while adding one `Run subflow` call's overhead per item and one more place to keep the `Log*`/`RetryCount` global-reuse discipline (reference 8.1) straight. Keeping it inline also keeps the "On block error" per-item handler directly attached to the loop body, matching how Phase 1 and Phase 3's retry handlers are structured.

**Why not more subflows in general:** every candidate subflow (Phase 3's grid-navigation, Phase 4's per-item logic, Phase 6's summary tally) would only be called from exactly one call site, so factoring it out buys no reuse — the one thing subflows are for here is exactly what `WriteLogRow` does: one piece of logic called from *many* call sites (every phase, every error branch). If a future phase needs the same non-trivial logic from two or more places, extract a subflow for it then, following `WriteLogRow`'s pattern (read globals in, no return value, caller sets globals first).

**UiPath portability note:** UiPath has no such `Go to`/label restriction and supports real Invoke Workflow with argument passing, so a port would likely split each phase into its own workflow with proper in/out arguments instead of comment-delimited sections in one file — but the *logic* transfers directly; only the file/workflow boundaries change.

---

## Shared Subflow: `WriteLogRow`

Appends one row to the rolling daily Excel log. Built once, called everywhere.

**Reads these global variables (caller must set them before calling):**

| Global variable | Meaning |
|---|---|
| `LogUserID` | User being processed (`N/A` for run-level rows — see note below) |
| `LogRequestID` | Request ID/Name (`N/A` for run-level rows — see note below) |
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
> **Verified in PA Desktop (see reference 1.8 ✅):** `Set variable`'s Value field cannot be left blank — the action errors ("parameter value can't be empty") if you try. So a run-level log row (no specific user/request — Fatal aborts, "No items", "Run Summary") cannot set `LogUserID`/`LogRequestID` to a true empty string; every call site sets them to the literal `N/A` instead. This shows up as the text "N/A" in the User ID / Request ID columns for run-level rows, which is also more explicit for anyone reading the log than a blank cell would be.
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

**Step 1.10b — Validate Config & Credential** *(fatal branch for the medium-level "Settings valid?" node)*

Reading the file can succeed but return an **empty** value; and a config field could be blank. This step catches those before we try to use them.

| Action | Display Name | Properties | Output |
|---|---|---|---|
| If | Check Config Not Empty | `%ConcurBaseUrl%` is empty OR `%CredentialFilePath%` is empty OR `%LogFolderPath%` is empty OR `%ExportFolderPath%` is empty OR `%AdminPassword%` is empty | branch |
| → Then: Set variable | Set Log Fields - Config Invalid | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Config error - a required setting or credential is blank` | — |
| → Then: Run subflow | Log Fatal - Config Invalid | Run subflow `WriteLogRow` | — |
| → Then: Close Excel | Save and Close Log | Save mode: Save document | — |
| → Then: Stop flow | Stop Run - Config Error | (ends the run) | — |

> **Verified in PA Desktop (see reference 4.4 ✅):** the `If` action's built-in condition list supports multiple `is empty` conditions combined by `OR`, added directly in the action UI — no precomputed Boolean needed. An earlier draft of this step tried to precompute the OR into a Boolean via `Set variable` (e.g. `%ConcurBaseUrl = "" OR ...%`); that failed live ("value cannot be empty" on the `Set variable` action) and has been dropped. See Lessons Learned L1 for the corrected rule.
>
> The log is already open (Step 1.9) so a config-error row can be written before aborting — satisfies the PDD requirement that every run leaves at least one log entry.

---

**Step 1.10c — Initialize Retry Count**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Initialize Retry Count | Value: `%0%` | `RetryCount` (Number) |

> Must exist as a real action (not just a note) — the browser-fail error handler increments and compares `%RetryCount%`, which would reference an uninitialized variable without this step.

---

**Step 1.11 — Launch Browser** *(retry target)*

Place a **Label** action named `RetryBrowserLaunch` immediately before this step so the error handler's "Go to" has a concrete target.

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch new Microsoft Edge (or Chrome) | Launch Browser at Concur Login | Initial URL: `%ConcurBaseUrl%` · Window state: Maximized · Clear cache/cookies: No · Timeout: `%TimeoutSeconds%` | `Browser` (Browser instance) |

> Clear-cache/cookies set to **No** to avoid wiping shared profile data on a shared bot machine. **Deviation note:** the medium-level design said "clean session, no leftover session." This is a deliberate reconciliation — preserved cookies may also help a future SSO login. Revisit once Phase 2's login method (SSO vs magic link) is chosen; if a truly clean session is required, flip this to Yes.

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
| Set variable | Set Log Fields - Credential Fail | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Credential file missing or unreadable` |
| Run subflow | Log Fatal - Credential Read Failed | Run subflow `WriteLogRow` |
| Close Excel | Save and Close Log | Save mode: Save document |
| Stop flow | Stop Run - Fatal Error | (ends the run) |

**On error in Steps 1.11–1.12 (browser/page load) — retry then fatal:**

| Action | Display Name | Properties |
|---|---|---|
| Increment variable | Increment Retry Count | Variable: `%RetryCount%` · Increment by: `1` |
| If | Check Retry Count | First operand: `%RetryCount%` · Operator: `Less than or equal to` · Second operand: `%MaxRetry%` |
| → Then: Close browser | Close Failed Browser | Instance: `%Browser%` · On error: continue (best-effort — instance may be unset if launch itself failed) |
| → Then: Wait | Wait Before Retry | Duration (seconds): `%RetryDelaySeconds%` |
| → Then: Go to | Retry Browser Launch | Label: `RetryBrowserLaunch` (placed before Step 1.11) |
| → Else: Set variable | Set Log Fields - Browser Fail | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Browser/login page failed to load after retries` |
| → Else: Run subflow | Log Fatal - Browser Launch Failed | Run subflow `WriteLogRow` |
| → Else: Close browser | Close Browser if Open | Instance: `%Browser%` · On error: continue (best-effort — may be unset if launch failed) |
| → Else: Close Excel | Save and Close Log | Save mode: Save document |
| → Else: Stop flow | Stop Run - Fatal Error | (ends the run) |

> **Retry hygiene:** the failed browser instance is closed at the top of the retry branch so retries don't accumulate orphaned Edge/Chrome processes on a shared bot machine. Both close actions are best-effort (`On error: continue`) because `%Browser%` may be unset when the *launch* itself failed.

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
| `RetryCount` | Number | Global | Init `%0%` in Step 1.10c; incremented in error handler |
| `LogUserID` / `LogRequestID` / `LogOutcome` / `LogReason` | Text | Global | Set by callers of `WriteLogRow` |

### Notes for Implementation
- The log file is opened once (Step 1.9) and **kept open for the whole run**; only saved/closed in Phase 6. (In an error abort it's saved/closed in the handler.)
- `AdminUser` is **deferred to Phase 2's detailed design** — the login mechanism (SSO vs magic link) decides whether a username variable is needed.
- File paths assume a Windows bot machine with **local** folders. If `ExportFolderPath` / `LogFolderPath` live on a **network drive**, flag it — network drops need extra retry handling.

---

## Phase 3 of 6: Get Pending Report

**Section name (flow comment):** `>> SECTION: Get Pending Report`

> **Picks up where Phase 1 left off:** `Browser` is already open. Phase 2 (Login) is blocked/deferred, so this section assumes the browser is already authenticated and landed on the Concur home page when it runs in the full flow. Nothing below depends on *how* login happened.

> **Retry-counter hygiene (see reference 8.1):** `RetryCount` is a single global reused everywhere. Phase 1 may have left it at a nonzero value (if browser launch needed a retry). This section resets it to `%0%` immediately before **each** of its two independent retry targets (Step 3.0 before Step 3.1, and Step 3.4 before Step 3.5) so neither retry block inherits leftover count from anywhere else in the run.

### Step-by-Step Actions

---

**Step 3.0 — Reset Retry Count (Grid Navigation)**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Reset Retry Count - Grid Nav | `%0%` | `RetryCount` (Number) |

---

**Step 3.1 — Navigate to Admin Pending Grid** *(retry target)*

Place a **Label** action named `RetryPendingGridNav` immediately before this step.

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Go to web page | Navigate to Pending Grid | Browser: `%Browser%` · URL: `%ConcurBaseUrl%/cash-advance/admin/pending` | — |

> **Open assumption:** the exact admin-grid URL/navigation path is unconfirmed — placeholder shown. Confirm with a live walkthrough of the Concur admin UI; if the grid is reached via in-app clicks (menu → Cash Advance Admin) rather than a direct URL, replace this with the click sequence.

---

**Step 3.2 — Wait for Pending Grid to Load**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Wait for web page content (element appears) | Wait for Grid Element | UI element: pending-requests grid/table header · Timeout: `%TimeoutSeconds%` | Flow continues on success; timeout raises an error → handler below |

---

**Step 3.3 — Ensure Filter = Pending Submission Status**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set value on web element (assumed dropdown filter) | Set Status Filter - Pending Submission | UI element: status filter dropdown · Value: `Pending Submission` | — |

> **Open assumption:** whether the admin grid defaults to pending-only or needs an explicit filter selection each run is unconfirmed, and so is the exact PA Desktop action for the filter control (dropdown vs. multi-select vs. list). Pin the exact action name once the live Concur admin UI is confirmed; if the grid is always pre-scoped to pending items (e.g., a dedicated admin view with no filter control), delete this step.

### Error Handling (Steps 3.1–3.3)

Sits inside an **"On block error"** handler, same retry-then-fatal shape as Phase 1's browser launch.

| Action | Display Name | Properties |
|---|---|---|
| Increment variable | Increment Retry Count - Grid Nav | Variable: `%RetryCount%` · Increment by: `1` |
| If | Check Retry Count - Grid Nav | First operand: `%RetryCount%` · Operator: `Less than or equal to` · Second operand: `%MaxRetry%` |
| → Then: Wait | Wait Before Retry - Grid Nav | Duration (seconds): `%RetryDelaySeconds%` |
| → Then: Go to | Retry Pending Grid Nav | Label: `RetryPendingGridNav` |
| → Else: Set variable | Set Log Fields - Grid Load Failed | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Admin pending grid failed to load after retries` |
| → Else: Run subflow | Log Fatal - Grid Load Failed | Run subflow `WriteLogRow` |
| → Else: Close browser | Close Browser on Fatal | Instance: `%Browser%` · On error: continue |
| → Else: Close Excel | Save and Close Log | Save mode: Save document |
| → Else: Stop flow | Stop Run - Fatal Error | (ends the run) |

---

**Step 3.4 — Reset Retry Count (Export/Download)**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Reset Retry Count - Export | `%0%` | `RetryCount` (Number) |

---

**Step 3.5 — Click Export to Excel** *(retry target)*

Place a **Label** action named `RetryExportClick` immediately before this step.

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Reset File Wait Count | `%0%` | `FileWaitCount` (Number) |
| Click | Click Export to Excel Button | UI element: Export button on pending grid | — |

> `FileWaitCount` is reset here, at the top of the retry target, so every export attempt (first try and any retry) gets a fresh polling budget. It is a separate counter from `RetryCount`: `RetryCount` governs *how many times we click Export and re-poll*; `FileWaitCount` governs *how many seconds we poll for the file to appear after one click*. Conflating them would make the click-retry budget and the download-wait budget the same number, which they conceptually aren't.

---

**Step 3.6 — Poll for Export File to Appear**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Loop Condition | Poll Loop - Wait for Export File | First operand: `%FileWaitCount%` · Operator: `Less than` · Second operand: `%TimeoutSeconds%` | — |
| → If file exists | Check Export File Exists | File path: `%ExportFilePath%` | branch |
| → → Then: Exit Loop | Exit Poll Loop - File Found | — | — |
| → → Else: Wait | Wait 1 Second Before Recheck | Duration (seconds): `%1%` | — |
| → → Else: Increment variable | Increment File Wait Count | Variable: `%FileWaitCount%` · Increment by: `1` | — |

---

**Step 3.7 — Confirm File Was Found (else escalate)**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| If file exists | Final Check Export File | File path: `%ExportFilePath%` | branch |
| → Else: Throw error | Throw - Export File Timeout | Message: `Export file did not appear within %TimeoutSeconds% seconds` | (caught by the on-block-error handler below, same as a native action failure) |

### Error Handling (Steps 3.5–3.7)

Sits inside an **"On block error"** handler wrapping Steps 3.5–3.7 (covers both a failed/missing Export click and a download that never lands).

| Action | Display Name | Properties |
|---|---|---|
| Increment variable | Increment Retry Count - Export | Variable: `%RetryCount%` · Increment by: `1` |
| If | Check Retry Count - Export | First operand: `%RetryCount%` · Operator: `Less than or equal to` · Second operand: `%MaxRetry%` |
| → Then: Wait | Wait Before Retry - Export | Duration (seconds): `%RetryDelaySeconds%` |
| → Then: Go to | Retry Export Click | Label: `RetryExportClick` |
| → Else: Set variable | Set Log Fields - Export Failed | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Export to Excel failed or file never downloaded after retries` |
| → Else: Run subflow | Log Fatal - Export Failed | Run subflow `WriteLogRow` |
| → Else: Close browser | Close Browser on Fatal | Instance: `%Browser%` · On error: continue |
| → Else: Close Excel | Save and Close Log | Save mode: Save document |
| → Else: Stop flow | Stop Run - Fatal Error | (ends the run) |

---

**Step 3.8 — Launch Excel on Export File**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Launch Excel | Launch Excel - Open Export | Open document: `%ExportFilePath%` · Visible: No | `ExcelExportInstance` (Excel instance) |

> Deliberately a **separate Excel instance** from `ExcelLogInstance` — the log workbook stays open throughout the run; the export workbook is short-lived (read once, then closed in Step 3.13).

---

**Step 3.9 — Read Export Worksheet into Table**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Read from Excel worksheet | Read Pending Export | Instance: `%ExcelExportInstance%` · Range: all/used range · Get: first row as headers | `PendingList` (Datatable) |

### Error Handling (Steps 3.8–3.9) — fatal, no retry

Sits inside an **"On block error"** handler wrapping Launch Excel (3.8) and Read (3.9). A corrupt, password-protected, or otherwise unreadable export file won't fix itself on a retry, so this escalates straight to fatal — no retry loop, unlike Steps 3.1–3.7.

| Action | Display Name | Properties |
|---|---|---|
| Set variable | Set Log Fields - Export File Unreadable | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Export file unreadable - path: %ExportFilePath%` |
| Run subflow | Log Fatal - Export File Unreadable | Run subflow `WriteLogRow` |
| Close Excel | Close Export Excel on Fatal | Instance: `%ExcelExportInstance%` · On error: continue |
| Close browser | Close Browser on Fatal | Instance: `%Browser%` · On error: continue |
| Close Excel | Save and Close Log | Save mode: Save document |
| Stop flow | Stop Run - Fatal Error | (ends the run) |

---

**Step 3.10 — Validate Export Headers** *(fatal branch, no retry)*

| Action | Display Name | Properties | Output |
|---|---|---|---|
| If | Check Required Columns Present | `%PendingList.Columns%` does not contain `User ID` OR `%PendingList.Columns%` does not contain `Request ID` | branch |
| → Then: Set variable | Set Log Fields - Bad Export Headers | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `Fatal` · `LogReason` = `Export file missing expected columns (User ID / Request ID) - path: %ExportFilePath%` | — |
| → Then: Run subflow | Log Fatal - Bad Export Headers | Run subflow `WriteLogRow` | — |
| → Then: Close Excel | Close Export Excel on Fatal | Instance: `%ExcelExportInstance%` · On error: continue | — |
| → Then: Close browser | Close Browser on Fatal | Instance: `%Browser%` · On error: continue | — |
| → Then: Close Excel | Save and Close Log | Save mode: Save document | — |
| → Then: Stop flow | Stop Run - Fatal Error | (ends the run) | — |

> **Verified in PA Desktop (see reference 4.4 ✅):** same mechanism confirmed at Step 1.10b — the `If` action's condition list supports multiple conditions combined by `OR` directly, no precomputed Boolean needed (an earlier draft here tried that; dropped for the same reason as 1.10b — see Lessons Learned L1).
>
> **Still unverified:** the `%PendingList.Columns%` `does not contain` membership test on a Datatable's column list (reference 7.4 only covers `.RowsCount`, not column-name lookups). If PA Desktop has no such operator/expression, the fallback is to read the header row of Step 3.9's range explicitly and compare cell values. Confirm live before build.

---

**Step 3.11 — Get Pending Count**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Get Pending Count | `%PendingList.RowsCount%` | `PendingCount` (Number) |

---

**Step 3.12 — Initialize Loop Counter**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Set variable | Initialize Current Index | `%0%` | `CurrentIndex` (Number) |

---

**Step 3.13 — Close Export Excel Instance**

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Close Excel | Close Export Excel | Instance: `%ExcelExportInstance%` · Save mode: Don't save | — |

> Closed **before** delete (Step 3.15) — the export file may still be locked by Excel automation while the instance holds it open.

---

**Step 3.14 — Check for Empty List**

Place a **Label** action named `Phase6CleanupStart` at the top of Phase 6's detailed design (built next) — this branch's "Then" jumps there directly, and it is also the fall-through entry point Phase 4's loop reaches on normal completion.

| Action | Display Name | Properties | Output |
|---|---|---|---|
| If | Check Pending Count Zero | First operand: `%PendingCount%` · Operator: `Equal to` · Second operand: `%0%` | branch |
| → Then: Set variable | Set Log Fields - No Pending Items | `LogUserID` = `N/A` · `LogRequestID` = `N/A` · `LogOutcome` = `No items` · `LogReason` = `No pending items - run complete` | — |
| → Then: Run subflow | Log - No Pending Items | Run subflow `WriteLogRow` | — |
| → Then: Delete file(s) | Delete Export File (Empty List) | File(s): `%ExportFilePath%` · On error: continue | — |
| → Then: Go to | Jump to Cleanup | Label: `Phase6CleanupStart` | — |

> The empty-list branch deletes the export file too (best-effort, same as Step 3.15) — a 0-row export left behind would otherwise accumulate on every empty run, since this branch never reaches Step 3.15.

---

**Step 3.15 — Delete Export File** *(only reached if `PendingCount > 0`; best-effort)*

| Action | Display Name | Properties | Output |
|---|---|---|---|
| Delete file(s) | Delete Export File | File(s): `%ExportFilePath%` · On error: continue | — |

> Best-effort / on-error-continue: `PendingList` is already read into memory, so a delete failure (e.g., file briefly locked by antivirus) doesn't block the run — it just risks one leftover export file, a housekeeping concern, not a run failure. Not separately logged as a warning here to avoid an extra Log* global juggling mid-transition into Phase 4; if leftover exports become a real problem in practice, add a warning row.

> **Step 3.15 is the last action of Phase 3.** Flow falls through to Phase 4 (Process Pending Requests Loop) with `PendingList`, `PendingCount`, and `CurrentIndex` populated.

### Variables Declared / Used in This Section

| Variable | Type | Scope | Default / Source |
|---|---|---|---|
| `ExportFilePath` | Text | Global | Already set in Phase 1 (Step 1.6) |
| `RetryCount` | Number | Global | Reset to `%0%` at Steps 3.0 and 3.4 (reused global — see reference 8.1) |
| `FileWaitCount` | Number | Global | Set `%0%` in Step 3.5 (retry target), fresh on every export attempt |
| `ExcelExportInstance` | Excel instance | Global | Step 3.8; closed Step 3.13 |
| `PendingList` | Datatable | Global | Step 3.9 |
| `PendingCount` | Number | Global | Step 3.11 |
| `CurrentIndex` | Number | Global | Initialized `%0%` in Step 3.12; used/incremented in Phase 4 |

### Notes for Implementation
- **Two independent retry blocks, one shared counter:** grid navigation (3.1) and export/download (3.5–3.7) each get their own `RetryCount` reset immediately before their own label — see reference 8.1. Do not skip either reset.
- **Two Excel instances alive at once during this phase:** `ExcelLogInstance` (open since Phase 1, stays open) and `ExcelExportInstance` (opened Step 3.8, closed Step 3.13). Don't confuse which instance an action targets — a `WriteLogRow` call must always target `ExcelLogInstance`.
- **Open assumptions carried from PROGRESS.md** still unresolved by this phase: exact admin-grid navigation path (Step 3.1), and whether a filter step (Step 3.3) is even needed. Both are flagged inline above and should be confirmed against the live Concur UI before implementation.
- The poll loop (Step 3.6) bounds itself by `TimeoutSeconds`, one second per iteration — for a longer expected download time, consider a distinct `DownloadTimeoutSeconds` config value rather than overloading `TimeoutSeconds` (currently used for web-element waits elsewhere). Flagged as a possible future config split, not changed here to avoid scope creep on this phase.
