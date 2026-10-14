# Power Automate (Cloud Flows) — Reference & Rulebook — SHANA AR Cloud Flows

> **Project rulebook for `RPA for SHANA/AR/ar-cloud-flows/`.** Seeded 2026-10-12 by copying
> `templates/power-automate-reference.md` verbatim, so the template's rules **R1–R13** live in this
> file directly (copied, not adopted by reference). Project-specific rules will be numbered from
> **R14** onward and project findings recorded here — this file diverges from the template as the
> project learns things; the template itself is edited only for findings true of *every* PA Cloud project.
>
> A PA Cloud design is still checked jointly against `templates/power-automate-reference.md`. Rule
> IDs are file-scoped (see "Rule IDs are file-scoped" below): cite `<file> R<n>`, never a bare ID across files.
>
> Where the body says "this template", read "the template this file was copied from"; its "will renumber"
> note is satisfied by numbering project rules from R14.
>
> **Project-specific additions so far** (2026-10-12 unless dated otherwise, Discovery):
>
> - **R14** in section 1 ("Project rules") — no run record, a recorded exception to R10.
> - **P7–P10** in section 3. They continue the template's P1–P6 numbering but are **project-scoped**: a
>   future template P7 is a different rule, so cite this file's by file name. P7 is 🔬 user-reported
>   for every sample type (2026-10-14), with the AI Builder approach still to record; P8–P10 remain unverified.
> - **L4** in section 5 — what the P7 test changed. L1–L3 are the template's.
> - **🔬 user-reported** (2026-10-14) — a project-scoped qualified marker, used only on P7. It means a
>   live test that the user ran and reported: binding for design, but its evidence is the user's
>   statement, not an artifact held in the repo. It is weaker than the legend's 🔬, which needs evidence
>   such as `flowagent-trial/test-plan.md`. The legend below is the template's and is left unchanged.
>
> Apart from this header block, the title's project suffix, and the additions listed above, everything
> else below is the template's text, unchanged. Project status: see `PROGRESS.md`.

**This rulebook governs Power Automate CLOUD flows only.** It has nothing to do with Power
Automate Desktop. `concur-cash-advance-bot/docs/pa-desktop-reference.md` is a ⛔ superseded
historical record for a different product that happens to share a brand — none of its rules,
syntax, or Lessons Learned apply here. See `CLAUDE.md` → "Solution options".

Rule status markers, matching the UiPath rulebooks:

| Marker | Meaning |
|---|---|
| ✅ | **Project-adopted convention** — a hard constraint. Binding. |
| 🔬 | **Verified platform behaviour** — proven by live testing. Binding, and evidenced. |
| ⚠️ | **Unverified** — believed but not tested here. Flag inline in the design with a documented fallback. |

Evidence for 🔬 V1–V5 is in `flowagent-trial/test-plan.md`. ⚠️ **V6 and V7 were not exercised there** — the trial reused an already-authorised connection and observed no expiry — so they rest on other sources and should be confirmed before a design leans on them.

---

## 1. Adopted conventions (✅)

**R1 — Single cloud flow.** No child flows, no "Run a Child Flow". ⚠️ **Scope: this governs one
process.** A separately-triggered flow that is a genuinely different process — scheduled monitoring,
recovery, a heartbeat — sits outside R1 rather than breaching it, but must be recorded as a decision
with its reason and its bounds, never assumed. Power Automate supports
splitting; we deliberately don't, mirroring the single-`Main.xaml` rule. The trade-off (a large
single artifact) is accepted knowingly in exchange for one place to read and one place to diff.

**R2 — Scopes are the logical sections.** One `Scope` per logical phase from the high-level
design, named Verb + Object. Nesting is fine. A flat sequence of 40 top-level actions fails
review regardless of whether it works.

**R3 — Error handling is Scope + "Configure run after".** There is no Try/Catch activity. The
shape is three sibling Scopes:

- `Try` Scope — the work.
- `Catch` Scope — `Configure run after` on the Try Scope set to **has failed**, **has timed out**,
  and **is skipped**. Omitting `is skipped` is the classic hole: a Try Scope skipped by an
  upstream failure leaves Catch unreached.
- `Finally` Scope — `Configure run after` set to **all four** outcomes, so cleanup and the run
  record happen on every path.

**R4 — Fatal paths use `Terminate`, not an exception.** `Terminate` with status `Failed` and an
explicit message. There is no `Throw`, and no `Go to`. Early exit from a non-fatal path uses a
guard variable plus `Condition`, exactly as UiPath projects use `runShouldContinue`.

