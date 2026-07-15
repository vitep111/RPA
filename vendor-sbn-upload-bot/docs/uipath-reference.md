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

## Packages (expected)

- `UiPath.Excel.Activities` — Config read, SAP export read, CSV write.
- `UiPath.System.Activities` — core (Assign, If, Try Catch, Invoke Code/VBScript, Delay, logging).
- `UiPath.UIAutomation.Activities` — SBN web portal automation.
- `UiPath.Mail.Activities` (or Outlook via `UiPath.MicrosoftOffice365` / SMTP) — summary/error email. (Exact mail mechanism TBC.)
- SAP GUI automation: handled via the parameterized `.vbs` invoked with `Invoke Code`/`Invoke VBScript`; UiPath SAP activities not required for the extraction itself.

## Unverified platform behaviors (⚠️ — confirm before build)

- **U1 — Invoke Code vs Invoke VBScript for the SAP `.vbs`.** Running the parameterized SAP GUI script from UiPath (passing in run date + output path) — exact activity and argument-passing mechanism to be confirmed. Fallback: write the parameters into the `.vbs` (or a params file) before running, or run via `Start Process`/`cscript`.
- **U2 — SE16N "no values found" detection.** The empty-day check relies on reading SAP's status-bar message after execute. Whether this is surfaced to the `.vbs` (e.g. via the session status bar text) or must be inferred from an empty export file is to be confirmed. Fallback: treat a zero-row export as the empty case.
- **U3 — SBN upload-row identification & status read.** Locating the just-created row by its unique Name and reading its Status cell via UI selectors — selector reliability to be confirmed against the live portal. Fallback: sort by Last Updated / anchor on the Name text.
- **U4 — `Use Excel File` / `Excel Application Scope` auto-closes on exception.** The design assumes the Excel scope releases the workbook on both success and error (so Finally has nothing to close for the config read). Believed correct but unverified. Fallback: an explicit `Close Workbook` / kill stray Excel in Phase 6 cleanup.

## Lessons Learned

*(none yet — populated as live tests confirm or disprove assumptions)*
