# FlowAgent MCP — Capability Trial

**Status:** trial / not a design project. This folder is deliberately **outside** the phased
`rpa-bot-dev` process (Discovery → … → Implementation Guide) that governs
`concur-cash-advance-bot/`, `vendor-sbn-upload-bot/`, and `invoice-signature-verification-bot/`.
Nothing here is a deliverable. The purpose is to find out what the tooling can and cannot do
before deciding whether it belongs in a real project.

## What we're testing

Whether Claude Code + the `power-automate` plugin (FlowAgent MCP, ~50 tools) can genuinely
author, edit, publish, observe, and debug Power Automate cloud flows — and where it breaks.

## Environment guardrail — settle before T0

Target must be a **dedicated dev/sandbox environment**. Not Default, not Production.

Default is the trap: it's created automatically, every licensed user in the tenant can make
flows in it, and it accumulates personal flows nobody inventories. An agent with admin rights
pointed at Default can read and edit all of them.

- [ ] Sandbox environment name: `________________`
- [ ] Confirmed it is **not** Default and **not** Production
- [ ] Confirmed nothing business-critical runs in it

## Test set

Ordered so that each test adds exactly one new variable. The first two are read-only; the
first flow needs **zero connectors**, which removes connection-authorization as a confound.

### T0 — Auth and routing (read-only)
Prove the pipe works before touching anything.
- `az login`, then ask the agent to list environments and resolve to the sandbox.
- **Pass:** correct environment list; agent routes to the sandbox without being re-told.
- **Watch:** whether it defaults to Default when the target is ambiguous. That's a real hazard.

### T1 — Read a real flow (read-only)
- Ask it to browse flows and print one existing flow's full JSON definition.
- **Pass:** returns actual definition JSON, not a plausible-looking reconstruction.
- **Watch:** solution-aware flows are documented as *not appearing in standard listings*.
  Confirm whether ours show up, and whether it silently reports "no flows" when they exist.

### T2 — Create, no connectors
First write. Deliberately connector-free: Recurrence trigger → Compose → Terminate.
- Ask it to build the flow from a one-line description.
- **Pass:** flow exists in the portal, definition matches the description, lands **Stopped**.
- **Watch:** does it actually land Stopped, or does it activate something on a live tenant?

### T3 — Surgical edit
Editing is a different code path from creating, and the likelier place to lose fidelity.
- Change the recurrence, then add a Condition branch to the T2 flow.
- **Pass:** the edit lands and **nothing else in the definition changes.**
- **Watch:** whether it round-trips the whole definition and quietly drops or reorders
  properties it didn't understand. Diff before/after — don't take "done" at face value.

### T4 — Connector + run inspection
Now add the connection variable. Use a low-blast-radius connector — OneDrive for Business or
SharePoint file create, **not** email.
- Add the action, authorize the connection, activate, let it run, then ask the agent to read
  the run history with full action inputs/outputs.
- **Pass:** it reads real run data, including inputs/outputs per action.
- **Watch:** connection authorization is per-connection and needs the owner to do it by hand
  the first time. Confirm the agent reports this clearly rather than failing opaquely.

### T5 — Break it, then diagnose (the headline claim)
This is the capability the blog rated highest, so it's the one worth testing hardest.
- Inject a realistic fault into T4's flow — bad expression reference, or a schema mismatch
  that only fails on certain input. Let it run and fail.
- **Start a fresh session** so the agent has no memory of what was broken.
- Ask only: "this flow is failing, find out why."
- **Pass:** it locates the actual root cause unaided, by correlating run output against the
  definition — not a generic list of things that could be wrong.
- This is the test that decides whether the tooling is worth adopting. Creating flows by hand
  was never the expensive part; finding out why one silently stopped working is.

### T6 — Lifecycle / versioning (optional)
- Export the flow to local solution source via `pac`, commit it, change the cloud flow,
  re-export, diff.
- **Pass:** the local mirror is a readable, diffable artifact.
- Tests whether the blog's discipline — *cloud flow is the working copy, local source is the
  versioned mirror* — is actually practical or just aspirational.

## Findings log

Filled in as we go. Negative results are the valuable ones — record what it got wrong,
not just what worked.

