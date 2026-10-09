# E-Tax Email Matching Bot — Project Reference

> **Purpose:** Single source of truth for the E-Tax Email Matching RPA project. Use this document to resume development in a new session. Paste this into the conversation or project knowledge to give Claude full context.

> **Last updated:** 2026-05-25
> **Status:** In development (Phase 4B VIM screens TBD)

---

## 1. Project Overview

**Process Name:** E-Tax Email Matching
**Platform:** UiPath (linear workflow, single Main.xaml, no Invoke Workflow)
**Automation Type:** Unattended, scheduled twice daily (times TBC)
**Volume:** 10+ invoices per month
**Department:** Account Payable / Finance
**Systems:** SAP S/4HANA (VIM) + Microsoft Outlook (shared mailbox)

**Business Objective:** Automate matching of incoming E-Tax invoice emails to VIM invoice records. The bot attaches the original .msg email to the VIM document, saving the AP team from manual search-match-attach work.

**This is a NEW process** — no existing manual process. Created as part of S/4HANA implementation.

---

## 2. Requirements Summary

### Trigger & Schedule
- Scheduled via UiPath Orchestrator (twice daily, times TBC)
- For development: Config.xlsx-based (no Orchestrator connection)
- Production: migrate credentials to Orchestrator Credential Store

### Systems & Access
- **SAP VIM** (S/4HANA) — SAP GUI automation, bot service account
- **Outlook** — Shared mailbox `AccountPayableTeam@pttep.com`, Outlook desktop (dev), Graph API (prod consideration)
- **SAP Tables:** `/OPT/VIM_1HEAD` (via SE16N), SQVI query `ETAX_EMAIL`
- **VIM Workplace:** TCode `/n/OPT/VIM_WP`

### Matching Logic
- Match on BOTH **Invoice Number** (field: `Reference` in SE16N) AND **Invoice Date** (field: `Document Date` in SE16N)
- Both must match exactly — no fuzzy matching
- Invoice number searched in email body using `.Contains()`
- Date searched in email body using multiple format variants (C.E. + B.E.)
- Thai Buddhist Era dates (B.E.) converted to C.E. by subtracting 543 years
- 1 email = 1 invoice (no multi-invoice emails)

### Email Sources Analyzed
| Source | Example | Parseable? | Notes |
|--------|---------|-----------|-------|
| E-Tax Providers (KPMG, etc.) | e-taxservice@etax.kpmg.co.th | Yes | Both invoice no. and date in body |
| Vendor-specific (Double A) | etax_dds@doublea1991.com | Yes | Both fields present, B.E. dates |
| PwC | th_noreply@invoice.th.pwc.com | No | Date missing from body — always NOT FOUND |

### What the Bot Does (FOUND case)
1. Save email as .msg to temp folder
2. Open VIM document via `/OPT/VIM_WP`
3. Attach .msg file
4. Save VIM document (Ctrl+S)
5. Close VIM document (/n)
6. Move email to Processed folder in Outlook
7. Log as FOUND

### What the Bot Does (NOT FOUND case)
1. Skip VIM entirely — no SAP action
2. Log as NOT FOUND
3. AP team reviews log/email to handle manually

### What Changed During Development
- ~~Mark FOUND/NOT FOUND in VIM custom field~~ → Removed. No field update needed.
- ~~Click Proceed Workflow~~ → Removed. No workflow advancement.
- ~~Open VIM for NOT FOUND~~ → Removed. Skip VIM entirely for NOT FOUND.
- Just save .msg, attach to VIM, save, close. That's it.

---

## 3. Architecture

### Config: Config.xlsx + Dictionary
- File: `Data\Config.xlsx` with columns: Name, Value, Description
- Read into `dict_Config` as `Dictionary(Of String, Object)` at init
- Access: `dict_Config("KeyName").ToString`

### Config Keys
| Name | Value | Description |
|------|-------|-------------|
| SharedMailboxAddress | AccountPayableTeam@pttep.com | Shared mailbox |
| ProcessedFolderName | Processed | Subfolder for matched emails |
| LogFilePath | \\server\share\ETax_Logs\ | Shared drive for logs |
| TempFolderPath | C:\Bot\ETax\Temp\ | Local temp for .msg files |
| SummaryEmailRecipients | AccountPayableTeam@pttep.com | Summary email recipients |
| SAP_TCode_ETaxReport | [TBD] | Custom report T-code |
| SAP_SystemID | [TBD] | SAP system connection |
| SAP_Client | [TBD] | SAP client number |
| SAP_Username | BOT_ETAX | *Move to Orchestrator for prod |
| SAP_Password | ******** | *Move to Orchestrator for prod |
| Outlook_Username | bot_etax@pttep.com | *Move to Orchestrator for prod |
| Outlook_Password | ******** | *Move to Orchestrator for prod |
| MaxRetryCount | 3 | Retry attempts for system errors |
| RetryDelaySeconds | 10 | Seconds between retries |
| EmailFilterDays | 30 | Days to look back for emails |
| SummaryEmailSubject | E-Tax Email Matching — Run Summary | Subject template |
| ErrorEmailSubject | E-Tax Email Matching — CRITICAL ERROR | Error subject template |

