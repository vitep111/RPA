# UiPath Reference — Concur Cash Advance Auto-Submit Bot

Source of truth for how this bot is built in UiPath. The `rpa-design-reviewer` agent checks the design's **correctness** against this doc.

- Rules marked ✅ are **project-adopted conventions** (our own hard constraints — non-negotiable).
- Rules marked ⚠️ are **believed-but-unverified platform behavior** — treat with caution, flag inline in the design with a documented fallback, and confirm before/at build.

> **Status:** new in the UiPath rebuild; synced to the folder-membership report design in `PDD.md`. **Reviewed → PASS (2026-08-06).** Expect it to grow as the medium-level design lands and as ⚠️ items get verified live.

> **Supersedes `pa-desktop-reference.md`.** That file is the PA Desktop-era record and is **no longer the rulebook**. Critically, its Lessons Learned **L1** (`If` multi-condition vs. Boolean precompute) and **L2** (`Set variable` can never be blank — use `N/A`) are **PA Desktop parser quirks that do not apply to UiPath**. UiPath's `Assign` has neither restriction, and `If` takes an ordinary VB.NET boolean expression with `AndAlso`/`OrElse`. Do not carry those rules forward. Its rule 9.1 (`Go to`/`Label` scoping) is void — UiPath has no `Go to`; see R9.

## Platform hard constraints (✅ project-adopted)

- **R1 — Linear Sequences only.** Everything is nested `Sequence` containers. No Flowchart, no State Machine, no REFramework.
- **R2 — Single Main.xaml.** No `Invoke Workflow File`; no splitting into separate `.xaml`. All logic lives in `Main.xaml`, organized by named `Sequence` containers (`DisplayName`) as logical sections. This is a **project convention mandated by the `rpa-bot-dev` skill**, not a platform limitation — UiPath does support `Invoke Workflow File`; we deliberately don't use it.
- **R3 — Config.xlsx at startup.** A `Config.xlsx` (Name/Value columns, sheet "Config") is read once into `configDict`. All environment-specific values come from Config — **never hardcoded**. Required keys:

  | Key | Purpose |
  |---|---|
  | `ConcurBaseUrl` | Concur web entry point (Phase 3 — no consumer yet, pending the login-method decision) |
  | `MaxRetry` | Total attempts (see P2) |
  | `RetryDelaySeconds` | Pause between retry attempts (P2) |
  | `TimeoutSeconds` | Element/page wait ceiling (P5) |
  | `LogFilePath` | Excel run log |
  | `ReportSender` | Expected sender of the Concur report email |
  | `ReportSubject` | Expected subject (or subject fragment) |
  | `ReportFolder` | Outlook folder the reports arrive in |
  | `ProcessedFolder` | Outlook subfolder processed reports are moved to |
  | `AttachmentFolder` | Disk folder the attachment is saved to |
  | `StaleReportHours` | Age beyond which a missing report raises the `Stale report` warning |
  | *(login secrets)* | **Only if** the chosen login method needs any — the preferred WIA/SSO option has none (see `PDD.md` → Credentials Required) |

  `configPath` itself is **not** a Config key — it can't be, since it's what locates Config. It is a project-relative constant (`Directory.GetCurrentDirectory() + "\Data\Config.xlsx"`), the one permitted hardcoded path.

- **R4 — Dictionary for structured data.** Use `Dictionary(Of String, String)` / `Dictionary(Of String, Object)`. `DataTable` is permitted **only** for genuine tabular row iteration: the config read (`configTable`, P1), the report attachment read (`pendingTable`), and the run-log accumulation/write (`runLogTable`, P8).
- **R5 — Verb + Object naming.** Every activity and Sequence `DisplayName` is Verb + Object ("Read Config File", "Save Report Attachment", "Click Submit Button").
- **R6 — Windows project.** Target UiPath **Windows** project. VB.NET expressions; string literals are quoted (`"..."`), expressions use VB.NET syntax (`+` concatenation, `.ToString`, `CInt(...)`, `AndAlso`/`OrElse`).
- **R7 — No credentials in the design.** Credentials are read from Config (or an Orchestrator asset / Windows Credential Manager if later chosen) — never written into the workflow or these docs.

## Control-flow and guard rules (✅ project-adopted)