| Test | Result | Notes |
|---|---|---|
| T0 | | |
| T1 | | |
| T2 | | |
| T3 | | |
| T4 | | |
| T5 | | |
| T6 | | |

---

## Setup findings (2026-08-18)

Recorded because both cost real time and will recur on any other machine here.

**No admin rights needed after all.** `pac` installs as a per-user MSI. Azure CLI's official
MSI is machine-scope and fails UAC with exit 1602, but `pip install --user azure-cli` puts
2.79.0 in `%APPDATA%\Python\Python39\Scripts` with no elevation. `az login` itself never
needed admin — only the installer did.

**`az login` fails with `PermissionError: [Errno 13]` on `azureProfile.json`** when that file
carries the Windows **Hidden** attribute. Not an ACL problem — the ACLs were correct and a
write test passed. Python's `open(path,'w')` uses `CREATE_ALWAYS`, which returns ACCESS_DENIED
against an existing hidden file unless `FILE_ATTRIBUTE_HIDDEN` is re-specified. Fix: clear
Hidden on the files in `~/.azure`. Note the sign-in itself *succeeds* — `msal_token_cache.bin`
gets written — so it looks like an auth failure when it's a file-write failure.

**FlowAgent shells out to `az` and needs it on the PATH of the Claude Code process.** Setting
the user PATH is not enough: Claude inherits the environment of the terminal window that
launched it, so restarting Claude alone doesn't pick it up — the terminal has to be closed and
reopened. Workaround without a restart: drop `az.cmd` / `pac.cmd` shims into a directory
already on the process PATH (`~/.local/bin` here).

**Shell trap:** the `!` prefix in Claude Code runs **Git Bash**, so Windows paths must be
POSIX-form (`/c/Users/...`) or quoted — bare backslashes get eaten as escapes.

## T0 result — partial PASS

| Check | Result |
|---|---|
| `az login` → tenant auth | PASS (PTTEP, `pttep.com`) |
| FlowAgent reaches Power Platform API | PASS after PATH shim |
| `list_environments` returns real data | PASS |
| Environment routing | **N/A — no current env set**, `source: "none"` |

The routing sub-test is untestable as written: FlowAgent holds no default environment and
said so plainly rather than silently falling back to Default. That is the correct, safe
behaviour and worth noting as a point in its favour.

## Blocker found at T0: no suitable trial environment

The tenant has exactly two environments:

| Display name | SKU | Default? | Region |
|---|---|---|---|
| PTTEP | Default | yes | australia |
| SHANA AP - PTTEP & Digital | Teams | no | australia |

Neither is usable for the trial:

- **PTTEP (Default)** holds **10 flows, 8 of them Started** — including `Tax Invoice`,
  `AR Email Classification`, `RPA Upload Error`, `RPA Email Monitor` and
  `Get Document No. Workflow`. These are live business automations, several apparently
  related to this repo's RPA work. This is precisely the blast radius the guardrail exists
  to avoid, and the loaded toolset includes `delete_flow`, `edit_flow` and `publish_flow`.
- **SHANA AP (Teams)** is a Dataverse-for-Teams environment: restricted connector set, tied
  to a real Team's membership, and not throwaway.

**Resolution:** create a **Developer** environment for the trial. Free, per-user, isolated,
and disposable when the trial ends.

---

## Decision: trial runs in PTTEP (Default)

The user chose Default over creating a Developer environment, after the blast radius above was
laid out. Recorded as their decision. Isolation therefore comes from the naming convention and
the guardrails in `baseline-inventory.md`, not from the environment.

## T1 result — PASS

`get_flow` on `Daily FX Rate Check` (64ace1b5…) returned the genuine, complete definition —
not a reconstruction. Verified by the presence of things a plausible fake wouldn't invent:

- Real connection GUIDs (`e4a7aedb583c4781b962f22b1dd6a49e`, `shared-teams-0a21ebf2…`)
- A SharePoint drive ID (`b!IG4P7BPwAUimpP5Fx4H5…`) and group ID
- Opaque Excel metadata keys (`016YC52FX75ZA2EESDG5DIURE3TJ4QVOYE`)
- The live expression, intact:
  `@concat('/General/11_PRD_Environment/02_FI_Daily_FX_Rate_Verification/Output/',
   formatDateTime(addDays(utcNow(),-1),'yyyy/MM/dd'),'/Round_2/…')`