### Error Handling: Three Levels
- **Level 1: Global Try-Catch** — catastrophic failures → error email → cleanup → terminate
- **Level 2: Retry Scope** — transient failures (Outlook connection) → retry up to 3x → throw to Level 1
- **Level 3: Per-item Try-Catch** — single invoice failure → log error → continue to next

### Flow Control
- `bool_SkipToPhase5` — set True when nothing to process → skips Phase 3 & 4
- Phase 5 (notification) and Phase 6 (cleanup) always run

---

## 4. Workflow Phases

### Phase 1: Initialization
- Read Config.xlsx into dict_Config (Read Range + For Each Row loop)
- Initialize counters: int_FoundCount, int_NotFoundCount, int_ErrorCount, int_TotalCount (all = 0)
- Build dt_Log DataTable (8 columns: RunTimestamp, InvoiceNumber, InvoiceDate, Vendor, Status, EmailSubject, EmailSender, ErrorDetails)
- Create temp folder (delete old + recreate for clean state)
- Log: "Phase 1 complete"

### Phase 2: Get Report Data (Two-Table Approach)

**Part A — SE16N:**
- Navigate to SE16N → table `/OPT/VIM_1HEAD`
- Filter: CUSTOM_FIELD4 = X, Date = Today
- Execute (F8)
- Check results: if zero → bool_SkipToPhase5 = True → skip to Phase 5
- Extract Table Data → dt_AllDocIDs
- Build arr_DocIDs and str_DocIDsPaste (newline-separated) for SQVI paste
- Close SE16N (/n)

**Part B — SQVI:**
- Navigate to SQVI → query ETAX_EMAIL (user handles opening query + selecting variant)
- Click Multiple Selection button (yellow arrow) next to Object ID field
- Set to Clipboard: str_DocIDsPaste → Click "Upload from Clipboard"
- Click confirm/copy → Execute (F8)
- Check results:
  - If has results → Extract Table Data → dt_AlreadyDone
  - If no results → dt_AlreadyDone = New DataTable ← **CRITICAL: prevents null reference crash**
- Close SQVI (/n)

**Part C — Compare:**
- Assign 1: `list_DoneIDs = If(dt_AlreadyDone.Rows.Count > 0, LINQ.Select("Object ID").ToList(), New List(Of String))`
- Assign 2: `bool_HasUnprocessed = dt_AllDocIDs...Where(Not list_DoneIDs.Contains("Document Id")).Any()`
- Assign 3 (inside If):
  - Then: `dt_NeedProcessing = ...Where(...).CopyToDataTable()`
  - Else: `dt_NeedProcessing = dt_AllDocIDs.Clone()` ← empty table, prevents CopyToDataTable crash
- If dt_NeedProcessing.Rows.Count = 0 → bool_SkipToPhase5 = True
- int_TotalCount = dt_NeedProcessing.Rows.Count
- Log: "Phase 2 complete. SE16N: X | SQVI: Y | Need processing: Z"

### Phase 3: Connect Outlook
- Wrapped in: `If Not bool_SkipToPhase5`
- Retry Scope (3 retries, 10s delay):
  - Get Outlook Mail Messages from shared mailbox Inbox
  - Filter: last 30 days (`EmailFilterDays` from config)
  - Filter format: `"[ReceivedTime] >= '" + Now.AddDays(-30).ToString("MM/dd/yyyy HH:mm") + "'"`
  - Top: 999, OnlyUnreadMessages: False, MarkAsRead: False
  - Output: list_AllEmails
- Validate: if 0 emails → Log Warn (but continue — all invoices will be NOT FOUND)
- Log: "Phase 3 complete. X emails fetched."

**Key gotchas:**
- Outlook date filter uses US format (MM/dd/yyyy) regardless of locale
- Shared mailbox must be added to Outlook profile on bot machine
- If all retries fail → exception bubbles to global Try-Catch

### Phase 4: Process Loop
- Wrapped in: `If Not bool_SkipToPhase5`
- Structure: `For Each Row (row) in dt_NeedProcessing → Try-Catch`

