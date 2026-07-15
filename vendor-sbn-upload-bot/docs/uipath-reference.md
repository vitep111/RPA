# UiPath Reference — Daily Vendor SBN Upload Bot

Source of truth for how this bot is built in UiPath. The reviewer checks the design's **correctness** against this doc. Rules marked ✅ are **project-adopted conventions** (our own hard constraints — non-negotiable). Rules marked ⚠️ are **believed-but-unverified platform behavior** — treat with caution, flag inline in the design with a documented fallback, and confirm before/at build.

## Platform hard constraints (✅ project-adopted)

- **R1 — Linear Sequences only.** Everything is nested `Sequence` containers. No Flowchart, no State Machine, no REFramework.
- **R2 — Single Main.xaml.** No `Invoke Workflow File`; no splitting into separate `.xaml`. All logic lives in `Main.xaml`, organized by named `Sequence` containers (`DisplayName`) as logical sections.
- **R3 — Config.xlsx at startup.** A `Config.xlsx` (Name/Value columns, sheet "Config") is read once into `configDict`. All environment-specific values (paths, URLs, credentials, retry/timeout numbers, email recipients) come from Config — **never hardcoded**.
- **R4 — Dictionary for structured data.** Use `Dictionary(Of String, String)` / `Dictionary(Of String, Object)`. Use `DataTable` only for genuine tabular row iteration (e.g. the SAP export / Excel reads).
- **R5 — Verb + Object naming.** Every activity and Sequence `DisplayName` is Verb + Object ("Read Config File", "Click Upload Button", "Assign Upload Name").
- **R6 — Windows project.** Target UiPath **Windows** project. VB.NET (and C#) expressions are acceptable; string literals are quoted (`"..."`), expressions use VB.NET syntax (`+` concatenation, `.ToString`, `CInt(...)`).
- **R7 — No credentials in the design.** Credentials are read from Config (or an Orchestrator asset / Windows Credential Manager if later chosen) — never written into the workflow or these docs.

## Standard patterns (✅ project-adopted)

- **P1 — Config read.** `Excel Application Scope`/`Use Excel File` on `configPath` → `Read Range` "Config" → `configTable` (DataTable) → `For Each Row` → `configDict(row("Name").ToString) = row("Value").ToString`.
- **P2 — Retry block.** `Assign retryCount = 0` → `Do While retryCount < CInt(configDict("MaxRetry"))` → `Try Catch`: Try does the action then sets `retryCount = CInt(configDict("MaxRetry"))` to exit; Catch does `retryCount = retryCount + 1`, and if `retryCount >= MaxRetry` logs Error + `Rethrow`, else `Delay`. Any reused counter is reset before each independent retry block.
- **P3 — Logging.** `Log Message` at: bot start (Info), each phase start/end (Info), each caught error (Error, includes `exception.Message`), bot end (Info).
- **P4 — Outer Try-Catch-Finally.** `Main` wraps Phases 1–5 in a `Try`; `Catch (Exception)` logs Error + sends the error email; `Finally` runs Phase 6 Cleanup (close apps) so it executes on every exit path.
- **P5 — SAP GUI UI automation.** Drive SAP GUI with `UiPath.UIAutomation.Activities` (SAP GUI Scripting enabled). Enter transaction codes via the command field (`Type Into`), fill selection fields, execute (`Click`/`F8`), and read results/status via SAP GUI selectors. Prefer stable SAP element IDs in selectors over screen coordinates. Wait for elements (`Element Exists` / reliable selectors) rather than fixed delays. Read the **status bar** element for messages (empty result, errors).

## Packages (expected)

- `UiPath.Excel.Activities` — Config read, SAP export read, CSV write.
- `UiPath.System.Activities` — core (Assign, If, Try Catch, Delay, logging).
- `UiPath.UIAutomation.Activities` — SBN web portal automation.
- `UiPath.Mail.Activities` (or Outlook via `UiPath.MicrosoftOffice365` / SMTP) — summary/error email. (Exact mail mechanism TBC.)
- SAP GUI automation: handled via **`UiPath.UIAutomation.Activities`** driving the SAP GUI directly (SAP GUI Scripting must be enabled — UiPath's SAP selectors are built on it). No `.vbs`, no separate SAP package needed for GUI screen automation.

## Unverified platform behaviors (⚠️ — confirm before build)

- **U1 — RETIRED.** (Was: Invoke Code/VBScript for a SAP `.vbs`.) Superseded by native UiPath SAP UI automation — no `.vbs` is used. Kept as a placeholder so later U-numbers don't shift.
- **U2 — SAP "no values found" detection.** The empty-day check reads SAP's **status-bar text directly in UiPath** (`Get Text` on the status-bar element) after executing the SQVI query, and tests it for the no-records message. Exact message text and the status-bar selector to be confirmed live. Fallback: treat a zero-row export as the empty case.
- **U3 — SBN upload-row identification & status read.** Locating the just-created row by its unique Name and reading its Status cell via UI selectors — selector reliability to be confirmed against the live portal. Fallback: sort by Last Updated / anchor on the Name text.
- **U4 — `Use Excel File` / `Excel Application Scope` auto-closes on exception.** The design assumes the Excel scope releases the workbook on both success and error (so Finally has nothing to close for the config read). Believed correct but unverified. Fallback: an explicit `Close Workbook` / kill stray Excel in Phase 6 cleanup.
- **U5 — SAP create-date filter format.** The value UiPath types into the SQVI query's create-date (ERDAT) selection field is locale-dependent (SAP display format, e.g. `dd.MM.yyyy` vs `MM/dd/yyyy`) and must match the SAP user's date format. Unverified until tested live. Fallback: confirm the format from a manual query run and set it explicitly; keep it a Config value if it varies by environment.
- **U6 — RETIRED.** (Was: `.vbs`→UiPath result-token file contract.) No longer needed — UiPath reads the SAP status bar directly (U2) and drives the export itself (U7), so there is no cross-boundary result file. Kept as a placeholder so later U-numbers don't shift.
- **U7 — SAP ALV export to local file via UiPath.** Exporting the SQVI result grid to `ExportPath` by driving the SAP menu (System → List → Export → Local File → Spreadsheet, or the toolbar export button) with UI activities — exact menu path, the file-format dialog, and overwrite/replace handling to be confirmed live. Fallback: alternate export format (e.g. text/`.xls`) or read the ALV grid directly.
- **U8 — SBN CSV format specifics.** The output CSV must match what SBN's uploader accepts: field delimiter (assumed comma), text encoding (e.g. UTF-8), quoting/escaping of values containing commas, and whether a header row is required. To be confirmed against a known-good SBN template/sample. Fallback: match the byte format of a manually-exported working file exactly (delimiter, encoding, line endings).
- **U9 — SQVI query navigation & selection.** Driving SQVI to select the named query (`SAPQueryName`) and reach its selection screen — exact steps (SQVI opens on a query list vs. last query; how to pick the query; Execute) and behavior when the query is absent for the login user, to be confirmed live. Note SQVI queries are **user-specific** — the query must exist under (or be shared to) the bot's SAP user (see PDD Prerequisites). Fallback: run the query's generated program directly, or use a global InfoSet query the bot user can access.

## Lessons Learned

*(none yet — populated as live tests confirm or disprove assumptions)*