- **R8 — Prologue: guards and state initialized before the outer Try.** Phase 6 runs from `Finally` (P4) on **every** exit path, including ones where earlier phases never ran. It must therefore assume nothing.

  > **All initialization below lives in a `Sequence` named "Initialize Run State" at the top of `Main` that *precedes* the outer Try — NOT inside Phase 1.** P4's Try wraps Phases 1–5, so anything initialized *inside* Phase 1 is unset if Phase 1 fails ahead of that line, which puts every variable back to its .NET default. That is exactly the failure R9 exists to prevent.

  | Variable | Type | Initialized to | Set by | Purpose |
  |---|---|---|---|---|
  | `runShouldContinue` | Boolean | **`True`** | Phase 2 clean-exit branch → `False` | Gates Phases 3 and 4 (R9) |
  | `configLoaded` | Boolean | `False` | Phase 1, after `configDict` is populated | Any Phase 6 use of `configDict`. If `False`, Phase 6 writes to a **hardcoded fallback log path** instead. |
  | `attachmentSaved` | Boolean | `False` | Phase 2, immediately after the attachment is written to disk | Deleting the attachment file |
  | `browserLaunched` | Boolean | `False` | Phase 3, immediately after the browser opens | Closing the browser |
  | `runLogTable` | DataTable | **`Build Data Table`** — UserID, RequestID, Outcome, Reason, Timestamp (all String except Timestamp) | Appended to throughout | P8. **Must be built here, not declared bare** — a `DataTable` variable with no Default is `Nothing`, and `Append Range` on `Nothing` throws. |

  `configLoaded` exists because a `Config.xlsx` read failure lands in Catch → Finally → Phase 6, which would otherwise dereference `configDict("LogFilePath")` and throw `KeyNotFoundException` **inside `Finally`** — masking the real error and producing no run log at all. `runLogTable` is built in the same prologue for the same reason: that failure path is precisely where the run log matters most, and P4's per-step inner Try Catch would swallow the null-reference silently.

- **R9 — No `Go to`.** The PA Desktop design used in-flow `Go to Phase6CleanupStart` for early exits. **UiPath has no equivalent and none is to be invented.** Clean exits use a `runShouldContinue` boolean:
  - **`Assign runShouldContinue = True` in the R8 prologue — the Sequence at the top of `Main` that precedes the outer Try, not inside Phase 1.** *(A UiPath `Boolean` with no Default is `False` — without this line Phases 3 and 4 never execute on any run, and the bot silently submits nothing while reporting success. Putting it inside Phase 1 reintroduces the same bug for any Phase 1 failure that occurs ahead of it.)*
  - Phase 2 sets it `False` on the clean-exit paths only (no report waiting, empty report).
  - Phases 3 and 4 are each wrapped in `If runShouldContinue`.
  - **Fatal paths never touch it** — they `Throw`, caught by P4's outer Catch. So the flag has exactly two writers: **the R8 prologue initializer** and the Phase 2 clean-exit branch.
  - Phase 6 runs unconditionally from `Finally`, guarded by R8 rather than by this flag.

## Standard patterns (✅ project-adopted)

- **P1 — Config read.** `Use Excel File` on `configPath` → `Read Range` "Config" → `configTable` (DataTable) → `For Each Row` → `configDict(row("Name").ToString) = row("Value").ToString` → `Assign configLoaded = True`.
- **P2 — Retry block.** `Assign retryCount = 0` → `Do While retryCount < CInt(configDict("MaxRetry"))` → `Try Catch`: Try does the action then sets `retryCount = CInt(configDict("MaxRetry"))` to exit; Catch does `retryCount = retryCount + 1`, and if `retryCount >= MaxRetry` logs Error + `Rethrow`, else `Delay` for `configDict("RetryDelaySeconds")`. **`MaxRetry` is the total number of attempts, not the number of additional retries** (`MaxRetry = 3` → 3 attempts). Any reused counter is reset before each independent retry block.
- **P3 — Logging.** `Log Message` at: bot start (Info), each phase start/end (Info), each caught error (Error, including `exception.Message`), bot end (Info). Separately the **run log** is the Excel deliverable (P8). The canonical outcome vocabulary — use these literals exactly, everywhere:
  - **Per item:** `Submitted` · `Skipped` · `Failed`
  - **Run level:** `No report` · `Stale report` · `No items` · `Fatal`