**Phase 4A: Email Search (inside Try):**
1. Reset variables (str_CurrentDocID, str_InvoiceNo, str_InvoiceDate, bool_MatchFound = False, mail_MatchedEmail = Nothing)
2. Extract: str_CurrentDocID = row("Document Id"), str_InvoiceNo = row("Reference"), str_InvoiceDate = row("Document Date")
3. Log: "Processing X of Y: DocID=... InvNo=... Date=..."
4. Parse date: dt_ParsedDate = DateTime.ParseExact(str_InvoiceDate, "dd.MM.yyyy", ...) ← **VERIFY format from actual SE16N export**
5. Build C.E. date variants: {dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy, yyyy-MM-dd, d/M/yyyy}
6. Build B.E. date variants: {dd/MM/BBBB, dd-MM-BBBB, d/M/BBBB} where year + 543
7. Combine: arr_AllDateVariants = CE.Concat(BE).ToArray()
8. Search: `mail_MatchedEmail = list_AllEmails.Where(Function(m) m.Body IsNot Nothing AndAlso m.Body.Contains(str_InvoiceNo) AndAlso arr_AllDateVariants.Any(Function(d) m.Body.Contains(d))).FirstOrDefault()`
9. Flag: `bool_MatchFound = mail_MatchedEmail IsNot Nothing`
10. Log: MATCH FOUND or NO MATCH

**Single If block (merged 4A.7 + 4B):**

**Then (FOUND):**
- Build path: `str_MsgFilePath = TempFolder + "ETAX_" + str_InvoiceNo + "_" + dt_ParsedDate.ToString("yyyyMMdd") + ".msg"`
- Save Mail Message → str_MsgFilePath
- Navigate: `/n/OPT/VIM_WP`
- Search + open VIM document by str_CurrentDocID [TBD — selectors needed]
- Click attachment button, type str_MsgFilePath, confirm [TBD — selectors needed]
- Save: Ctrl+S
- Close: /n + Enter
- Move Outlook Mail Message → Processed folder
- int_FoundCount += 1
- Add Data Row to dt_Log: FOUND with email subject + sender

**Else (NOT FOUND):**
- int_NotFoundCount += 1
- Add Data Row to dt_Log: NOT FOUND
- No VIM action at all

**Catch (System.Exception ex):**
- Log Error with doc ID, invoice no., error message
- int_ErrorCount += 1
- Add Data Row to dt_Log: ERROR with ex.Message

Log after loop: "Phase 4 complete. Found: X | Not Found: Y | Errors: Z"

### Phase 5: Notification & Logging (always runs)
1. Build str_LogFilePath: LogPath + "E-Tax_Matching_Log_" + timestamp + ".xlsx"
2. Write Range (Workbook): dt_Log → str_LogFilePath
3. Build str_EmailBody: summary with SE16N total, SQVI processed, need processing, Found, Not Found, Errors counts + log file path (with null safety checks)
4. Build str_EmailSubject: subject with counts for at-a-glance inbox view
5. Send Outlook Mail Message: to AP team, attach log file .xlsx
6. Log: "Phase 5 complete"

### Phase 6: Cleanup (always runs)
1. Delete temp folder (If exists → Delete Folder recursive)
2. Close SAP GUI: "/nex" (wrapped in its own Try-Catch — cleanup must not crash)
3. (Optional) Kill Process: "saplogon"
4. Log: "Run complete"

---

## 5. Variables — Complete Inventory

### Main Sequence scope (persist across all phases)
| Variable | Type | Initialized in | Used in |
|----------|------|----------------|---------|
| dict_Config | Dictionary(Of String, Object) | Phase 1 | All phases |
| dt_Log | DataTable | Phase 1 | Phase 4, 5 |
| int_FoundCount | Int32 (default: 0) | Phase 1 | Phase 4, 5 |
| int_NotFoundCount | Int32 (default: 0) | Phase 1 | Phase 4, 5 |
| int_ErrorCount | Int32 (default: 0) | Phase 1 | Phase 4, 5 |
| int_TotalCount | Int32 (default: 0) | Phase 2 | Phase 4, 5 |
| dt_AllDocIDs | DataTable | Phase 2 (SE16N) | Phase 2 (Part C) |
| dt_AlreadyDone | DataTable (default: New DataTable) | Phase 2 (SQVI) | Phase 2 (Part C) |
| dt_NeedProcessing | DataTable | Phase 2 (Part C) | Phase 4 |
| bool_SkipToPhase5 | Boolean (default: False) | Phase 2 | Phase 3, 4 |
| list_AllEmails | List(Of MailMessage) | Phase 3 | Phase 4 |
| str_LogFilePath | String | Phase 5 | Phase 5 |
| str_EmailBody | String | Phase 5 | Phase 5 |
| str_EmailSubject | String | Phase 5 | Phase 5 |

### Phase 2 intermediate (used within Phase 2 only)
| Variable | Type | Purpose |
|----------|------|---------|
| dt_Config | DataTable | Config.xlsx raw data (used once in Phase 1) |
| arr_DocIDs | String[] | Array of Doc IDs for SQVI paste |
| str_DocIDsPaste | String | Newline-separated Doc IDs for clipboard |
| list_DoneIDs | List(Of String) | SQVI Object IDs for comparison |
| bool_HasUnprocessed | Boolean | CopyToDataTable safety check |
| bool_HasResults | Boolean | SE16N results check |
| bool_SQVIHasResults | Boolean | SQVI results check |
| int_EmailCount | Int32 | Count of fetched emails (logging) |