**R5 — No hardcoded environment values.** URLs, site addresses, list/library names, table names,
thresholds, recipients, folder paths, and retry counts all come from one config source read once
at flow start into a single object variable.

- Solution-aware flow in a Dataverse-backed environment → **environment variables**.
- Otherwise → a config SharePoint list or Excel file, read once.

The design must **state which applies and why**, because it depends on the target environment
having Dataverse. Don't assume; check.

**R6 — Connections are referenced, never credentialed.** No secret, token, password, or API key
appears in a flow definition under any circumstance. Connection authorization is a human, per-
connection, first-time action (⚠️ V6) and the implementation guide must say so explicitly rather
than implying the flow is self-installing.

**R7 — Expressions are WDL.** `concat()`, `formatDateTime()`, `addDays()`, `coalesce()`, `if()`,
`length()`, `empty()`, and `@{...}` interpolation inside strings. VB.NET from a UiPath design and
`%Var%` from PA Desktop are both defects here.

**R8 — Every expression-built target gets an existence check or a post-condition.** Direct
consequence of 🔬 V2. If a folder path, file name, list item, or table row is assembled from an
expression, the flow must verify it landed where intended — the run history will report success
either way.

**R9 — Flows are created `Stopped`.** Activation is a separate, deliberately recorded step, never
a side effect of saving. This also applies to the tooling: `create_flow` takes `state: "Stopped"`.

**R10 — Run record.** Every flow writes a run record (start, end, outcome, key identifiers,
error message on failure) from the `Finally` Scope, so a failed run is diagnosable without the
run history. This matters more on PA Cloud than UiPath because of 🔬 V3: the platform will not
show you what an action actually produced on a successful run, so anything you need after the
fact must be written down while the flow is running.

**R11 — Build inside a Solution, not "My flows".** A solution is what gives you environment
variables, connection references, and an export path — without it, ✅ R5's environment-variable
option doesn't exist and the flow cannot be moved between environments at all. Unmanaged in dev.
This is the rule that makes several others possible, so decide it first.

**Which environment, not just which Solution.** Repo `CLAUDE.md`'s standing constraint applies to
every project seeded from this template: **never build in the Default environment** — it holds every
maker's personal flows under constant concurrent edit, and "the agent changed nothing" becomes
unprovable there. Use a dedicated Developer or sandbox environment, name it explicitly in the
project's rulebook, and if a live/shared environment is ever used anyway, capture a pre-work inventory
first (`flowagent-trial/baseline-inventory.md` is the pattern). This is deliberately folded into R11
rather than given its own number, to avoid colliding with a seeded project's own R14-onward numbering.

**R12 — Set trigger concurrency deliberately.** Leaving it at the default is a decision by
omission. Serial execution (concurrency 1) keeps run history readable and makes any cross-run
counter meaningful; parallel execution is a choice that must be justified by volume.
⚠️ On some triggers concurrency control **cannot be reverted once set** — treat it as a one-way
door and set it at build time, not by experiment.

**R13 — Default action names are banned.** `HTTP 2`, `Condition 3`, `Apply to each 2`,
`Compose 5`. Every action gets a Verb + Object name (the repo-wide "Verb + Object" naming convention in `CLAUDE.md`).
This is the single biggest cause of unreadable flows, and unlike UiPath — where an unnamed
activity at least shows its type and properties — a PA Cloud expression referencing
`outputs('Compose 5')` is unreadable *and* becomes a rename hazard, since renaming an action does
not update the expressions that reference it.

### Project rules (R14 onward)

**R14 — No run record: a recorded exception to R10.** This project does not apply R10 (this file's
copy) or `templates/power-automate-reference.md` R10. The `Finally` Scope writes no run record and no log
store exists. The user decided this on 2026-10-12 ("no need for log"; `PROGRESS.md` D7), after being told
of the conflict with R10.

*Accepted consequence* (`docs/power-automate-reference.md` V3): a run that succeeds but sends a wrong
reply, or sends none, leaves no evidence beyond the reply itself, because the run history of a succeeded
run does not show what its actions produced. Failed runs stay visible in the run history.

*Still to design:* with no record, a failed run is only noticed if someone opens the run history. Phase 2
or 3 must decide how a failure becomes visible, for example the `Catch` Scope notifying an owner. That is
an open design point, not decided here. The `[run record — see R10]` step in section 4's Try/Catch/Finally
pattern is omitted for this project. A `Finally` Scope is still kept, with `Configure run after` set to
all four outcomes as R3 requires, but it holds cleanup only: R3's "and the run record" clause and the
pattern's "Finally - Write Run Record" Scope name do not apply here.

