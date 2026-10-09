# CLAUDE.md — RPA Repo Instructions

This repo holds RPA bot design/build work. Read this file first, every session, before doing anything else.

## How we work on every project

The repo **is** the workspace. Every project — `concur-cash-advance-bot/` is the template — lives as its own top-level folder, and all of its artifacts (PDD, designs, reference doc, progress file, and eventually the build) are created **inside that folder in this repo**, never in scratch space or only in chat.

- **Claude Code is where we think out loud.** Use the conversation to ask questions, discuss options, and work through decisions. Nothing in chat is the deliverable — the files in the repo are.
- **Confirmed work gets committed.** When a discussion reaches a conclusion or a phase/result is confirmed by the user, capture it in the appropriate repo file and commit it (per the Git workflow below), so the repo is always the durable record of what's been decided. Unconfirmed exploration stays in chat until the user confirms; don't commit half-decided drafts.
- **A new project = a new top-level folder** mirroring the template's `docs/` layout (see Docs map). Start it the same way: Discovery → PDD, then the phased process, with a `PROGRESS.md` as its resume file from day one.
- The result is that anyone (including a future session) can reconstruct the whole state of a project — decisions, rationale, open questions — from the committed files alone, exactly as the cash-advance project already works.

## Always resume from PROGRESS.md

Before any work, read the active project's `docs/PROGRESS.md`. Three projects exist — `concur-cash-advance-bot/`, `vendor-sbn-upload-bot/`, and `invoice-signature-verification-bot/` — each with its own `PROGRESS.md`; read the one for the project the user is asking about. It states the current phase, what's confirmed, what's blocked, and what's next. Don't re-derive this from guessing at file contents — `PROGRESS.md` is the source of truth for where we are.

`invoice-signature-verification-bot/` differs from the other two: it is the repo's **first PA Cloud project** (decision D5, 2026-08-19 — it was scoped for UiPath and an external developer until then, and reverts to UiPath if **either** of its two gating checks fails — tenant DLP permitting the HTTP/Azure Functions connector, or Azure Function deployability. A revert also re-opens the delivery model, tracked as that project's Q18). Its `PROGRESS.md` carries a **Confirmed decisions** section (D1–D5 confirmed by the user; **D6 recorded but pending explicit user confirmation** — flagged inline where it lives) — decisions that bind later phases once confirmed. A later phase contradicting a confirmed one is a defect, not a revision. It also carries a superseded `uipath-reference.md`, banner-marked, kept deliberately as the fallback rulebook.

## Use the `rpa-bot-dev` skill for all RPA/bot design work

Any task involving UiPath, Power Automate cloud flows, Power Automate Desktop, RPA, bot development, process automation, or "let's automate X" goes through the `rpa-bot-dev` skill. It is the only skill installed in this repo (`.claude/skills/rpa-bot-dev/SKILL.md`) — deliberately. Don't install or restore other skills.

The skill enforces a **phased process** (Discovery → High-Level Design → Medium-Level Design → Detailed Design → Full Review & Sign-off → Implementation Guide). Rules:
- **Never skip phases.** Each phase must be confirmed by the user before moving to the next.
- **No code or automation files until Phase 5 sign-off.** Everything before that is documentation.
- Confirm **one sub-phase at a time** within Detailed Design — don't draft all 6 sub-phases and present them together.
- If a phase is blocked on an external decision (e.g., login method), flag it explicitly, mark it blocked in `PROGRESS.md`, and keep designing the phases that don't depend on it.

## Review loop — mandatory and automatic

Running the `rpa-design-reviewer` agent (`.claude/agents/rpa-design-reviewer.md`) is **not optional and does not wait for the user to ask.** The moment you finish creating or editing **any new phase, sub-phase, or development step** — a detailed-design sub-phase, a medium/high-level phase, an implementation step, or any edit to a design/reference doc — you **automatically** run the reviewer against it, before you present anything to the user for confirmation and before you commit.