- `runAfter` dependency graph, `evaluatedRecurrence`, `referencedResources`, creator objectId

It also returns `connectionReferences` **and** `installedConnectionReferences` separately, which
matters later: those can diverge, and that divergence is a classic cause of a flow that looks
correct but fails at run time.

**Useful discovery:** `get_flow` takes a `path` parameter to scope the response
(`definition.actions`, `properties.connectionReferences`). The full response for a *two-action*
flow was already large; on the 13-action flows it would be unwieldy. Use `path` by default and
`list_flows` for metadata sweeps.

### Solution-membership sub-check

`get_flow_context` reported `inSolution: false`, `isManaged: false`, `isCustomizable: true`,
with `warning: "workflow-not-found"`. Per the tool's own contract that warning means "no
Dataverse instance / no solution context — fall through to PPAPI behaviour", which is
consistent with a Default environment that has no Dataverse database provisioned.

Consequence: **the documented "solution-aware flows don't appear in standard listings" trap
cannot be tested here**, because this environment has no solutions at all. The 10 flows in the
baseline are the complete population. This is a gap in the trial, not a pass — it stays
unverified until we test somewhere with Dataverse.

The tool did report the ambiguity in a `warning` field rather than silently returning
`inSolution: false` as though it were confirmed. That is the right behaviour and a second point
in its favour, after the `source: "none"` refusal at T0.

## API/schema defect found

`list_flows` advertises `top` with `"maximum": 500` in its JSON schema, but the Flow API
rejects anything over 50:

```
Flow API 400: InvalidTopInQueryString — Top value must be positive integer
less than or equal to 50.
```

The tool schema and the service disagree. Harmless here (10 flows), but in an environment with
more than 50 flows an agent trusting the schema gets a hard 400 — and, worse, an agent that
retries with the default could silently inventory only the first page and report it as complete.

## T2 result — PASS

Created `ZZ-FLOWAGENT-TRIAL-01-Hello` (`99a261e0-c719-4d03-b90e-14951839ec81`),
Recurrence → Compose → Terminate, no connectors.

| Check | Result |
|---|---|
| Flow created | PASS |
| Landed **Stopped** | PASS — honoured `state: "Stopped"`, did not activate |
| Definition round-trip | PASS — read-back is identical to what was sent |
| No baseline flow touched | PASS (see drift note) |

The only difference on read-back was a service-added `evaluatedRecurrence` block mirroring
`recurrence` — computed by the platform, not a mutation of our input. Nothing was dropped,
reordered, or silently rewritten.

**`preflight_flow` is worth using every time.** It returned
`{overall: "ready", validation.valid: true, connectionRefs: [], solutionWrap.detected: false}`
before the write. Its docs also note `create_flow` auto-injects `$authentication` /
`$connections` because "most agent-built definitions forget these" — an honest admission that
the failure mode is common, and a sensible place to have put a guard.

`create_flow` also refuses duplicate display names by default, returning the existing flow ID
and pointing at `update_flow`. That is the correct default for an agent that might retry.

## Background drift confirmed — attribution works

`2026-08-18 Expense noti` has now changed **three times** across our read-only observations:

| Observation | actionCount | lastModifiedTime |
|---|---|---|
| Initial listing | 4 | 07:11:14 |
| Baseline capture | 5 | 07:26:56 |
| Post-T2 verification | 6 | 07:30:49 |

The trial's only write in that window created a *new* flow. Someone is editing that flow in the
maker portal concurrently.

This validates the scoped-verification decision: a naive "did any lastModifiedTime change?"
check would have flagged a false regression here. The baseline plus per-flow scoping correctly
attributes the change to something outside the trial. Worth carrying into any real adoption —
**in a shared environment, agent-caused change can only be proven per-artifact, never by a
whole-environment diff.**

## T3 result — PASS (the important one)

This was the test I flagged as most likely to fail. It didn't.

Three surgical operations via `edit_flow`: rewrite the recurrence (Day → Week + weekDays
schedule), add a nested `If` action with an `else` branch, and rewire `Terminate`'s `runAfter`.

Full read-back confirms:

