# Power Automate (Cloud) Reference — Invoice Signature Verification Bot

Source of truth for how this bot is built in **PA Cloud**. The `rpa-design-reviewer` agent checks the
design's **correctness** against this doc **and** against `templates/power-automate-reference.md`.

- Rules marked ✅ are **project-adopted conventions** (hard constraints — non-negotiable).
- Rules marked ⚠️ are **believed-but-unverified platform behavior** — flag inline in the design with a
  documented fallback, and confirm before/at build.
- Findings marked 🔬 are **verified platform behaviours** inherited from the template.

> **Status:** seeded 2026-08-19 (decision **D5**); restructured 2026-08-20 after review.

## How this file relates to the template

`templates/power-automate-reference.md` is the canonical PA Cloud rulebook. **Its ✅ R1–R13 are adopted
in full by this project** — they are not restated here. This file adds only what is specific to *this*
bot, and records the choices the template requires each project to make.

**Rule numbering is contiguous across the two files: the template owns R1–R13, this project starts at
R14.** That is a collision *guard* only. ⚠️ **It does not license bare cross-file IDs** — repo
`CLAUDE.md` and the template both state that a bare cross-file rule ID is a review finding, and they
win. An earlier draft of this file claimed contiguity made bare IDs safe; that licence produced a wrong
citation within the same session. **Always write `<file> R<n>`.**

⚠️ **Unverified-item prefixes differ**: repo `CLAUDE.md` specifies `U`-numbers, the template uses
`P1–P6`. This file uses `U`, per `CLAUDE.md`. Fallback: always qualify across files — `P3` and `U3` are
unrelated.

**Reconciliation history.** This rulebook predates the template. Three of its rules were promoted upward
and are now template R11 (Solution), R12 (concurrency), and R13 (default action names banned). The
template's 🔬 V1–V5 (plus ⚠️ V6–V7, template-asserted rather than trial-verified) were absorbed downward
on 2026-08-20 and appear below with this project's consequences — the template's §2 remains the
canonical statement of *what was observed (or asserted)*; the section here says only *what it means for
this flow*.

> **Companion doc:** `teda-validation-api-reference.md` describes the **external service**. Its substance
> is unchanged by D5 and it stays authoritative on ETDA's behaviour. This file governs how *our flow* is
> built.
>
> **Superseded:** `uipath-reference.md` — banner-marked, retained as the fallback rulebook if D5's DLP
> or Azure checks fail.

## The shape of the solution

```
Office 365 Outlook trigger  ──►  PA Cloud flow  ──►  Azure Function  ──►  ETDA API
   (one email per run)           orchestration,      one submit+poll     verify → poll
                                 waits, retries,     cycle only          (bounded)
                                 breaker, output
                                 — per attachment,
                                   see below
```

The **Azure Function is decision D1's isolation boundary** made concrete: it hashes the file, calls
ETDA, and returns the contract in implication 1 of the service reference. The flow never sees ETDA JSON
or an HTTP status code.

⚠️ **The trigger is per email, but the unit this design's breaker/park/bound rules operate on is per
attachment, not per email.** `PROGRESS.md` Q4 — "can one email carry several attachments" — is still
open; the parked-queue key (message ID **+ attachment ID**, R18) and U7's idempotency key already assume
an email can carry more than one invoice, and are only correct under that assumption. **This design
treats "a run" as one email, iterating an `Apply to each` over its attachments, and treats every
breaker increment, park, `MaxReCalls`/`MaxValidationWaitMinutes` bound, and companion-flow re-submission
as scoped to one attachment**, not to the email as a whole — a bad or malicious 5-attachment email
increments the breaker once per bad attachment, and one failing attachment must not block the others in
the same email from validating and reporting normally. Wherever "invoice" appears below, read it as "one
attachment within the triggering email"; wherever "run" appears, read it as "the flow instance triggered
by one email, which may process several invoices." Settle Q4 before Phase 2 — if it resolves to
"exactly one invoice per email", this note and the per-attachment iteration collapse to the simpler
one-email-one-invoice case with no design change needed elsewhere.

⚠️ **Why a Function at all:** PA Cloud has **no SHA-256** — no expression, no standard action — and
ETDA's `digest` is mandatory (`P1005` absent, `P1002` wrong). Fallback options in order of preference:
(1) Azure Function; (2) an inline-code action, if licensing permits and it handles binary — unverified,
U6; (3) a third-party hashing connector — **rejected on data-protection grounds**, since hashing means
handing the invoice bytes to a stranger, a worse version of what Q9 already scrutinises.

## Template rules — adoption and required choices