⚠️ *Assumption:* "failed runs stay visible" depends on how long the platform keeps run history. The
retention period is not established in this rulebook (believed to be roughly 28–30 days, unverified).
With no log, run history is the only record of a failure, so the failure-visibility design point above
must not rely on someone checking it within that window. *Fallback:* design failure visibility as an
active notification (for example from the `Catch` Scope), so it does not depend on retention at all. Revisit R14 if a silent bad reply is ever
reported.

---

## Rule IDs are file-scoped

`R5` in this template and `R5` in a project's rulebook are **different rules**. This template's
numbering is its own; a project seeded from it will renumber as it adds project-specific rules.
Never cite a bare rule ID across files — always write `<file> R<n>`
(e.g. `invoice-signature-verification-bot/docs/power-automate-reference.md` R14). A cross-file
bare ID is a review finding.

---

## 2. Verified platform behaviours (🔬, plus V6/V7 which are ⚠️ — see below)

**V1 — The write API rejects fields the read API returns.** `get_flow` returns
`"authentication": "@parameters('$authentication')"` on connector actions. Sending that same
field back on a write fails validation:

```
rule: extra-authentication
"Do not include authentication in action inputs — the Flow API auto-injects it"
```

**The naive read → edit → write round-trip does not work.** This was reproduced by copying a
field verbatim out of a live production flow. Always `preflight_flow` before a write; it names
the exact offending path, and nothing else does.

**V2 — OneDrive `Create file` creates missing folders instead of failing.** A `folderPath`
pointing at a non-existent directory does not 404. The connector creates the folder tree, writes
the file, and reports success.

Consequence: **a flow whose path expression has drifted reports a green run while writing
somewhere nobody is looking.** A dated-path pattern like
`concat('/Output/', formatDateTime(addDays(utcNow(),-1),'yyyy/MM/dd'))` has no write-side
protection at all. Read-side steps fail loudly; write-side steps do not. Hence ✅ R8.

**V3 — Succeeded runs expose no action inputs or outputs.** Run history gives per-action name,
timings, status, and error codes — and nothing about what an action received or returned.
Verified across `get_run_actions`, `get_run_details`, and `diagnose_run`.

Consequence: **"the flow finished green but produced the wrong data" is not diagnosable from run
history.** Design for it — see ✅ R10.

**V4 — Property selection on a scalar fails only at runtime.** `outputs('Compose_X')['status']`
where `Compose_X` produced a string passes save-time validation and fails on execution with
`InvalidTemplate`. Save-time validation does not type-check expression results, so an expression
being accepted by the designer says nothing about whether it will run.

**V5 — Failed runs are diagnosable in full.** On failure, the platform returns the failing action
name, the error class, the reason, **and the offending expression quoted verbatim**. This is
genuinely good and is the strongest capability the tooling has. It is also the *easy* class of
failure — see V3 for the hard one.

⚠️ **V6 and V7 below keep the "V" numbering for cross-reference stability, but are not 🔬-tier —
neither was exercised in `flowagent-trial/` (see the caveat at the top of this section). Treat them
as documented-but-unverified, one notch below V1–V5, and confirm before a design leans on them.**

**⚠️ V6 — Connection authorization is per-connection and human.** Documented platform behaviour, not
observed in the trial: it happens once per connection, by the connection owner, and cannot be
automated. A flow imported or created with an unauthorized connection sits broken until a person
authorizes it.

**⚠️ V7 — Connections silently expire after ~90 days of inactivity.** Documented Entra ID / Power
Automate connection behaviour, not observed in the trial (which reused an already-authorized
connection and saw no expiry): the failure surfaces as `AADSTS700082 — The refresh token has expired
due to inactivity`, and the connection shows `Error` status but nothing proactively alerts. Any flow
that runs less often than quarterly must assume its connections may be dead, and the design should
say how that is detected.

---

## 3. Unverified platform behaviours (⚠️)

Each needs a documented fallback in the design until proven. When a live test settles one,
promote it to 🔬, add a Lessons Learned entry, and sweep the design docs for anything that
assumed otherwise.

**P1 — Solution-aware flows may not appear in standard flow listings.** Documented by the tooling,
**untestable in our trial** because the environment had no Dataverse and therefore no solutions.
*Fallback:* address solution flows by ID; never conclude "no flows exist" from an empty listing.