| Fidelity check | Result |
|---|---|
| `Compose_Trial_Marker` untouched | PASS — byte-identical, `@{utcNow()}` expression intact |
| Nested `If` → `actions` + `else` → `actions` | PASS — both branches survived |
| `contains` expression array preserved | PASS — `["@outputs('Compose_Trial_Marker')", "trial"]` |
| `runAfter` graph rewired correctly | PASS |
| Anything dropped / silently rewritten | **None** |
| `$authentication` / `$connections` params | PASS — preserved |

JSON key *order* changed (`Check_Marker` appended last; keys within it reordered). That is not
semantically meaningful in a flow definition, but it does mean **a naive textual diff of
exported JSON will show noise**. Compare parsed structures, not text.

### The safety design here is genuinely good

`edit_flow` with `dryRun: true` returned a structured diff before writing anything:

```
"summary": "actions: +1 −0 ~1 (1 unchanged); trigger changed"
"unchanged": 1
```

That `unchanged: 1` is exactly the assurance needed — it states positively that the untouched
action stayed untouched. Applying then required passing back a single-use `previewToken`
(90-second expiry) bound to that exact proposal, so a concurrent edit between preview and apply
causes `PreviewTokenMismatch` rather than a lost write. `update_flow` also auto-captures a
backup before applying (last 10 per flow, via `list_backups`).

Preview-then-commit with an optimistic-concurrency token is the right pattern for an agent
mutating shared state, and it is better than what a human clicking through the maker portal
gets.

### Minor defect: wrong tool named in guidance

`edit_flow`'s dryRun response says:

> "Re-submit the SAME body to update_flow with previewToken to apply."

But the token was issued by `edit_flow` and takes `operations`, not a `definition` body —
`edit_flow`'s own description correctly says "re-call with the SAME operations plus that
previewToken". Following the response `note` instead of the tool description would send an
agent to the wrong tool with the wrong payload shape. Cosmetic, but it is the kind of thing an
agent follows literally.

## T4 result — PARTIAL (blocked before the run step)

Added a OneDrive for Business `CreateFile` action to trial flow 01, writing to
`/FlowAgentTrial`. Reused the existing Connected connection
(`shared-onedriveforbu-06851a3b…`) rather than creating a new one — a new connection would be
a permanent artifact in the tenant needing cleanup, whereas reuse creates nothing. This is a
deliberate change from the plan's "fresh connection" wording.

### Best finding of the trial so far: `preflight_flow` caught a real, non-obvious error

First attempt was **blocked before any write**:

```
overall: "block"
rule: "extra-authentication"
message: "Do not include authentication in action inputs — the Flow API auto-injects it"
path: "actions.Create_Trial_File.inputs.authentication"
```

The `"authentication": "@parameters('$authentication')"` line was copied verbatim from the
**live production** `Daily FX Rate Check` definition read in T1 — where it is genuinely present.

So: the field the API *returns* on read is a field the API *rejects* on write.

**This breaks the naive round-trip.** `get_flow` → edit → `update_flow` fails, because the read
includes service-injected fields the write refuses. Anyone building the blog's "cloud flow is
the working copy, local source is the versioned mirror" discipline hits this immediately, and
the error surfaces at save time with a message that points at *your* JSON rather than at the
platform that injected it. `preflight_flow` caught it cleanly and named the exact path.

**Practical rule: always `preflight_flow` before `create_flow` / `update_flow`.** Not optional.

### Correction: a defect I reported was not real

`update_flow` returned `state: "Started"` on a flow last verified `Stopped`, and this was
initially recorded as a silent-activation defect — `update_flow`'s own description says it is
not for starting/stopping flows.

Four controlled attempts failed to reproduce it:

| Attempt | State before | State after |
|---|---|---|
| `update_flow`, full definition, no `state` param | Stopped | Stopped |
| `edit_flow`, action inputs only | Stopped | Stopped |
| `edit_flow`, trigger rewrite | Stopped | Stopped |
| `update_flow` introducing a connection ref for the first time (fresh probe flow 02) | Stopped | Stopped |

The last one was built specifically to test the leading hypothesis and refuted it.

Most likely explanation: **the flow was already `Started` before the call**, switched on
externally during the ~30-minute gap after T3 — in an environment already proven to be under
concurrent edit (`2026-08-18 Expense noti` changed three times unprompted). `update_flow`
preserved the existing state and reported it accurately. Its state handling appears correct.