- It checks **correctness** against the project's platform reference doc — `docs/uipath-reference.md` or `docs/power-automate-reference.md`, whichever that project carries, including its Lessons Learned (and, for a PA Cloud project, `templates/power-automate-reference.md` as well) and **completeness** against the medium-level design + PDD.
- **Loop `fix → re-review` until the reviewer returns a clean `PASS` with zero BLOCKERS and zero MAJOR items.** One review pass is not the loop — a `FAIL` means fix and re-run, every time, however many rounds it takes. Do not present or commit a phase that has not reached PASS.
- The only findings allowed to remain under a PASS are **MINORS tied to still-unverified platform behavior**, and only when each is flagged inline in the design with a documented fallback.
- **Never skip the review to save time or because a change looks trivial** — a small edit (a wording fix, a variable rename) is exactly where a stale cross-reference or dangling variable slips in. Default reviewer model is **Opus** (set in the agent's frontmatter); don't downgrade it.
- If the custom agent type isn't loaded mid-session (custom agents load at session start), run the same review instructions via a `general-purpose` agent instead — don't skip the review.
- Only after PASS do you present the phase to the user for confirmation, then commit.

## Solution options — three platforms, chosen in Phase 1

This repo builds on **three distinct platforms**. Platform is selected at the end of Discovery and governs Phases 2–6. Getting the choice right matters more than getting the design right, because the design is unportable.

| Platform | Status | Rulebook | Use when |
|---|---|---|---|
| **UiPath** | Live — `concur-cash-advance-bot`, `vendor-sbn-upload-bot` | `docs/uipath-reference.md` | Desktop/UI automation, SAP GUI, on-prem systems, complex exception handling, high volume, anything needing a real attended/unattended robot |
| **Power Automate (cloud flows)** | Live — `invoice-signature-verification-bot` | `docs/power-automate-reference.md` | Connector/API work against cloud services (SharePoint, Outlook, Teams, Excel Online, Dataverse, Forms), event- or schedule-triggered, **no UI automation needed** |
| **Power Automate Desktop** | ⛔ Legacy — historical only | `concur-cash-advance-bot/docs/pa-desktop-reference.md` | Don't select for new work without an explicit decision. See "Legacy" below. |

**The distinction that will bite you: "Power Automate" means two different products here.** Cloud flows and Desktop flows share a brand and almost nothing else — different designer, different expression language, different rulebook, different failure modes. When writing or reading anything in this repo, say **"PA Cloud"** or **"PA Desktop"**, never bare "Power Automate". A rule from one applied to the other is a defect, exactly as the UiPath/PA-Desktop confusion already is.

**Choosing between UiPath and PA Cloud.** The deciding question is *does this need to drive a user interface?* If the work is entirely API- and connector-shaped against Microsoft 365 or Dataverse, PA Cloud is cheaper to build, cheaper to run, and needs no robot infrastructure. The moment the process must click, type, or read a screen — SAP GUI, a legacy thick client, a portal with no API — it is UiPath. A hybrid where a cloud flow calls a desktop flow for one UI step is possible but pushes you into two rulebooks and two failure surfaces; treat it as a deliberate, documented decision rather than a default.

**Don't choose PA Cloud to avoid design rigour.** The phased process, the review loop, and the no-build-before-sign-off rule apply identically to all three platforms. A cloud flow is easier to *change* than a `.xaml`, which makes it easier to change *carelessly*.

## Platform syntax — don't assume, verify

**Each project carries its own platform reference doc** as the source of truth for how that platform behaves and what conventions the project has adopted — `docs/uipath-reference.md` for a UiPath project, `docs/power-automate-reference.md` for a PA Cloud one. A project has exactly one platform rulebook. Every design must conform to it.

New PA Cloud projects seed their rulebook from **`templates/power-automate-reference.md`**, which carries the platform behaviours verified by live testing (see `flowagent-trial/`) plus flagged-unverified ones — not everything in it has been proven. Copy it into the project's `docs/`, then let it diverge as that project learns things.

**The template now exists** (created 2026-08-19). `invoice-signature-verification-bot/docs/power-automate-reference.md` predates it and was written independently from platform facts plus `flowagent-trial/`'s findings. The two have been reconciled, and the divergences are deliberate:

- The project rulebook's **solution-build** and **concurrency** rules were good enough to promote into the template (as its R11 and R12). Its ban on default action names became template R13.
- The template's findings **V1–V7 were absorbed into the project rulebook on 2026-08-20** — the `extra-authentication` round-trip trap, OneDrive's create-on-miss behaviour, runtime-only expression faults, the ~90-day connection-token expiry, and three more. ⚠️ Only **V1–V5 are trial-verified**; V6 and V7 are template-asserted, not exercised in `flowagent-trial/`, and are marked ⚠️ rather than 🔬 for exactly that reason. **A PA Cloud design is still checked against both files**: the template states what was observed (or asserted), the project rulebook states what it means for that flow.
- **Rule IDs do not line up between the two files, and never will.** `R5` in the template is not `R5` in the project rulebook. Always cite `<file> R<n>`, never a bare ID — a bare cross-file rule reference is a review finding.

`invoice-signature-verification-bot/` additionally carries `docs/teda-validation-api-reference.md` — a **platform-independent** reference for the external ETDA validation service it integrates with. That file is authoritative on what *ETDA* does; its **`power-automate-reference.md`** is authoritative on how *our flow* is built. Don't conflate them.

- Rules marked ✅ are **project-adopted conventions** — the project's own hard constraints. Rules marked ⚠️ / `U`-numbered are believed-but-unverified platform behavior — treat with caution, flag inline in the design with a documented fallback, and say so explicitly.
- **Where the reference doc is silent, flag the assumption rather than guessing.** Add it to the rulebook's "Unverified platform behaviors" section with a fallback.
- **When the user reports back a live test result** (pass or fail), that overrides any prior assumption immediately — update the reference doc's rule status, add a **Lessons Learned** entry describing what was assumed vs. what's actually true, and fix every affected spot in the design docs in the same pass. Don't leave stale references to a disproven approach anywhere (design doc, reference doc, or `PROGRESS.md`) — sweep for all of them, not just the one the user pointed at.
- **UiPath — watch for uninitialized variables.** A UiPath `Boolean` with no Default is `False` and a `DataTable` with no Default is `Nothing`. Guard flags and accumulator tables need explicit initialization — in concur's case a prologue *before* the outer Try (`concur-cash-advance-bot/docs/uipath-reference.md` R8). This has already produced two would-be silent-failure bugs: a bot that reports success while doing nothing, and a missing run log on the one path where it matters most.
- **PA Cloud — watch for actions that succeed at the wrong target.** The equivalent silent-failure class isn't uninitialized variables, it's connectors that create-on-miss. OneDrive `Create file` **creates missing folders** rather than erroring, so a flow whose path expression has drifted writes to a brand-new wrong folder and reports a green run (verified — `flowagent-trial/test-plan.md`). Any action whose target is built from an expression needs an explicit existence check or a post-condition, because the run history will not tell you. Expression faults are the mirror image: `outputs('X')['prop']` on a scalar passes save-time validation and fails only at runtime.

### Legacy: `pa-desktop-reference.md`

`concur-cash-advance-bot/` was originally built for Power Automate Desktop and still carries a banner-marked `docs/pa-desktop-reference.md` as a historical record. **It is not a rulebook and must never be enforced against a UiPath design — nor against a PA Cloud one.** Its Lessons Learned (L1: never precompute a Boolean for a multi-condition `If`; L2: `Set variable` can never be blank, use `N/A`) are **PA Desktop parser quirks with no equivalent on either live platform** — UiPath's `Assign` has neither restriction and its `If` takes an ordinary VB.NET boolean expression; PA Cloud has no `Set variable` parser of that kind at all and composes conditions in WDL. Applying them anywhere else would be a defect, not a safeguard.

**Now that PA Cloud is live, this file is a bigger trap than it used to be.** A future session skimming for "Power Automate" will find `pa-desktop-reference.md` first and may take it as the PA rulebook. It is not. The PA Cloud rulebook is `docs/power-automate-reference.md`, seeded from `templates/power-automate-reference.md`. Nothing in the PA Desktop file — not its expression syntax (`%Var%` interpolation), not its `Go to`/`Label` control flow, not its variable model — carries over to cloud flows.

## Workflow architecture

### Naming convention (all platforms, non-negotiable)

**Verb + Object** for every activity, action, Sequence, and Scope display name — "Read Config File", "Click Submit Button", "Post Teams Message". This is the one rule that crosses all three platforms.

### UiPath hard constraints (non-negotiable for UiPath projects)

From the `rpa-bot-dev` skill's UiPath hard constraints — these bind every UiPath project here:

- **Single `Main.xaml`.** No `Invoke Workflow File`, no splitting into separate `.xaml` files. UiPath *supports* it; we deliberately don't use it. Organize with nested `Sequence` containers carrying descriptive `DisplayName` values as logical sections.
- **Linear Sequences only** — no Flowchart, no State Machine, no REFramework (REFramework requires Invoke Workflow).
- **Dictionary for structured data** — `Dictionary(Of String, Object)` / `(Of String, String)`. Avoid `DataTable` unless the case is genuine tabular row iteration; each project's rulebook defines where it's sanctioned.
- **Config.xlsx at startup**, read once into a config Dictionary. No hardcoded environment values or credentials (other than the path to `Config.xlsx` itself, which necessarily can't live inside it).
- **Windows project** — target UiPath Windows projects. VB.NET and C# expressions are both acceptable.
- **Verb + Object naming** for every activity and Sequence `DisplayName` ("Read Config File", "Click Submit Button").

### PA Cloud hard constraints (non-negotiable for PA Cloud projects)

Deliberately mirroring the UiPath philosophy — one artifact, explicit structure, nothing environment-specific baked in. Full rationale and the verified platform behaviours live in `templates/power-automate-reference.md`.

- **Single cloud flow.** No child flows, no "Run a Child Flow" fan-out. *Scoped to one process: a separately-triggered monitoring or recovery flow sits outside this rule rather than breaching it, but must be recorded as a decision with its reason and bounds — see `invoice-signature-verification-bot` D6.* Power Automate *supports* it; we deliberately don't — same reasoning as the single-`Main.xaml` rule, and the same trade-off accepted.
- **Scopes as logical sections.** Organize with nested `Scope` actions carrying Verb + Object names, one per logical phase. Scopes are the PA Cloud equivalent of named Sequence containers; a flat wall of 40 actions is not acceptable.
- **Error handling via Scope + "Configure run after".** The Try/Catch/Finally shape is three sibling Scopes: `Try` (has failed / has timed out → `Catch`), and a `Finally` Scope configured to run on *every* outcome. There is no `Throw`; a fatal path uses `Terminate` with status `Failed`.
- **Build inside a Solution, not "My flows".** This is what provides environment variables, connection references, and an export path — without it, the environment-variable option below doesn't exist and the flow can't move between environments.
- **Trigger concurrency is set deliberately, never left at default.** Serial (concurrency 1) keeps run history readable and makes any cross-run counter meaningful; on some triggers it can't be reverted once set, so decide it at build time, not by experiment.
- **No hardcoded environment values.** URLs, site addresses, list names, thresholds, recipients, paths — all come from one config source read once at flow start. Solution-aware flows use **environment variables**; non-solution flows read a config list or file. Which one applies depends on whether the environment has Dataverse, so **state the choice explicitly in the design** rather than assuming.
- **Connections are referenced, never credentialed.** No secrets in the flow definition, ever. Connection authorization is a per-connection human step and must be called out in the implementation guide as such — it cannot be automated away.
- **Expressions are WDL, not VB.NET.** `concat()`, `formatDateTime()`, `coalesce()`, `if()`, `@{...}` interpolation. A UiPath expression pasted into a cloud flow is a defect. Nothing from PA Desktop (`%Var%`) carries over either.
- **Flows are created Stopped** and activated as a deliberate, separately-recorded step — never as a side effect of saving.

### PA Cloud tooling — and why it makes the phase gate matter more

Claude Code can build cloud flows directly. Microsoft's `power-automate` plugin (FlowAgent MCP) is installed and authenticated, and it can create, edit, publish, run, and diagnose flows in a live tenant. `flowagent-trial/` holds the full capability assessment.

**This is exactly why Phase 5 sign-off is now easier to violate than it has ever been.** With UiPath, "building early" means producing a `.xaml` — a file, in the repo, visible in a diff. With PA Cloud, building early means *a flow now exists in a live Microsoft 365 tenant*, invisible to git, possibly running. The rule is unchanged and applies with more force: **no flow is created in any environment before Phase 5 sign-off.** Designing in Markdown is Phases 1–4; the tenant is touched at Phase 6.

Three standing constraints when the tooling is used:

- **Never build in the Default environment.** It holds every maker's personal flows and is under constant concurrent edit. Use a Developer or dedicated sandbox environment. If a live environment is used anyway, capture a pre-work inventory first (see `flowagent-trial/baseline-inventory.md` for the pattern) — in a shared environment, "the agent changed nothing" can only be proven per-artifact, never by a whole-environment diff.
- **Always `preflight_flow` before any write.** It catches the round-trip trap that nothing else does: the write API rejects fields the read API returns.
- **Verify state immediately before a write, not only after.** Skipping the before-check once during the trial produced a confident, wrong defect report that took four controlled experiments to retract.

The tooling's verdict, from live testing: **good for authoring and for triaging failed runs; not to be relied on for verifying correctness.** Succeeded runs expose no action inputs or outputs, so "green run, wrong data" is invisible to it — and that is the failure mode this repo has already been bitten by twice.

### Control-flow patterns (project-level, not skill mandates)

These are conventions adopted in `concur-cash-advance-bot/docs/uipath-reference.md` (R8, R9, P4). They're the patterns to reach for, and worth adopting in a new project — but attribute them correctly rather than citing them as skill law, and check the project's own rulebook first.

- **No `Go to`.** UiPath has no equivalent of PA Desktop's `Go to`/`Label`, and none is to be invented. Early exits use a guard flag (e.g. `runShouldContinue`) initialized in a prologue *before* the outer Try, with later phases wrapped in `If`. Fatal paths `Throw` and are caught by the outer Catch.
- **Cleanup runs from `Finally`** on every exit path, so it must assume nothing — guard each step on a flag recording whether the thing it cleans up was ever created, and wrap each step in its own inner Try-Catch that logs and swallows, so a cleanup failure can't replace the real exception.

## Git workflow

- Design/build work happens on a feature branch per the session's assigned branch (see the session's system instructions for the exact name), never directly on `main`.
- Merge to `main` via a GitHub PR, not a raw push, so there's a reviewable diff — except for small housekeeping changes (like repo config/skill cleanup) the user explicitly asks to commit directly. Use the `gh` CLI (`gh pr create` → `gh pr merge`); the GitHub MCP tools are not always loaded in a session.
- **Verify a push actually landed** rather than assuming — a push can hang on a credential prompt and time out without pushing. Compare SHAs: `git ls-remote origin <branch>` against `git rev-parse HEAD`. Checking only that the branch *exists* is not enough — on a follow-up push to an existing branch it returns the stale SHA and looks like success. `gh auth setup-git`, or pushing with `GIT_TERMINAL_PROMPT=0`, fixes the hang.
- Commit messages: explain *why*, not *what* — the diff already shows what changed.
- Never push, merge, or force anything without the user's go-ahead for that specific action.
- **Before every commit, run the `rpa-design-reviewer` agent on the staged changes first.** Default reviewer model is **Opus** (already set in the agent's frontmatter — don't override it to a smaller model to save time). Loop fix → re-review until PASS, per the mandatory review loop above, then commit. This applies to any commit touching `docs/`, not just a freshly-built phase — small edits (a wording fix, a variable rename) still go through the reviewer before being committed, since a small edit is exactly where a stale cross-reference or dangling variable slips in unnoticed.

## Docs map (per project, e.g. `concur-cash-advance-bot/docs/`)

| File | Purpose |
|---|---|
| `PDD.md` | Process Definition Document — confirmed scope, trigger, steps, exceptions |
| `high-level-design.md` | Phase 2 output — logical phases + phase-flow diagram (**authority** on the flow) |
| `phase-flow.mmd` | Standalone copy of the high-level Mermaid, for rendering only. `high-level-design.md` wins if they disagree; regenerate whenever the flow changes. |
| `medium-level-design.md` | Phase 3 output — purpose/scope, key steps, variables, error handling, flow diagrams per logical phase |
| `detailed-design.md` | Phase 4 output — step-by-step activities (UiPath) or actions (PA Cloud), reviewed per sub-phase |
| `uipath-reference.md` **or** `power-automate-reference.md` | Project constraints, standard patterns, unverified platform behaviors + Lessons Learned — **the rulebook**. Exactly one per project, matching its platform. |
| `PROGRESS.md` | Resume file — read this first every session |

Repo-level, not per-project:

| Path | Purpose |
|---|---|
| `templates/power-automate-reference.md` | Seed rulebook for a new PA Cloud project — copy into the project's `docs/`, then let it diverge. Carries the platform behaviours verified by live testing, plus flagged-unverified ones — not everything in it has been proven. |
| `flowagent-trial/` | The FlowAgent MCP capability trial: what the tooling can and cannot do, and the evidence behind the PA Cloud rules. Not a design project, deliberately outside the phased process. |

`invoice-signature-verification-bot/docs/` additionally carries `teda-validation-api-reference.md` — a **platform-independent** reference for the external ETDA validation service (endpoints, result codes, limits, and the traps in interpreting them). It is authoritative on what *ETDA* does; that project's **`power-automate-reference.md`** is authoritative on how *our flow* is built (its `uipath-reference.md` is superseded — see D5). Its `PROGRESS.md` also carries a **Confirmed decisions** section (D1, D2, …) that binds later phases.

`concur-cash-advance-bot/docs/pa-desktop-reference.md` also exists but is banner-marked superseded — historical record only, see above.
