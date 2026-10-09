# UiPath Reference — Invoice Signature Verification Bot

> # ⛔ SUPERSEDED — NOT THE RULEBOOK
>
> **Decision D5 (2026-08-19) moved this project from UiPath to Power Automate Cloud.** The live rulebook
> is **`power-automate-reference.md`**. This file is retained as a historical record and as a standby.
>
> **Do not enforce these rules against the PA Cloud design.** R1–R2 (single `Main.xaml`, nested
> Sequences), R3 (Config.xlsx), R4 (Dictionary over DataTable), R8–R10 (the prologue, `Go to` avoidance,
> `Finally` cleanup) are UiPath constructs with no PA Cloud equivalent. Applying them to a cloud flow
> would be a defect, not a safeguard — exactly as `pa-desktop-reference.md` is to UiPath in
> `concur-cash-advance-bot/`.
>
> **What did carry over**, restated in `power-automate-reference.md` as its **R14–R17**: the isolation
> boundary and its output contract, byte integrity, no-date-arithmetic, and per-field code tables —
> properties of ETDA and of the problem, not of UiPath. This file's **R5** (Verb+Object naming) and
> **R7** (no credentials) also carry over, as template R13 and R6. This file's **R6** (Windows project)
> does not carry over at all. **R11**'s consecutive-failure counter carries over only in *intent*: its
> `Main`-scope realisation is void, replaced by a cross-run circuit breaker in
> `power-automate-reference.md` R18, because an event-driven trigger has no batch run to abort.
>
> **Why it is kept rather than deleted:** D5 depends on an unverified tenant DLP policy
> (`power-automate-reference.md` U1). If DLP blocks the HTTP connector, the design reverts here.


Source of truth for how this bot is built in UiPath. The `rpa-design-reviewer` agent checks the
design's **correctness** against this doc.

- Rules marked ✅ are **project-adopted conventions** (our own hard constraints — non-negotiable).
- Rules marked ⚠️ are **believed-but-unverified platform behavior** — treat with caution, flag inline in
  the design with a documented fallback, and confirm before/at build.

> **Status:** seeded 2026-08-18, immediately after decision **D2** settled the platform as UiPath.
> Thin by design — it will grow as the high- and medium-level designs land. It currently records the
> repo-wide constraints, the packages this project's API integration forces, and the unverified
> behaviours that integration depends on.

> **Companion doc:** `teda-validation-api-reference.md` describes the **external service**. It is
> platform-independent and stays authoritative on ETDA's behaviour; this file governs how *our bot* is
> built. Where the two touch — the isolation boundary, the digest, the polling loop — this file records
> the UiPath realisation and defers to the other for what ETDA does.

## Platform hard constraints (✅ project-adopted)

- **R1 — Linear Sequences only.** Everything is nested `Sequence` containers. No Flowchart, no State
  Machine, no REFramework.
- **R2 — Single Main.xaml.** No `Invoke Workflow File`; no splitting into separate `.xaml`. All logic
  lives in `Main.xaml`, organised by named `Sequence` containers as logical sections. A **project
  convention mandated by the `rpa-bot-dev` skill**, not a platform limitation.