Recording this as a **methodology lesson, not a tool defect**. The trial's own attribution rule
— never attribute a change without a tight before/after check — was violated by the person
running the trial: state was verified after T2 and after the update, but not immediately before
the update. One unverified gap in a shared environment produced a confident, wrong bug report.
This is precisely the failure mode that makes agent-driven changes hard to audit in a live
tenant, and it argues for the Developer environment that was declined.

### Blocked: run step

`publish_flow` was refused by Claude Code's auto-mode safety classifier — activating a flow in
a live tenant. The refusal is correct, and it means the run-and-inspect half of T4 (and all of
T5, which needs a failing run) cannot proceed without the user's explicit approval.

Still unverified as a result: run history, per-action inputs/outputs, and the whole diagnosis
capability — which is the single most valuable claim being tested.

## T4 result — PARTIAL PASS (run works; inputs/outputs missing)

The user started, ran, and stopped the flow manually (option A), leaving the safety classifier
intact. Two runs were then read back.

### The correction is now confirmed by evidence, not inference

Run history shows a run at **08:10:09** that **contains no `Create_Trial_File` action** — the
OneDrive action wasn't added until 08:14–08:16.

That is proof the flow was already `Started` and actively running *before* the `update_flow`
call at 08:14 that reported `state: "Started"`. The tool reported the truth. The
silent-activation defect was never real, and `update_flow`'s state handling is correct.

### What worked

| Check | Result |
|---|---|
| `get_run_history` returns real runs | PASS — 2 runs, correct timestamps, status |
| Per-action execution status | PASS — all 6 actions, start/end to sub-millisecond |
| Branch resolution visible | PASS — `Compose_Marker_Present` Succeeded, `Compose_Marker_Absent` Skipped with `ActionBranchingConditionNotSatisfied` |
| Connector action executed | PASS — `Create_Trial_File` OK, file written to OneDrive |
| Trigger detail | PASS — `scheduledTime`, `clientKeywords: ["testFlow"]` correctly marking a manual test run |

The condition logic evaluated correctly and the skip reason is explicit, which is genuinely
useful for debugging branch behaviour.

### Gap: no action inputs/outputs

**T4's actual pass criterion was per-action inputs and outputs. That was not met.**

- `get_run_actions` → name, times, status, code, error code/message. No inputs. No outputs.
- `get_run_details` → run-level and trigger-level detail only. No per-action data at all.
- `diagnose_run` on a successful run → `{status, failedActions: [], summary}`. Nothing more.

So on a **succeeded** run there is no way, via these tools, to see what an action actually
received or returned. Not the composed marker's value, not the created file's name or path.

This matters more than it first appears. The blog's headline claim — that the assistant
"correlat[ed] run outputs with flow definitions" to catch a negative-credit-line bug — depends
on reading outputs. That capability is unverified here, and on this evidence it may be
available only for *failed* actions.

Note `diagnose_run` is explicitly failure-oriented: it "classif[ies] each failed/timed-out
action". It has nothing to say about a healthy run, which is reasonable for its purpose but
leaves the success-path visibility gap open.

**Untested and now the key open question:** whether inputs/outputs appear for *failed* actions.
That is exactly what T5 would establish, and it is the difference between "reads run metadata"
and "can actually debug a flow".

## Verified: the auto-backup claim is real

`update_flow` claims to "auto-capture a backup snapshot before applying (last 10 retained per
flow)". Confirmed on disk at `.flowagent/backups/<envId>/<flowId>/<timestamp>.json` — six
snapshots for flow 01, matching the six writes made against it, each a full pre-change flow
body with `capturedAt` / `envId` / `flowId` / `operation`.

This is a real rollback path, not a claim. It is also **local and per-machine** — it lives in
the working directory, not in the tenant. A colleague editing the same flow from their own
machine gets no benefit from it, and wiping the working copy destroys the safety net. Worth
knowing before relying on it.

Minor inconsistency: snapshots taken by `edit_flow` are recorded as `"operation": "update_flow"`,
so the backup log can't distinguish a surgical edit from a full replace.

`.flowagent/` is git-ignored here: regenerable local working state, and it would churn on every
write.