**P2 — Environment variables require a solution and a Dataverse-backed environment.** Believed,
not tested. *Fallback:* ✅ R5's config-list alternative.

**P3 — Connector actions carry a default retry policy** (believed: exponential, ~4 attempts).
If true, an action that "failed once" may have already been attempted several times, which
changes what a retry loop around it means. *Fallback:* set retry policy explicitly on any action
where the count matters, rather than relying on the default.

**P4 — `Apply to each` defaults to sequential**, with concurrency opt-in and a cap around 50.
*Fallback:* set concurrency explicitly wherever order or rate limiting matters.

**P5 — Flow-level throttling limits** (actions per 5 minutes, connector-specific request caps) are
not established for this tenant. *Fallback:* design for volume well under any plausible limit and
flag high-volume phases for a live test.

**P6 — Behaviour of `update_flow` on a flow that is currently running** is unknown. *Fallback:*
stop the flow before editing anything non-trivial.

### Project-specific unverified behaviours (added 2026-10-12, Discovery)

These come from this project's process, not from the template. Each one changes the design if it turns
out false, so each needs settling before the design leans on it, not discovering at build time.
P7 stays in this section, under the qualified marker **🔬 user-reported** defined in the header, so that
its number does not change; it is not moved to section 2 and gets no V number.

**P7 passed the user's own test** (2026-10-12) on every sample type (2026-10-14); only the approach the
test used is not yet recorded — see P7 and L4. That was the user's own test, outside this project's process; it grants the assistant nothing. **None of P7–P10 may
be tested in the tenant by the assistant** — including any test to confirm P7's coverage. `CLAUDE.md` ("PA Cloud tooling") keeps the tenant
untouched until Phase 6, and a test artifact is a tenant artifact just as a flow is. A pre-Phase-6 test
would need an explicit user-approved exception with bounds — the shape is in `PROGRESS.md` D8, now
closed — and a non-Default environment (`docs/power-automate-reference.md` R11).

**P7 — AI Builder can classify and extract from these PDFs.** 🔬 **user-reported (header marker), every
sample type (2026-10-14); approach not yet recorded.** The user first reported (2026-10-12): "I tested AI builder and
it works. No concern on this." Asked which kinds of sample the test covered (Thai, English, mixed,
scanned, digital), the user answered "test all - pass all" (2026-10-14). The marker rests on the user's
report, not on a test this project ran or saw: no sample set or result is held in the repo. Still not recorded:
which AI Builder approach the test used (`PROGRESS.md` Q14). The design must use the approach that was
tested, so Q14 still blocks the design. ⚠️ Whether the test covered classification as well as extraction
is assumed from "test all" and not stated; confirm it when the approach is recorded. *Fallback if
classification was not tested:* a separate classification step, as in approach (2) below. Extraction is
confirmed only for the fields the user happened to test: the field list (`PROGRESS.md` Q13) is deferred,
so P7 must be re-confirmed against that list when Q13 is settled, before Phase 3. The original risk was that the documents are
Thai, English, or mixed, and arrive as both digital PDFs and scans. *Approaches, in the order to consider them:* (1) an AI Builder **prompt** that takes the PDF as input and returns the
document type plus the fields as JSON; (2) an AI Builder **document processing** custom model, one per
document type, with a separate classification step. *Fallback if neither is good enough:* an external
OCR/extraction service, reached through a custom connector or a connection reference that holds the
credential, so no key appears in the flow definition (`docs/power-automate-reference.md` R6). It needs
Premium, a DLP check and a data-residency check, so it is a recorded decision, not a silent swap. With
every sample type reported as passing, this fallback is no longer expected; it is kept in case a test
during the build contradicts the user's result. The Phase 6 implementation guide must therefore include
an AI Builder acceptance test on real samples of each kind.

**P8 — The trigger can watch a Microsoft 365 group's mailbox.** `AccountReceivable@pttep.com` is a
Microsoft 365 group, not a user or shared mailbox. The Office 365 Outlook shared-mailbox trigger is
believed not to work reliably against a group address, and the Office 365 Groups Mail trigger's status
and behaviour are unconfirmed. *Fallback:* make the flow's service account a member of the group,
subscribed so that group mail is delivered to its own inbox, and trigger on that inbox with the
standard new-email trigger. **If this fallback is used, P10's new-email fallback becomes the default:** a
reply action on the service account's copy of the message would address the original sender, which is
the leak `PROGRESS.md` D2 forbids.