- **P4 — Outer Try-Catch-Finally with best-effort cleanup.** `Main` wraps Phases 1–5 in a `Try`; `Catch (Exception)` logs Error and records a `Fatal` outcome row; `Finally` runs Phase 6 Cleanup so it executes on every exit path. **Every Phase 6 step sits in its own inner `Try Catch` that logs and swallows** — an Excel write, a file delete, or a browser close throwing from inside `Finally` would otherwise escape uncaught and *replace* the original fatal exception, destroying the diagnosis.
- **P5 — Web UI automation.** Drive Concur with `UiPath.UIAutomation.Activities`. Prefer stable selectors/anchors over coordinates. Wait for elements (`Element Exists`, `Check App State`) with a timeout of `configDict("TimeoutSeconds")` rather than fixed `Delay`s.
- **P6 — Per-item isolation in the loop.** Each iteration of the Phase 4 loop is wrapped in its own `Try Catch` so a single item's failure records a `Failed`/`Skipped` outcome and continues to the next item, never aborting the run.
- **P7 — Outlook report read (folder-membership).** State is **folder membership, never read/unread** — read status is not consulted anywhere.
  0. Verify Outlook is reachable and both `ReportFolder` and `ProcessedFolder` exist; throw on failure (this is HLD flow node `O`, and it is an **explicit** check rather than relying on a later activity to throw — so the run log records a clear cause).
  1. `Get Outlook Mail Messages` on `configDict("ReportFolder")`, **`MarkAsRead = False`**, no unread filter.
  2. Filter to reports matching `configDict("ReportSender")` and `configDict("ReportSubject")` (see U3 for whether this is a DASL filter or a LINQ pass over the returned collection).
  3. Sort the returned collection **explicitly** by `ReceivedTime` descending — activity ordering is not relied on (U2).
  4. If the collection is empty → **staleness branch**: a second `Get Outlook Mail Messages` against `configDict("ProcessedFolder")`, take the newest `ReceivedTime` across both folders, and compare against `configDict("StaleReportHours")`. Older → `Stale report`; otherwise → `No report`. Both are clean exits (R9).
     > ⚠️ **`Top = 1` cannot be used here.** Per U2 the activity guarantees no ordering, so "newest" requires retrieving the folder and sorting. Since `ProcessedFolder` grows by one message per hour and this branch runs on *most* runs, its **retention policy is load-bearing for performance, not just housekeeping** — an unbounded folder makes the cheapest, most common path the slowest. Bound it (retention window, or an archive subfolder) and say so in the medium-level design.
  5. Otherwise take the newest → `Save Attachments` to `configDict("AttachmentFolder")` under a per-run unique filename → `Assign attachmentSaved = True`.
  6. Read the attachment into `pendingTable`.
  7. `Move Outlook Mail Message` that message **and the folder's remaining backlog** into `configDict("ProcessedFolder")` (U12).

  **Failure split — these two are deliberately different:**
  - *Attachment cannot be saved* (path/permissions/disk): abort **without moving**. Environmental fault; the report is fine and must stay in the folder for the next run.
  - *Attachment saved but unreadable / wrong columns*: **move it and the backlog first**, then abort. Otherwise the malformed report fails the bot identically every hour forever.
- **P8 — Run-log accumulation.** `runLogTable` is **built in the R8 prologue** (not declared bare) and rows are appended as outcomes occur: per item in Phase 4, run-level in Phase 2 (`No report`, `Stale report`, `No items`) and in **P4's outer Catch** (`Fatal`). Phase 6 writes the whole table to `configDict("LogFilePath")` in one `Append Range`, and must tolerate a zero-row table without erroring.
  - **Run-level rows use the literal `N/A`** in `UserID` and `RequestID`. This is a readability choice for a human-read Excel deliverable — *not* the PA Desktop `Set variable` restriction from the superseded rulebook's L2, which does not apply to UiPath.
  - **The accumulated rows *are* the run summary** referenced in `PDD.md` step 6. There is no separate summary row.

## Packages (expected)

- `UiPath.System.Activities` — core (Assign, If, Try Catch, Delay, Log Message).
- `UiPath.Excel.Activities` — Config read, report attachment read, run-log write.
- `UiPath.Mail.Activities` — `Get Outlook Mail Messages`, `Save Attachments`, **`Move Outlook Mail Message`**. *(No mark-as-read activity is used or needed — the design never consults read state. Classic Outlook activities return `System.Net.Mail.MailMessage`, which carries no read-state property anyway.)*
- `UiPath.UIAutomation.Activities` — Concur web automation (Act-as, pending block, Submit).

## Unverified platform behaviors (⚠️ — confirm before build)