### Phase 4 per-iteration (scoped inside For Each body)
| Variable | Type | Purpose |
|----------|------|---------|
| str_CurrentDocID | String | Current Document Id |
| str_InvoiceNo | String | Current Reference (invoice number) |
| str_InvoiceDate | String | Current Document Date (raw string) |
| dt_ParsedDate | DateTime | Parsed date for format conversion |
| arr_DateSearchCE | String[] | C.E. date format variants |
| arr_DateSearchBE | String[] | B.E. date format variants (+543) |
| arr_AllDateVariants | String[] | Combined C.E. + B.E. variants |
| mail_MatchedEmail | MailMessage | Matched email (Nothing if not found) |
| bool_MatchFound | Boolean | True = found, False = not found |
| str_MsgFilePath | String | Path to saved .msg file |

---

## 6. Known Issues & Decisions Made

### Issues encountered during development
1. **"Object reference not set"** on Phase 2 log — caused by dt_AlreadyDone not being initialized in the SQVI Else branch. Fix: `dt_AlreadyDone = New DataTable` in Else.
2. **"The directory name is invalid"** on Save Mail Message — caused by putting `str_MsgFilePath` in quotes (literal string) instead of referencing the variable. Fix: remove quotes.
3. **"The operation has timed out"** on Get Outlook Mail Messages — Outlook not fully synced, or shared mailbox still downloading. Fix: increase TimeoutMS, ensure Outlook is fully loaded.
4. **0 emails returned** — Outlook date filter format issue. Outlook requires MM/dd/yyyy (US format) regardless of locale.

### Design decisions
1. **Pre-fetch all emails (Option A)** over search-per-invoice (Option B) — because invoice data is in the email body (not subject), and Outlook body search via DASL filter is unreliable for HTML emails and Thai text.
2. **Single If block** for FOUND/NOT FOUND instead of two separate Ifs — simpler, less nesting, same Try-Catch coverage.
3. **Move email to Processed LAST** (after VIM save) — if VIM fails, email stays in Inbox for retry on next run.
4. **SE16N + SQVI two-table approach** — SE16N gets today's E-Tax invoices, SQVI checks which are already done, Part C comparison produces the filtered list.
5. **Config.xlsx for dev, Orchestrator for prod** — get it working first, optimize later.
6. **No FOUND/NOT FOUND field update in VIM** — removed during development. Just attach .msg and save.
7. **No Proceed Workflow click** — removed during development. Just save.

---

## 7. What's Still TBD

| Item | Depends on | Who |
|------|-----------|-----|
| VIM Workplace screen selectors (search field, open doc, attachment button, upload dialog) | VIM custom report development | Developer — record actual screens |
| SE16N date field name for filter | Access to test system | Developer — verify field name |
| SE16N Document Date export format (dd.MM.yyyy or other) | Actual SE16N export | Developer — export sample and check |
| SAP system ID, client number | SAP Basis team | IT |
| Shared drive path for log files | Infrastructure setup | IT |
| Scheduled run times | Business decision | AP Team Lead |
| Production credential migration to Orchestrator | Orchestrator setup | RPA + IT |
| UAT sign-off | All test cases pass | AP Team + RPA |

---

## 8. Documents Produced

1. **FSD** — Functional Specification Document (E-Tax_Email_Matching_FSD.docx)
2. **Executive Summary** — Management overview (E-Tax_Executive_Summary.docx)
3. **UAT Test Cases** — 20 test cases with sign-off (E-Tax_UAT_Test_Cases.docx)
4. **Process Flow Diagram** — SVG flowchart (rendered in chat)
5. **Developer Guide** — Step-by-step phases 1-6 (rendered in chat as interactive cards)

---

## 9. How to Continue Development in a New Session

1. Paste this document into the new chat or project knowledge
2. Reference the `/mnt/skills/user/uipath-bot-dev/SKILL.md` for the development methodology
3. Tell Claude which phase/step you're working on or what issue you're facing
4. For VIM screen development: describe the actual VIM Workplace screens and Claude will build the Phase 4B selectors
5. For troubleshooting: paste the exact error message and Claude will diagnose

### Quick resume prompts:
- "I'm working on the E-Tax bot. I need help with Phase 4B VIM selectors — the VIM Workplace screen is now ready."
- "I'm testing TC-008 (mixed batch) and getting an error on the third invoice."
- "I need to update the FSD — we changed the matching logic."
- "Ready for production migration — help me move from Config.xlsx to Orchestrator."