| Template rule | This project's choice |
|---|---|
| **R5** — config source, *"state which applies and why"* | ⚠️ **Undecided, gated on U8 — and U8's evidence is about the wrong environment.** `flowagent-trial/` **indicated** that PTTEP **Default** has no Dataverse, but repo `CLAUDE.md` forbids building this flow in Default at all; this project's actual **build environment is not yet named** (a dedicated Developer/sandbox environment, per the same constraint the trial itself hit and worked around). The trial's finding is suggestive — Developer environments commonly lack Dataverse too — but not evidence about the environment this flow will actually run in. Fallback, and the likely outcome: a **config SharePoint list**, read once at flow start into one object variable. Settle before Phase 2, and name the target environment first. |
| **R11** — build inside a Solution | ⚠️ **Conditional on the same finding, with the same caveat** — Dataverse availability must be checked in the *actual* build environment once named, not inferred from PTTEP Default. Fallback: unsolutioned flow plus the config list above, accepting that moving between environments becomes manual. |
| **R12** — trigger concurrency | ✅ **Concurrency 1.** At ~10 invoices/week throughput is irrelevant, and serial execution is what makes R18's cross-run counter meaningful. ⚠️ One-way door on some triggers — set at build time. |
| **R9** — created `Stopped` | ✅ Adopted as written. |
| **R3** — Try/Catch/Finally Scopes | ✅ Adopted, **including `is skipped` on the Catch Scope** — the template calls omitting it "the classic hole", and this flow has upstream steps (attachment fetch, config read) that can skip the Try Scope. |
| **R10** — run record from `Finally` | ✅ Adopted, and **load-bearing here** — see 🔬 V3. The run record is where the verdict, `TransactionID` and `TransactionDate` are written (implication 8, Q14). |
| **R6** — no secrets in the flow | ✅ Adopted absolutely. See R14 for where the ETDA key actually lives. |
| **R7** — WDL expressions | ✅ Adopted. VB.NET carried over from the superseded `uipath-reference.md` is a defect here. |
| **R1/R2/R13** — single flow, Scopes as sections, Verb+Object names | ✅ Adopted. ⚠️ **R1's scope is child flows within one process** — no "Run a Child Flow", no splitting this process across artifacts. A **separately-triggered monitoring/recovery flow is outside R1's scope**, not an exception to it; recorded as ⚠️ **D6 (provisional, not yet user-confirmed)** so the distinction is deliberate rather than assumed. |
| **R4** — `Terminate`, guard variable for early exit | ✅ Adopted. ⚠️ Note R18: `Terminate` ends *this* invoice's run, which under a per-email trigger is not a batch abort. |
| **R8** — existence check on expression-built targets | ✅ Adopted; see 🔬 V2 for why it matters at the output step. |

## Project-specific rules (✅ project-adopted)