- **R3 — Config.xlsx at startup.** A `Config.xlsx` (Name/Value columns, sheet "Config") is read once
  into `configDict`. No environment value is hardcoded. Keys known so far — this table will grow, and
  several entries depend on still-open questions:

  | Key | Purpose | Source |
  |---|---|---|
  | `TedaBaseUrl` | ETDA API host. ❓ Production value unknown — UAT is `https://api-uat.teda.th` | ETDA q1 |
  | `TedaApiKey` | The `apikey` header value. ⚠️ **Provisional row — R7 governs, and Config placement is a Q13 decision rather than an assumption.** An Orchestrator asset or Windows Credential Manager may well be preferred to a plaintext Config cell | Q13 |
  | `PollIntervalSeconds` | `P2002` poll gap — proposed **5** | Q8 |
  | `PollTimeoutSeconds` | Overall poll ceiling — proposed **300** | Q8 |
  | `TransientRetryCount` | `P1999`/`P2999`/HTTP 5xx/**`429`** — proposed **3 retries after the initial call** (4 calls total) | Q8 |
  | `TransientRetryBackoffSeconds` | Delimited backoff sequence — proposed **`5,30,120`**. Keyed rather than hardcoded, per this rule's own "no environment value is hardcoded" | Q8 |
  | *(throttle key)* | ⚠️ **None carried yet.** ETDA documents no rate limit and question 2 is unanswered; at ~10 invoices/week (Q6) throttling is unlikely. Fallback: if ETDA states a limit, add a key then rather than inventing one now | ETDA q2 |
  | `E0001RetryCount` / `E0001RetryDelayMinutes` | Warning-retry schedule — proposed **3** / **10** | Q8 |
  | `ConsecutiveFailureAbort` | Run-abort threshold — proposed **5 invoices** (per-invoice, not per call — see R11) | Q8 |
  | `MaxPdfBytes` / `MaxXmlBytes` | Pre-flight size gates — **20971520** / **3145728** | D3 |
  | *(mailbox keys)* | Folder(s), sender/subject rule — **pending Q4** | Q4 |
  | *(output keys)* | **Pending Q5**, which is undecided | Q5 |

  `configPath` itself is **not** a Config key — it can't be, since it's what locates Config. It is a
  project-relative constant, the one permitted hardcoded path.

- **R4 — Dictionary for structured data.** `Dictionary(Of String, String)` / `(Of String, Object)`.
  `DataTable` is permitted **only** for genuine tabular row iteration — the config read, and any
  tabular output Q5 turns out to require.
- **R5 — Verb + Object naming.** Every activity and Sequence `DisplayName` ("Read Config File",
  "Compute File Digest", "Submit File For Validation").
- **R6 — Windows project.** Target UiPath **Windows** project; VB.NET expressions.
- **R7 — No credentials in the design.** The ETDA `apikey` is never written into the workflow or into
  these docs. See Q13.

## Control-flow and guard rules (✅ project-adopted)

Adopted from `concur-cash-advance-bot`, which had two live silent-failure bugs from getting these wrong.

- **R8 — Prologue: guards and state initialised before the outer Try.** Any cleanup or reporting that
  runs from `Finally` executes on paths where earlier phases never ran, so it must assume nothing. Every
  guard flag and accumulator is initialised in a `Sequence` at the top of `Main` that **precedes** the
  outer Try — not inside phase 1.

  ⚠️ The two traps this exists for, both of which have bitten the sibling project: a UiPath `Boolean`
  with no Default is **`False`** (so an uninitialised `runShouldContinue` means the bot silently does
  nothing while reporting success), and a `DataTable` with no Default is **`Nothing`** (so appending to
  it throws — inside `Finally`, where it destroys the real exception).

- **R9 — No `Go to`.** UiPath has no equivalent and none is to be invented. Early exits use a guard
  boolean initialised in the R8 prologue, with later phases wrapped in `If`. Fatal paths `Throw` and are
  caught by the outer Catch.
- **R10 — Cleanup runs from `Finally`**, with each step guarded on a flag recording whether the thing it
  cleans up was ever created, and each step in its own inner Try-Catch that logs and swallows — so a
  cleanup failure cannot replace the real exception.

## Project-specific rules (✅ project-adopted)

- **R11 — The validation call is one isolated Sequence.** Decision **D1**'s binding constraint. Realised
  as a named `Sequence` (R2 forbids a separate workflow file), whose output contract is the **minimum**
  set in implication 1 of the service reference doc — outcome-or-business-exception, disposition,
  run-fatality flag, per-signature entries, transaction identifiers. Later phases **widen that contract
  rather than bypass it**. **Nothing outside the Sequence parses ETDA JSON or reads an HTTP status
  code.**

  ⚠️ **The consecutive-failure counter is `Main`-scope, initialised in the R8 prologue** — *not* a
  variable declared inside the isolation Sequence. A Sequence-scoped variable re-initialises on every
  entry, so inside a per-invoice loop it would reset to 0 on each call and the abort threshold
  (proposed 5, Q8) **could never be reached** — the run-abort safeguard would silently never fire. This
  is R8's uninitialised-state trap wearing a different hat. The Sequence is its **only writer**; callers
  read the run-fatality flag, never the counter, and never derive either from HTTP codes.
  Fallback: if a later phase needs the count for reporting, pass it out through the contract.

  ⚠️ **Counting unit: one increment per _invoice_, not per HTTP call.** With `TransientRetryCount` = 3
  an invoice can consume four calls, so a per-call counter would hit a threshold of 5 partway through
  the *second* invoice — and Q8's rationale for choosing 5 is explicitly per-item. Count invoices.

  ⚠️ **Increment / reset — get both halves right, or the safeguard silently does nothing.**

  | The invoice ended as… | Counter |
  |---|---|
  | a **verdict** — Trusted, Untrusted, Warning, No supported signature | **reset to 0** |
  | a verify-stage business exception — `P1001`, `P1003` | **reset to 0** *(ETDA answered; the file was the problem)* |
  | **Could not check** — exhausted transient retries (`P1999`/`P2999`/5xx/`429`/timeout), `N9999`, `P2001`/`P2003`/`P2004`, exhausted `E0001`, `P1002`/`P1004`/`P1005`, unrecognised `signatureCode`, `N0001`-on-PDF, transport/auth failure | **increment** *(except HTTP `400` — see the clustered-`400` note below)* |

  Two failure modes, and both have already been written into this doc and corrected:

  - **No reset at all** → the counter is cumulative, so five failures scattered across an otherwise
    healthy fifty-invoice run abort a run that was working.
  - **Reset on "any outcome"** → *Could not check* **is** one of the five outcomes, so an ETDA outage
    that fails every single invoice would reset the counter every time and the abort could **never
    fire** — in precisely the scenario Q8 created it for.

  Fallback: if a run legitimately mixes many *Could not check* results with successes, raise the
  threshold rather than loosening the reset rule.

  ⚠️ **Clustered `400`s are counted separately.** A `400` is an our-bot request defect (service reference,
  "HTTP and authentication failures"), not a transient ETDA failure, so it does not belong in the counter
  above — but clustering is what distinguishes "one odd file" from "the contract changed". Fallback: a
  second counter with the same reset discipline; its threshold is part of Q8 and is not yet chosen, so
  until it is, log the clustering and do not abort on it.
- **R12 — Byte integrity is absolute.** The attachment is saved byte-for-byte, hashed as that exact byte
  stream, and uploaded as that same stream. **No activity may re-save, re-render, normalise or
  round-trip the file.** Implication 2 of the service reference: a re-saved PDF produces either a digest
  mismatch or a genuine `E0002` *"document was modified after signing"* — our own bot manufacturing
  evidence of tampering against an innocent supplier.

  ✅ **Applies identically to XML now that D3 is in force** — re-serialising an XML document (re-indenting,
  changing encoding declarations, normalising namespace prefixes) breaks XMLDSig exactly as re-saving
  breaks a PDF signature, and is *easier* to do accidentally, since XML invites parse-then-write handling
  in a way a PDF does not. Read and forward the bytes; never load into an XML object model on the path to
  ETDA.

  ⚠️ **The same risk exists upstream, outside our control:** mail gateways and AV scanners that rewrite
  attachments break signatures before the bot ever sees the file. Fallback: if `E0002` appears at an
  implausible rate on first run, **suspect the mail path before suspecting the suppliers**.
- **R13 — The verdict never comes from date arithmetic.** `certExpireDate` and `certBeginDate` are
  recorded for the audit trail only. The outcome is derived from `signatureCode`. See trap 1.
- **R14 — Each ETDA code field is read against its own table.** No shared code-mapping step. See trap 4
  — `E0002` means "document modified after signing" in one table and "Not LTA" in another, so one shared
  mapper turns an unremarkable fact into a tampering alert.

  ⚠️ R2 bans separate workflows, and there is no reusable expression-level function inside `Main.xaml`
  without `Invoke Code` (see U1's fallback, which does use it). So the permitted realisation is **one `Dictionary(Of String, String)` per code field**,
  loaded in the R8 prologue (`signatureCodeMap`, `ltvCodeMap`, `signatureTypeCodeMap`, …), or a per-field
  `Switch`. Sequence `DisplayName`s follow R5 spacing — "Map Signature Code", not `MapSignatureCode`.
  Fallback: if the maps prove unwieldy in the prologue, they may be built in phase 1 **provided** no
  `Finally`-path step reads them (R8).

## Packages (expected)

- `UiPath.System.Activities` — core (Assign, If, Try Catch, Delay, Log Message).
- `UiPath.WebAPI.Activities` — **`HTTP Request`** for both ETDA endpoints, and **`Deserialize JSON`**
  (which ships here, not in System). ⚠️ See U1, U2, U5.
- `UiPath.Cryptography.Activities` — **SHA-256 file digest**, confirmed mandatory by the API's required
  `digest` parameter (D2). ⚠️ See U3.
- `UiPath.Mail.Activities` — Outlook desktop retrieval (Q4). ⚠️ See U4.
- `UiPath.Excel.Activities` — Config read; and output, if Q5 lands on a spreadsheet.

## Unverified platform behaviors (⚠️ — confirm before build)

- **U1 — `HTTP Request` multipart file upload.** The Verify endpoint needs `multipart/form-data` with a
  **file part plus a text part** (`digest`) in one request. Whether the classic `HTTP Request` activity
  expresses this cleanly — and whether it streams the file rather than loading and re-encoding it — is
  **load-bearing for R12**. **Fallback:** if the activity cannot send raw bytes faithfully, use an
  `Invoke Code` step with `HttpClient`/`MultipartFormDataContent`, which is still inside `Main.xaml` and
  so does not breach R2.
- **U2 — `HTTP Request` behaviour on non-2xx.** Whether it throws or returns the status code and body
  decides how R11's run-fatality flag is computed, and the design needs the **body** on a 4xx (the auth
  errors return `{"message": ...}` rather than a `ResultCode`). **Fallback:** wrap in Try-Catch and
  extract status/body from the exception if the activity throws rather than returning.
- **U3 — SHA-256 output encoding.** ETDA requires **lowercase hexadecimal**. UiPath's hashing activities
  commonly return Base64 or uppercase hex. Getting this wrong yields `P1002` and nothing else — there is
  no other feedback. **Fallback:** normalise explicitly to lowercase hex rather than trusting the
  default, and assert the expected digest against a known file during testing.
- **U4 — Classic Outlook activities under an unattended robot.** *Carried forward from
  `concur-cash-advance-bot` U1, where it is the same load-bearing risk.* `UiPath.Mail.Activities`' Outlook
  activities drive Outlook through Interop/MAPI, requiring Outlook installed with a **loaded mail profile
  in an interactive Windows session**. An unattended robot in a session-0 context is the classic failure.
  ⚠️ **This partially undercuts D1's leading argument** — the API lets the *validation* run headless, but
  if the *mail* side needs an interactive session, the deployment is interactive anyway. D1 still stands
  on its other four reasons. **Fallback:** Microsoft 365 / Graph activities against a service mailbox
  (changes the auth story, needs an app registration), or IMAP. **Decide before Phase 2 fixes the
  deployment model.**
- **U5 — `Deserialize JSON` over the ETDA result.** The result nests arrays (`pdfDigitalSignatureResult`
  0–5, each with a nested `embedTimestampResult`) and the 2022 spec is known to lag the live service, so
  **unexpected extra fields must not break parsing**. **Fallback:** deserialize to `JObject` and navigate
  defensively with `SelectToken`, rather than binding to a fixed type.
- **U6 — Timer accuracy for the `E0001` retry window.** The proposed schedule is **3 retries after the
  initial call, at +10 / +20 / +30 minutes** — a 30-minute window, 4 calls total (Q8). A `Delay` holding a robot idle for 30 minutes is wasteful and may collide with schedule
  windows. **Fallback:** re-queue the item for a later run rather than sleeping in-process — which
  interacts with Q5 and Q12 (an item awaiting retry must not look like a fresh arrival, nor like a
  finished one).

## Lessons Learned

*(None yet — this project has had no live runs. Entries land here when a real test result overturns an
assumption, per repo `CLAUDE.md`.)*