## First fault attempt failed — and found a real silent-failure mode

The initial fault set `folderPath` to a non-existent dated path
(`/FlowAgentTrial/2026/08/17/Round_2`), on the assumption it would 404 at runtime. **The run
succeeded.** OneDrive's `CreateFile` silently creates missing folders in the path.

The test-design mistake is mine, but the underlying behaviour matters beyond this trial: a
production flow writing to a mistyped, drifted, or stale folder path **will not fail**. It
creates the wrong folder, writes the file there, and reports a green run.

This applies directly to the existing `Daily FX Rate Check`, which builds its path from
`formatDateTime(addDays(utcNow(),-1),'yyyy/MM/dd')`. If that expression ever drifts, output
lands in a new wrong folder with a clean run history and no alert. Worth a look independently
of this trial. (Its Excel `GetItem` step would likely fail on the missing file — but only
because it *reads*; the write side gives no such protection.)

Second fault, which did work — property selection on a scalar, a classic runtime-only error:
`body: "@{outputs('Compose_Trial_Marker')['status']}"`

## T5 result — PASS (with an important boundary)

Run `08584145641917497489914079456CU30`, status `Failed`.

`diagnose_run` returned:

```json
{
  "name": "Create_Trial_File",
  "code": "InvalidTemplate",
  "message": "... 'The template language expression
     'outputs('Compose_Trial_Marker')['status']' cannot be evaluated because
     property 'status' cannot be selected. Property selection is not supported
     on values of type 'String'. ...'",
  "remediation": "Expression or template error. Check the expression syntax in this action's inputs."
}
```

It named the failing action, the error class, **quoted the offending expression verbatim**, gave
the reason, and offered a remediation.

**Was this a fair pass despite the same-session setup?** Yes. The prior knowledge added nothing
— the error message is self-contained and identifies the fault without inference. Any agent
reading that output cold would locate it immediately.

`get_run_actions` is also materially richer on failure than on success: it carries `errorCode`
and `errorMessage` per action, and explains downstream skips precisely —
`"the 'runAfter' condition for action 'Create_Trial_File' is not satisfied. Expected status
values 'Succeeded' and actual value 'Failed'"`. The full causal chain is legible.

### The boundary — what this does not prove

This was the **easy class** of failure: the platform itself emitted a precise, self-describing
error. The tooling relayed it faithfully, which is genuinely valuable, but relaying a good error
message is a lower bar than diagnosis.

The blog's headline case — spotting that negative credit lines were causing connector rejections
— required correlating **actual output values** across actions. That is still unverified, and
T4 established that succeeded actions expose no inputs or outputs at all. So:

| Failure class | Verdict |
|---|---|
| Action throws a descriptive platform error | **Verified** — relayed in full, expression quoted, remediation offered |
| Action fails with an opaque connector error | Untested |
| Flow succeeds but produces *wrong data* | **Cannot be diagnosed with these tools** — no output values on succeeded runs |

The third row is the one that matters most for the kind of work in this repo. A bot that reports
success while doing the wrong thing is the failure mode this repo has already been bitten by
twice (see the uninitialized-variable lessons in `concur-cash-advance-bot`). These tools would
not have caught those.

## Overall verdict

**Adopt for authoring and for triaging failed runs. Do not rely on it to verify correctness.**

Strengths, all verified rather than assumed:
- `preflight_flow` catches real errors before they reach the tenant, including the
  read-returns-what-write-rejects `authentication` trap
- `edit_flow` surgical edits preserve untouched structure exactly, with a positive
  `unchanged: N` assertion and preview-token optimistic concurrency
- Automatic local backups before every write
- Failed-run diagnosis relays the full platform error including the offending expression
- It declines to guess: `source: "none"` rather than defaulting; `warning` rather than a
  fabricated `inSolution: false`

Limits, also verified:
- No action inputs/outputs on succeeded runs — the "wrong data, green run" case is invisible
- `list_flows` schema claims `top: 500`; the API caps at 50
- Backups are local and machine-bound, not tenant-side
- Round-tripping a read definition into a write fails without preflight

Process lesson, learned the hard way: in a shared environment, **verify state immediately before
a write, not only after** — one skipped check produced a confident, wrong defect report that took
four controlled experiments to retract.