- **R14 — The validation call is one isolated component: the Azure Function.** Decision **D1**. Its
  output contract is the **minimum** in implication 1 of the service reference — outcome or
  verify-stage business exception, disposition, run-fatality flag, per-signature entries, transaction
  identifiers. Later phases **widen the contract rather than bypass it**. The flow parses no ETDA JSON
  and reads no ETDA HTTP status code.

  **Widenings already sanctioned**, required by R18/R19. This rule is the home of the **output** contract,
  which R19 widens with `retryAfterSeconds`, `retryReason`, the **forward `retryStep`** to send on the
  next call, and a **failure-blame field** distinguishing ETDA-side failure from an our-bot request
  defect, so R18 can route the two to different counters without the flow inspecting an ETDA code; R18
  additionally widens the output with a **reachability result**, used only by the companion flow's untrip
  probe. R19 separately defines a distinct **input** contract for the poll-only/resubmit re-call path
  (`fileContent`, `fileName`, optional `transactionId`, `attemptCount`, `retryStep` + `retryStepReason`,
  `elapsedSeconds`), widened by R18 with a **probe-mode flag** for the same untrip probe — see R19 for the
  full shape of both.

  ⚠️ **How the flow authenticates to the Function is itself a `templates/power-automate-reference.md` R6
  question, not a detail to invent at build time.** The default HTTP-action pattern — a Function key
  appended to the trigger URL — puts that key in the flow definition, exactly what R6 forbids for the
  ETDA `apikey`. The design uses
  the **Azure Functions connector**, whose connection holds the key the same way any other connector
  connection holds its secret (⚠️ V6 applies: authorization is a per-connection human step). Function-level
  auth (Easy Auth / Entra ID, so the connector's own token suffices and no function key exists at all) is
  the preferred variant if the Function's hosting plan supports it; record which was actually used at
  Phase 6.

  **The ETDA `apikey` never reaches the flow at all.** It lives in the Function's own configuration —
  Key Vault referenced by the Function, or the Function's application settings, with a managed identity
  preferred over a stored secret. ⚠️ Under no circumstances a flow secure-input parameter: that puts the
  key in the flow definition, which template R6 and repo `CLAUDE.md` forbid outright. Since the Function
  owns the whole ETDA exchange, the flow has no need of the key.

- **R15 — Byte integrity is absolute.** *(Implication 2 of the service reference.)* The attachment
  reaches ETDA byte-for-byte; nothing may re-save, re-render, normalise, or round-trip it. A
  re-serialised file returns `E0002` — *"document was modified after signing"* — our own automation
  manufacturing evidence of tampering against a supplier. ⚠️ Applies identically to **XML** (D3):
  re-indenting or re-encoding breaks XMLDSig, and XML invites parse-then-write handling in a way PDFs do
  not. ⚠️ The same risk exists upstream in mail gateways and AV scanners — if `E0002` appears at an
  implausible rate, suspect the mail path before the suppliers. **Load-bearing on U3** — whether the
  Outlook connector's `Get attachment` output is byte-identical to the original is unverified, and R15
  has no protection against a connector-side alteration that happens before the Function ever sees the
  file.

- **R16 — The verdict never comes from date arithmetic.** *(Trap 1.)* `certExpireDate`/`certBeginDate`
  are recorded for audit only; the outcome derives from `signatureCode`. An expired certificate is
  `S0003` — **Trusted**.

- **R17 — Each ETDA code field is read against its own table.** *(Trap 4.)* No shared code map: `E0002`
  means "document modified after signing" in one table and "Not LTA" in another. Implemented in the
  Function as per-field lookups named for the field.

- **R18 — Failure counting is a cross-run circuit breaker, not a run-level abort.**

  ⚠️ **This replaces the batch-era design wholesale, and the reason matters.** Under UiPath the bot
  processed many invoices per run, so "abort the run after N consecutive failures" was a real safeguard.
  Under D5 the trigger fires **once per email** at concurrency 1, and — per "The shape of the solution"
  above — the counting unit throughout this rule is **one attachment/invoice**, not one email; a run may
  still contain several invoices if Q4 allows multiple attachments. "Abort the run" protects nothing
  either way, since aborting one email's processing doesn't stop the next email's invoices from hitting
  the same dead dependency, and a counter held in run scope or passed through the contract has nothing to
  carry forward into the next run regardless of how many invoices one run contains.

  | Aspect | Rule |
  |---|---|
  | **Where it lives** | A **durable state store outside the run** — one item in a state list. This is *state*, not configuration, and does not belong in the config source. Never a flow variable, never a contract round-trip. ⚠️ **The item must be seeded as a deployment step** (counter 0, tripped `false`) before the flow's first run — a missing item is the PA Cloud analogue of the uninitialized-variable class repo `CLAUDE.md` already warns about, and the flow reads it through `coalesce()` with an explicit default rather than trusting the item to exist. |
  | **Who reads and writes it** | **The flow.** It reads the breaker before calling and updates it after, keyed on the contract's **outcome and failure-blame fields**. ⚠️ This does not breach R14 — the flow reacts to a contract value, never to an ETDA code or HTTP status. The Function cannot own it: a Consumption Function is stateless between invocations (R19). |
  | **The Function itself doesn't answer** | ⚠️ **Distinct failure class, and the one the breaker must not miss.** A Function-side 5xx, a timeout, or a connector-level failure to invoke it at all returns **no contract** — no outcome, no failure-blame field, nothing to key an increment on. Treated as its own blame class (*Function-unreachable*, added to the "split by blame" enumeration below) on the **same counter as ETDA-side failures** — but counted the same way the Counting unit row below requires: **one increment per invoice**, taken once that invoice's validation attempt has given up (its `MaxReCalls`/`MaxValidationWaitMinutes` bound is reached, or the retry policy exhausts), never once per individual HTTP call, connector-level retry, or re-call. It never resets on its own — a reset only ever happens per the Reset row below (a verdict or a verify-stage business exception), which by definition cannot occur when there was no contract to read one from. Without this, a dead or misconfigured Function — arguably the single most likely outage, since it is a resource this project deploys and owns — produces **no contract to key a breaker on and therefore never trips**, silently parking nothing while every invoice quietly fails. |
  | **Counting unit** | One increment per **invoice**, not per HTTP call — this applies identically to the Function-unreachable row above: a single invoice's exhausted re-call attempts are one increment, not several. |
  | **Increment** | The invoice ended as *Could not check*. |
  | **Reset to 0** | The invoice ended as a **verdict** (Trusted / Untrusted / Warning / No supported signature) **or** a verify-stage business exception (`P1001`, `P1003`) — ETDA answered; the file was the problem. |
  | **Trip** | Either: at `BreakerTripThreshold` consecutive increments, **or immediately** when the contract's **run-fatality flag** is set — a revoked key or wrong URL will fail every subsequent invoice identically, so waiting for a count is pointless. |
  | **While tripped** | Each new run **parks its invoice durably without calling the Function** (and therefore never reaches ETDA), and raises the Q15 alert. A parked invoice is *pending*, never *failed*, never silently dropped. |
  | **Untrip** | A deliberate human action, or a scheduled probe that succeeds (companion flow, below). Never automatic on the next arrival. ⚠️ **Untrip must reset both counters to 0, not only clear the tripped flag** — clearing the flag alone leaves the count sitting at `BreakerTripThreshold`, so the very next increment re-trips immediately regardless of whether the underlying problem is actually fixed. |

  ⚠️ Both halves of the reset rule are load-bearing and each has been got wrong once already: omitting
  the reset makes it cumulative, so scattered failures trip it; resetting on *any* outcome makes it
  unreachable during an outage, because *Could not check* **is** an outcome.

  ⚠️ **Two counters, and the split is by blame, not by symptom.** *Could not check* covers **ETDA-side
  failures and Function-unreachable failures on one counter**, and our-bot/config defects on the other
  (`P1002`, `P1004`, `P1005`, HTTP `400`, and the run-fatal class as implication 1 defines it
  (`401`/`404`/`405`/undocumented 4xx, **excluding `429`/throttle**, which is transient) — which trip
  immediately rather than counting), and they need different responses — an ETDA or infrastructure
  outage clears itself, a malformed request does not. The contract must therefore distinguish ETDA
  failures from request defects (R14); a Function-unreachable failure is distinguishable without the
  contract at all, since there is no contract, so it always lands on the ETDA-side counter by
  construction. Fallback if the contract fails to distinguish an ETDA failure from a request defect: put
  **all** *Could not check* on the ETDA counter and accept that a request defect can trip it —
  over-tripping is the safe direction, since a tripped breaker parks rather than discards. The
  request-defect counter follows the **same reset discipline** as the ETDA one — reset on a verdict
  or a verify-stage business exception, increment on its own blame class. Its threshold is unchosen
  (Q8): until it is, **log the clustering and do not trip**.

  ⚠️ **What the parked queue stores matters.** It holds the **message ID and attachment ID**, not the
  file bytes — the companion flow re-fetches from Outlook when it drains. Storing bytes in a list means a
  round-trip through another connector, which is exactly the re-save R15 bans and would surface as a
  fabricated `E0002`. ⚠️ Draining therefore re-submits messages the main flow already consumed, so the
  drain path must honour Q12's duplicate rule and U7's idempotency key (message ID + attachment hash).
  ⚠️ The queue and the breaker store are each a connection-bearing dependency, inheriting ⚠️ V6 (human
  authorization) and ⚠️ V7 (~90-day expiry) — include them in the connection inventory. A connection is
  per-connector/identity, not per-list, so if both live in the same SharePoint site they may share one
  SharePoint connection; state which is actually the case once the site is chosen.

  ⚠️ **The park → drain → re-park cycle needs a bound**, or an invoice loops between them forever — the
  cross-run analogue of what `MaxReCalls` closes within a run. ✅ **`MaxParkAttempts` (proposed 3):** the
  *threshold* is flow config (Configuration ownership table); the *count itself* is per-item state that
  travels with the queue item and persists across drain attempts, incrementing each time that invoice is
  re-parked. Exhausting the threshold ends the invoice as *Could not check* / **Manual review**, alertable
  under Q15, and it leaves the parked queue. ⚠️ A drained invoice **restarts** its
  `MaxValidationWaitMinutes` clock — it is a fresh validation attempt, not a continuation — while its
  `MaxParkAttempts` count keeps accumulating with the queue item regardless.

  ⚠️ **Something must drain the parked queue.** A per-email trigger will **not** re-fire for a message
  it has already consumed, so an invoice parked while the breaker was tripped is stranded unless
  something goes back for it.

  **Companion flow — outside template R1's scope, recorded as ⚠️ D6 (provisional, not yet user-confirmed).**
  R1 bans splitting *one process*
  across flows via "Run a Child Flow". A **separately-triggered scheduled flow is a second, independent
  process**, so R1 does not reach it — and it cannot be folded into the main flow, because it must run
  precisely when **no** email has arrived, which is the ⚠️ V7 case the design has to detect. It does three things: assert the main flow has run recently
  (V7 heartbeat), probe **via the Function** to untrip the breaker — ⚠️ never ETDA directly, which would breach R14 and
  require the companion flow to hold the `apikey` — and **re-submit parked invoices**. ⚠️ Both ETDA
  endpoints are POSTs, so a reachability probe needs either a small canary file or a known-stale
  `transid` treated as *reachable* on `P2001` *(the transmitted label; `P2001` is named here for
  documentation only — no ETDA code crosses the boundary, exactly as R19's `revocation` row)*. This
  requires a **probe mode and reachability result**, added here as a further widening of implication 1's
  minimum contract alongside R18/R19's retry and blame fields (R14's "widen rather than bypass" clause):
  the companion flow calls the Function with a probe-mode flag, and the Function returns a plain
  reachable/unreachable result rather than any ETDA code. Fallback: if neither the canary nor the
  known-stale-`transid` approach is acceptable, untrip by hand only. Fallback: if a
  second flow is refused, the parked queue must be drained by hand and that must be written into the
  runbook, because nothing else will do it.

  ⚠️ Implication 1's **run-fatality flag** is reinterpreted the same way: under a per-email trigger,
  "fatal to the run" means *fatal to this invoice **and** trip the breaker* — there is no batch-level
  abort to perform. If the triggering email carries more than one attachment (Q4), the breaker being
  tripped by the first one is what stops the rest: subsequent attachments in the same `Apply to each`
  see the breaker already tripped and park without calling the Function, rather than each needing to
  hit the same fatal condition independently.

- **R19 — One Function invocation is one bounded submit-and-poll cycle.**

  ⚠️ **Consumption-plan Azure Functions have a hard execution ceiling** (documented as 5 minutes by
  default, 10 maximum — U9). The earlier draft of this design assumed otherwise: a 300-second poll
  ceiling sat exactly on the default limit, and the `E0001` retry schedule of +10/+20/+30 minutes
  **could not execute inside a Function invocation at all.**

  **The Function computes the schedule; the flow only waits.** This is what keeps R14's boundary intact —
  the flow must not know that an `E0001` warrants one delay and a `P1999` another. On any non-terminal
  result the Function returns disposition `Retry` **plus `retryAfterSeconds` and a `retryReason` label**,
  and the flow waits that long and calls back. No ETDA vocabulary crosses the boundary, and the retry
  schedules stay in Function configuration where the rest of the ETDA knowledge lives. `retryReason` is
  not decorative: it is written to the R10 run record and distinguishes "ETDA was slow" from "ETDA could
  not reach a revocation source" when Q15's alerting or a human reviews the case.

  | Wait | Owner |
  |---|---|
  | ETDA `P2002` polling within one attempt | **Function**, bounded at **90 s** |
  | Every other wait — `pending` re-call, `revocation` schedule, `transient-verify`/`transient-poll` backoff | **Flow.** ⚠️ **The Function never sleeps for backoff.** An earlier draft had it run the 5/30/120 s transient schedule internally on top of the 90 s poll bound — 90 + 5 + 30 + 120 = 245 s, close enough to U9's documented 300 s default ceiling to leave no safety margin once actual ETDA response time is added — reintroducing the exact collision R19 exists to remove. It polls, then returns. |

  ⚠️ **`retryReason` decides whether the re-call is a poll or a resubmit, and getting this wrong wastes
  every retry silently:**

  | `retryReason` | Re-call shape | Why |
  |---|---|---|
  | `pending` | **Poll-only** — send `transactionId`, no bytes | ETDA has the file and has not finished |
  | `revocation` *(the transmitted label; `E0001` is named here for documentation only — no ETDA code crosses the boundary)* | **Resubmit** — send bytes, **no** `transactionId`, `retryStep` incremented | ⚠️ **Inferred, not documented:** an `E0001` transaction looks **terminal**, so re-polling it would return `E0001` forever and burn all three retries without re-checking. Fallback: resubmitting is safe whichever way it turns out, costing one extra `TransactionID`. Worth confirming — ETDA question 10. |
  | `transient-verify` *(the submission itself failed — no transaction exists yet)* | **Resubmit** — no transaction exists yet | Distinct label from `transient-poll`, precisely so the flow never has to infer the stage from `transactionId` presence — implication 1 already warns `TransactionID` can appear on a failure response, so its presence/absence is not a safe discriminator. |
  | `transient-poll` *(`P2999`, 5xx, `429` on `/result`)* | **Poll-only** — send `transactionId` | ⚠️ A live transaction already exists. Resubmitting would discard it and mint a second `TransactionID` against implication 8 / Q14. The 5/30/120 s backoff is flow-side, so it cannot run inside the 90 s Function bound anyway. |

  ⚠️ **`transient-verify` and `transient-poll` are two distinct `retryReason` values, not one `transient`
  label read differently by stage.** An earlier draft used a single `transient` label and distinguished
  the two cases only in prose — unactionable by the flow, since nothing in the contract itself carries
  which stage failed. Splitting the label is what actually lets the flow branch correctly without
  inspecting an ETDA code.

  ⚠️ **A resubmit needs the bytes again.** The flow does **not** hold them across a wait of up to 30
  minutes — it re-fetches from Outlook by message ID and attachment ID, the same mechanism the parked
  queue uses (R18) and for the same R15 reason: nothing is re-saved anywhere.

  ⚠️ **`retryStep` is per-`retryReason` and resets when the reason changes — and a stateless Function
  cannot enforce that rule unless the flow hands back which reason the step count belongs to.** An
  earlier draft had the flow track and increment `retryStep` on its own, which cannot work: the flow
  chooses the `retryStep` to send *before* it knows what the next `retryReason` will be, so the first
  `revocation` after several `pending` re-calls would arrive at the Function carrying step 4+ of a
  3-step schedule — silently burning the revocation retries, the exact defect this rule exists to
  prevent, just moved one level down. **Fix: the flow never decides `retryStep` — it only echoes what the
  Function last told it.** The Function's output, alongside `retryReason`, includes the **`retryStep` to
  send on the next call** (call it forward, not computed by the flow); the flow's *input* contract then
  carries that same `retryStep` back **plus the `retryReason` it was paired with** (as `retryStepReason`).
  On each call the Function compares its own newly-determined reason against the incoming
  `retryStepReason`: same reason → increment; changed reason → reset to 1. The flow never applies the
  reset rule itself — it is pure pass-through of two opaque values, which is what keeps the logic inside
  R14's boundary rather than leaking ETDA-shaped retry semantics into the flow.

  ⚠️ **The revocation schedule is successive delays of 10 minutes, not absolute offsets from first
  submission.** Absolute offsets cannot be computed by a stateless Function: `retryStep` alone does not
  give elapsed time, and `elapsedSeconds` is contaminated by poll duration and preceding waits, which is
  exactly why it was demoted to a logging hint. Three successive 10-minute delays total the same 30
  minutes and are computable from `retryStep` alone. Fallback: if the absolute-offset behaviour is ever
  genuinely wanted, `elapsedSeconds` must be re-promoted to load-bearing and its contamination handled.

  ⚠️ A resubmit creates a
  **second `TransactionID`**; **persist every one with its `TransactionDate`** (implication 8, Q14),
  newest authoritative, earlier ones kept so an ETDA support query about any attempt can be answered.

  ⚠️ **The re-call loop needs a bound, or an invoice sits in it forever** — exactly the failure
  implication 4 and trap 3 exist to prevent. Two flow-owned bounds, both adopted:

  - **`MaxValidationWaitMinutes`** (proposed **45**) caps total elapsed time across all invocations. It
    covers the 30-minute revocation window plus poll time and slack.
  - **`MaxReCalls`** (proposed **20**) caps the *number* of re-calls, guarding against a Function fault
    returning `retryAfterSeconds: 0` in a loop.

  Exhausting **either** ends the invoice identically: outcome *Could not check*, disposition *Manual
  review*, and alertable under Q15.

  **Function input contract** — required by the poll-only path, and defined here because implication 1
  specifies only the output: `fileContent` (bytes) and `fileName` — **present on the initial submit and
  on a resubmit re-call (`revocation`, `transient-verify`); omitted entirely on a poll-only re-call**,
  matching the re-call table above — optional **`transactionId`** (present means poll-only — do not
  resubmit, and do not send bytes alongside it), **`attemptCount`**, **`retryStep`** paired with
  **`retryStepReason`** (see below — together they let a stateless Function apply the per-reason reset
  rule), a **probe-mode flag** (present only on the companion flow's untrip probe — see R18), and
  **`elapsedSeconds`**. Sending a ~28 MB base64 payload (U12) on every one of up to 20 poll-only re-calls
  is exactly what the resubmit/poll-only split exists to prevent. ⚠️ **`attemptCount`/`retryStep` are
  load-bearing for a *stateless* Function** — they are how it knows which retry step it is on, since it
  remembers nothing between invocations. An earlier draft tried to derive that from `elapsedSeconds`,
  which cannot work: elapsed time is contaminated by poll duration and by any preceding revocation wait.
  `elapsedSeconds` is now only a hint for logging — **the overall ceiling is enforced flow-side only, and
  the Function is never told it and never self-limits from it.** Fallback: if the Function ever needs to
  self-limit, pass a `remainingSeconds` budget explicitly rather than deriving anything from
  `elapsedSeconds` or the ceiling. ⚠️ `retryAfterSeconds` / `retryReason` / the **forward `retryStep`
  to send on the next call** / `transactionId` are a **widening of implication 1's minimum output
  contract**; the companion flow's **reachability result** is the same output contract's other widening.
  Both are sanctioned by R14's "widen rather than bypass" clause and recorded there.

  Fallback if the flow proves a poor host for long waits (U5): a **Durable Function** orchestration,
  exempt from the per-invocation ceiling. Larger build; not the default.

## Verified platform behaviours (🔬, plus V6/V7 which are ⚠️ — inherited from the template)

Canonically recorded in `templates/power-automate-reference.md` §2. Repeated here only for what each
means *for this flow*.

⚠️ **Attribution:** V1–V5 were observed directly in `flowagent-trial/`; **V6 and V7 were not exercised
there** and rest on the template's own sources. Treat them as template-asserted rather than
trial-verified, and confirm V7 before relying on the mitigation it drives.

- **⚠️ V7 — connections expire after ~90 days idle.** ⚠️ **The most dangerous one here.** If the Office
  365 Outlook connection dies, **the trigger stops firing**: invoices arrive, nothing runs, no run
  appears in history. The connection shows `Error` status in the connections list, but **nothing
  proactively alerts**. It is indistinguishable from a quiet week, and this bot has quiet weeks by
  design (~10/week, Q6). Production traffic should keep it alive; a **UAT flow will certainly sit idle**
  between test rounds. Fallback, in order: poll connection status if reachable; otherwise a scheduled
  heartbeat asserting the flow has run recently, or periodic reconciliation of invoices received against
  invoices validated. **Monitoring that watches only failed runs cannot see this** — see Q15.
- **🔬 V2 — `Create file` creates missing folders instead of failing.** A drifted path expression does
  not 404; the connector creates the tree, writes, and reports success. ⚠️ Directly relevant once **Q5**
  picks an output target: a computed output path would write verdicts somewhere nobody looks while every
  run stays green. Template R8 is the general rule; the concrete guidance here is to write to a fixed
  container — a SharePoint **list**, not a computed folder path. ⚠️ The trial exercised **OneDrive**
  only; extending it to SharePoint is our inference, in the conservative direction.
- **🔬 V3 — succeeded runs expose no action inputs or outputs.** ⚠️ For this project that is the failure
  mode that matters most: **a wrong verdict is a green run.** Mitigated by template R10's run record —
  the verdict, `TransactionID` and `TransactionDate` are written while the flow runs, not recovered
  afterwards. Fallback: spot-check outcomes against the ETDA portal by hand during acceptance.
- **🔬 V4 — property selection on a scalar fails only at runtime.** Save-time validation does not
  type-check. ⚠️ The flow's main parsing job is reading the Function's contract, so that is where it
  would bite. **R14 already limits the exposure** — the Function returns a flat named contract rather
  than raw ETDA JSON. Keep it that way; every field the flow digs into is a runtime fault waiting for an
  unusual response.
- **🔬 V1 — the write API rejects fields the read API returns** (`extra-authentication`). A naive
  read → edit → write round-trip of a flow definition fails. ⚠️ Concerns how this is built and
  maintained, not its runtime. Fallback: always `preflight_flow` before a write.
- **⚠️ V6 — connection authorization is per-connection and human.** Cannot be automated; a flow created
  or imported with an unauthorised connection sits broken until a person acts. Ties to Q13 and to any
  environment move. Fallback: record the connection owner explicitly — if that person leaves, the flow
  stops.
- **🔬 V5 — failed runs are diagnosable in full**, including the offending expression verbatim. The good
  news, and the reason V3 and V7 are the ones to design around: loud failures look after themselves.

## Configuration ownership

⚠️ **Clarification of template R5, not a divergence from it.** R5 mandates *one* config source read
once at flow start **for the flow**, and this design satisfies that. Two other components — the
Function's own configuration and the breaker's durable state store — sit outside R5's scope entirely
rather than breaching it, and the split must be stated rather than discovered:

- **The flow has exactly one config source** — template R5 satisfied. Mechanism gated on U8.
- **The Function has its own configuration.** That is a separate deployed component with its own
  lifecycle, not a second config store for the flow. R14 requires ETDA knowledge to live behind the
  boundary, so ETDA's host, key, poll bound and retry schedules belong there — putting them in flow
  config would leak exactly what R14 exists to contain.
- **The breaker store holds state, not configuration** — a counter and a flag, written at runtime.
  Thresholds are *config* and live in the flow's config source; only the mutable state lives here.

| Setting | Home |
|---|---|
| `TedaBaseUrl`, ETDA `apikey`, per-attempt poll bound (90 s) and poll interval (5 s), transient backoff, `E0001` schedule (3 × 10 min successive delays), `pending` re-call wait (proposed **30 s**) | **Function** config — app settings / Key Vault. The flow neither holds nor needs these; under R19 the Function returns each as `retryAfterSeconds` and the flow just waits. |
| `MaxValidationWaitMinutes` (overall cross-invocation ceiling, proposed **45**) and `MaxReCalls` (proposed **20**, a guard against a Function fault returning `retryAfterSeconds: 0`) | **Flow** config — the flow's own safety bounds, not ETDA parameters. |
| Parked-invoice queue (message ID + attachment ID, per-item park count) | **Durable state store.** |
| `BreakerTripThreshold` (proposed **5 invoices**), request-defect threshold (unchosen, Q8), `MaxParkAttempts` (proposed **3**) | **Flow** config — thresholds are configuration. |
| Breaker counter, request-defect counter, tripped flag | **Durable state store** (R18) — runtime state, read and written by the flow. |
| `MaxPdfBytes` / `MaxXmlBytes` (**20971520** / **3145728**) | **Function**. ⚠️ Considered for the flow to avoid a pointless call, but `P1003` is authoritative anyway and Function-side keeps every ETDA limit behind R14. |
| Mailbox folder / recognition rule (Q4), output target (Q5) | **Flow** config. |

## Unverified platform behaviors (⚠️ — confirm before build)

- **U1 — Tenant DLP permitting the HTTP (or Azure Functions) connector to an external host.** ⚠️ **The
  single most likely thing to stop this design**, and one of D5's two gating checks. Fallback: the Azure
  Functions connector may be classified differently from raw HTTP; if both are blocked, D5 is
  unbuildable and the project reverts to `uipath-reference.md`. **Test cheaply — throwaway flow, HTTP
  action, try to save it.**
- **U2 — `$multipart` byte fidelity for signed files.** ⚠️ Largely moot under R19, since the Function
  performs the multipart call in ordinary testable code. Retained because it would matter if the call
  ever moved back into the flow.
- **U3 — Attachment content fidelity from the Outlook connector.** `Get Attachment (V2)` returns base64.
  Whether that is the exact original byte stream — for signed PDFs, and for XML with a specific encoding
  declaration — is unverified and **load-bearing for R15**. Fallback: hash the same file locally and
  compare against the hash computed from the connector's output; a mismatch means the connector or the
  mail path altered it.
- **U4 — Azure Function deployability.** Needs a subscription and deploy rights. D5's second gating
  check. Cost is not the barrier (~43 *invoices*/month, each possibly several invocations — still far inside the free grant).
- **U5 — Long waits held in the flow.** R19 moves the long *waits* into the flow; the **schedule itself
  stays in Function config** (the Function returns `retryAfterSeconds`). ⚠️ Combined with
  concurrency 1 (template R12) this **serialises arriving invoices behind a sleeping run** — tolerable at
  ~10/week, but it is an interaction between two adopted rules rather than a free choice. Fallback:
  re-trigger the item later instead of sleeping in-run, which interacts with Q12 — an item awaiting retry
  must look neither like a fresh arrival nor like a finished one.
- **U6 — Inline-code action for hashing.** Only relevant if U4 fails. Licensing-gated, unproven with
  binary input. Fallback: do not design around it; last resort only.
- **U7 — Trigger duplicate-delivery semantics.** Whether the Outlook trigger can fire twice for one
  message, and how that interacts with Q12. Fallback: key idempotency on message ID plus attachment hash,
  not on trigger identity.
- **U8 — Solution and Dataverse availability in the target environment.** ⚠️ **The target environment
  itself is not yet named.** `flowagent-trial/` **indicated** PTTEP **Default** has no Dataverse — the
  trial itself says only "consistent with", and left it unverified — but repo `CLAUDE.md` forbids
  building this flow in Default, so that finding is evidence about an environment this project must not
  use, not about the dedicated Developer/sandbox environment this flow actually needs. Until that
  environment is created and named, template R11 (Solution) and template R5's environment-variable
  option are both unresolved, not merely unavailable. ⚠️ Decides the config mechanism; not yet settled.
  Fallback: config SharePoint list read once at flow start, which works regardless of Dataverse.
- **U9 — Azure Function execution-duration ceiling.** Consumption plan is documented as 5 minutes by
  default, 10 maximum. ⚠️ **R19 is built entirely around this limit** — confirm it for the plan actually
  used before fixing the poll bound. Fallback: Durable Function orchestration, exempt but a larger build.
- **U10 — Does the Outlook trigger re-fire for a message *moved* into the watched folder?** If it
  does, the parked-queue drain can simply move a message back and let the main flow re-process it,
  leaving the D6 companion flow with **no validation path at all** — the cleaner shape. ⚠️ Likely not,
  since "when a new email arrives" fires on arrival rather than folder membership. Fallback, and the
  adopted design until this is tested: the drain re-enters the same Function contract itself (D6).
- **U11 — Is the Outlook message ID stable across a folder move and over time?** Both the parked-queue
  re-fetch (after up to 30 minutes, or longer while parked) and U10's move-the-message option assume it
  is, and U7's idempotency key rests on it too. ⚠️ Unverified. Fallback: key on the **internet message
  ID** plus attachment hash, which is stable by definition, rather than the connector's message ID.
- **U12 — PA Cloud message/action payload limits against a ~20 MB PDF as base64.** A 20,971,520-byte
  PDF (the ETDA ceiling, `MaxPdfBytes`) becomes roughly 28 MB once base64-encoded, and it crosses the
  flow-to-Function boundary on every submit **and every resubmit** (R19). Whether the trigger, the
  Azure Functions connector action, or the underlying HTTP message size limit accommodates that is
  unverified for this tenant. Fallback: confirm the limit before build; if it binds, stream the
  attachment to Blob storage and pass a reference instead of inline bytes.

## Lessons Learned

*(None from this project yet — no flow has been built. Entries land here when a live test overturns an
assumption, per repo `CLAUDE.md`. The trial's process lesson is worth carrying meanwhile: in a shared
environment, verify state immediately **before** a write, not only after — skipping that produced a
confident, wrong defect report that took four controlled experiments to retract.)*