- **U1 — Classic Outlook activities under an unattended robot.** `UiPath.Mail.Activities`' Outlook activities drive Outlook through Interop/MAPI, requiring Outlook installed with a **loaded mail profile in an interactive Windows session**. An unattended robot in a disconnected or session-0 context is the classic failure mode. Load-bearing for the entire report source. **Fallback:** Microsoft 365 / Graph activities against a service mailbox (changes the auth story — needs an app registration), or IMAP.
- **U2 — Returned-message ordering.** `Get Outlook Mail Messages` does not guarantee any particular order. **Mitigation already in P7:** sort explicitly by `ReceivedTime` descending. Confirm the returned items expose `ReceivedTime` as expected.
- **U3 — Sender/subject filtering syntax.** The activity's `Filter` property takes a **DASL/MAPI query string**, not a plain VB expression. Exact syntax to be pinned. **Fallback:** retrieve **all messages in the report folder** unfiltered and filter with LINQ over the returned collection on `.From` / `.Subject`.
- **U4 — Folder addressing.** How `ReportFolder` and the nested `ProcessedFolder` are named in the activity's `MailFolder` property (nested-path syntax, e.g. `Inbox\ConcurReports\Processed`), and behavior when the folder does not exist. **Fallback:** create the folders manually as a documented setup step; presence is validated at **P7 step 0** (HLD node `O`), at the start of Phase 2 rather than in Phase 1 — the check needs Outlook itself to be up, which is a Phase 2 concern.
- **U5 — `Save Attachments` behavior.** Output shape, target-folder creation, and **filename collisions across hourly runs** (Concur will likely send the same attachment name every hour). **Mitigation in P7:** per-run unique filename. Confirm whether the activity can rename on save or whether a save-then-rename/move step is needed.
- **U6 — Report attachment file format.** Concur report attachments are frequently **`.xls`-named HTML or CSV** rather than true OOXML/BIFF. If so, `Read Range` fails outright. Must be confirmed against a real report email before the Phase 2 detailed design. **Fallback:** `Read CSV`, or an HTML-table parse, selected on the actual format.
- **U7 — Browser lifetime across phases.** The browser is launched in Phase 3, used in Phase 4, and closed in Phase 6. **A single enclosing `Use Application/Browser` scope cannot span these** — Phases 3/4 sit in P4's `Try` while Phase 6 sits in its `Finally`, which are sibling blocks; hoisting a scope above the whole Try-Catch-Finally would launch the browser before Phase 2 and destroy the phase-swap rationale. So the browser must outlive its scope: either classic `Open Browser` with a `UiBrowser` variable, or `Use Application/Browser` in Phase 3 with **Close = Never** and a re-attaching scope in Phase 4. Exact mechanism to be confirmed; ties to R8's `browserLaunched`.
- **U8 — Concur "Act as" impersonation.** Selector for the Act-as field, how the switch is confirmed to have taken effect, and how admin context is cleanly restored between users. Carried over from the PA design. **Fallback:** navigate to a known admin URL to reset context between items.
- **U9 — Pending block matching.** How to uniquely match the correct pending block when a user has multiple cash advances — likely on request name/ID from the report, plus pending status. Carried over. **Fallback:** anchor on the request identifier text and assert pending status before clicking.
- **U10 — Submit confirmation.** Believed to be no popup on submit; success confirmed by the block leaving pending status or the Submit button disappearing. Unverified. **Fallback:** re-query the user's Cash Advances screen and assert the item is no longer pending.
- **U11 — Report is a full snapshot, not a delta.** *(Business/config assumption rather than platform, but the most load-bearing item in this doc.)* The **move-early** decision and the **backlog-drain** rule are safe **only** if Concur's scheduled report lists **all currently-open items** each send. If it is a delta of items created since the last send, a missed or failed item is lost permanently. **Fallback if delta:** move the message only after all its items have been processed successfully, and drop the backlog drain entirely. Confirm against the actual Concur report definition.
- **U12 — `Move Outlook Mail Message` semantics.** The single load-bearing mechanism of the folder-membership design. To confirm: target-folder path syntax for a nested subfolder, behavior when `ProcessedFolder` is absent, and per-message vs. batch move semantics on partial failure (what state the mailbox is in if a crash lands mid-drain). **Fallback:** ensure `ProcessedFolder` exists at **P7 step 0** (per U4 — the check needs Outlook up, so it belongs in Phase 2, not Phase 1); move one message at a time and tolerate a partial drain — the next run re-drains whatever is left, which is safe under U11's snapshot property.

## Lessons Learned

*(none yet — populated as live tests confirm or disprove assumptions. Note the PA Desktop L1/L2 entries in `pa-desktop-reference.md` explicitly do NOT carry over — see the banner at the top of this file.)*