**P9 — A password-protected PDF can be told apart from other failures.** The working assumption is
that the AI Builder action fails on an encrypted PDF, and that the failure can be caught per
attachment. Whether the error says "password" or "encrypted" is unknown. *Fallback:* treat any failure
to read a PDF as "could not be read", and word the reply to cover both cases: password-protected or
damaged, please send an unlocked or readable copy.

**P10 — A reply can be addressed to the group alone and still sit in the original thread.** The
result must go only to `AccountReceivable@pttep.com` (`PROGRESS.md` D2). It is unconfirmed whether
Office 365 Outlook's reply action lets the recipient list be replaced rather than added to, and whether
the reply threads under the original email in the group's conversation view. *Fallback:* send a new
email to the group with the original subject prefixed `RE:` and the original sender, date and subject
quoted at the top of the body.

---

## 4. Standard patterns

**Config read (start of every flow):**

```
Scope: "Read Configuration"
  [solution-aware]      Initialize variable: cfg  ← environment variable references
  [non-solution]        Get items (SharePoint) → config list
                        Select / Compose → cfg object keyed by Name
  Condition: "Verify Config Loaded"
    empty(cfg) → Terminate (Failed, "Config source empty or unreachable")
```

**Try / Catch / Finally:**

```
Scope: "Try - Process Transactions"
    [work]

Scope: "Catch - Handle Failure"
    Configure run after: has failed, has timed out, is skipped
    Compose: error detail from result('Try - Process Transactions')
    [notify / record]

Scope: "Finally - Write Run Record"
    Configure run after: is successful, has failed, is skipped, has timed out
    [run record — see R10]
```

`result('<Scope name>')` inside the Catch Scope returns the per-action outcomes of the failed
Scope, and is the only practical way to get at what went wrong.

**Guarded early exit (there is no `Go to`):**

```
Initialize variable: runShouldContinue (Boolean) = true      ← before the Try Scope
...
Set variable: runShouldContinue = false                      ← where the run should stop
Condition: "Check Run Should Continue"  →  @variables('runShouldContinue')
  If yes: [later phase]
```

Mirrors the UiPath guard-flag pattern for the same reason: neither platform has a jump.

**Write with verification (R8):**

```
Scope: "Write Output File"
  Create file        → folderPath from cfg, name from expression
  Get file metadata  → on the path just written
  Condition: "Verify File Landed At Expected Path"
    path mismatch → Terminate (Failed) or Catch
```

Without the verify step, V2 means this Scope reports success no matter where the file went.

---

## 5. Lessons Learned

**L1 — Verify state immediately *before* a write, not only after.** During the FlowAgent trial a
flow's `state` was found to be `Started` after an `update_flow` call and this was reported as a
silent-activation defect in the tool. Four controlled experiments failed to reproduce it, and run
history later proved the flow had already been running *before* the call — someone had activated
it externally. The tool was correct throughout; the report was wrong.

The root cause was checking state after the write but not immediately before it, in an
environment under concurrent edit. **In any shared environment, a change can only be attributed
per-artifact with a tight before/after check.** A whole-environment diff proves nothing, because
other people are editing too.

**L2 — Write-side connector steps do not protect you the way read-side steps do.** The first fault
deliberately injected during the trial — a path pointing at a non-existent folder — *refused to
fail*, because OneDrive created the folder (V2). The instinct that "a bad path will obviously
error" is wrong on the write side and right on the read side, and that asymmetry is invisible
until it costs you a day looking for output that went somewhere else. Hence ✅ R8.

**L3 — A tool schema is not the API contract.** `list_flows` advertises `top` up to 500; the Flow
API hard-rejects anything above 50. Believing the schema yields a 400 at best, and at worst a
silent single-page inventory reported as complete. Verify limits against the service, not the
client.

**L4 — The biggest feared risk was largely answered already by the person closest to the data** (project
addition, 2026-10-12). Discovery treated AI Builder on Thai and scanned PDFs (P7) as the risk most likely
to change the design, and proposed a bounded pre-Phase-6 test exception (`PROGRESS.md` D8) to settle it.
The user had already tested AI Builder and reported that it works. What was assumed: an open feasibility
risk that nobody had tried. What is true: the user had tried it on every sample type and all passed
(coverage recorded 2026-10-14), so P7 is 🔬 user-reported; the approach is still to be recorded
(`PROGRESS.md` Q14). Ask what the
user has already tried before designing a test for it — and when they have, record exactly what it
covered before treating the risk as closed.
