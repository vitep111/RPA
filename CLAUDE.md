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

`invoice-signature-verification-bot/` differs from the other two in one way that changes how it's designed: **it will be built by an external developer, not in-house.** The deliverable is the design package, so anything left implicit becomes a change request after the contract is signed. Its `PROGRESS.md` also carries a **Confirmed decisions** section (D1, D2, …) — decisions the user has explicitly settled, which bind later phases. A later phase contradicting one of those is a defect, not a revision.

## Use the `rpa-bot-dev` skill for all RPA/bot design work

Any task involving UiPath, Power Automate Desktop, RPA, bot development, process automation, or "let's automate X" goes through the `rpa-bot-dev` skill. It is the only skill installed in this repo (`.claude/skills/rpa-bot-dev/SKILL.md`) — deliberately. Don't install or restore other skills.

The skill enforces a **phased process** (Discovery → High-Level Design → Medium-Level Design → Detailed Design → Full Review & Sign-off → Implementation Guide). Rules:
- **Never skip phases.** Each phase must be confirmed by the user before moving to the next.
- **No code or automation files until Phase 5 sign-off.** Everything before that is documentation.
- Confirm **one sub-phase at a time** within Detailed Design — don't draft all 6 sub-phases and present them together.
- If a phase is blocked on an external decision (e.g., login method), flag it explicitly, mark it blocked in `PROGRESS.md`, and keep designing the phases that don't depend on it.

## Review loop — mandatory and automatic

Running the `rpa-design-reviewer` agent (`.claude/agents/rpa-design-reviewer.md`) is **not optional and does not wait for the user to ask.** The moment you finish creating or editing **any new phase, sub-phase, or development step** — a detailed-design sub-phase, a medium/high-level phase, an implementation step, or any edit to a design/reference doc — you **automatically** run the reviewer against it, before you present anything to the user for confirmation and before you commit.

- It checks **correctness** against the project's platform reference doc (`docs/uipath-reference.md`, including its Lessons Learned) and **completeness** against the medium-level design + PDD.
- **Loop `fix → re-review` until the reviewer returns a clean `PASS` with zero BLOCKERS and zero MAJOR items.** One review pass is not the loop — a `FAIL` means fix and re-run, every time, however many rounds it takes. Do not present or commit a phase that has not reached PASS.
- The only findings allowed to remain under a PASS are **MINORS tied to still-unverified platform behavior**, and only when each is flagged inline in the design with a documented fallback.
- **Never skip the review to save time or because a change looks trivial** — a small edit (a wording fix, a variable rename) is exactly where a stale cross-reference or dangling variable slips in. Default reviewer model is **Opus** (set in the agent's frontmatter); don't downgrade it.
- If the custom agent type isn't loaded mid-session (custom agents load at session start), run the same review instructions via a `general-purpose` agent instead — don't skip the review.
- Only after PASS do you present the phase to the user for confirmation, then commit.

## UiPath syntax — don't assume, verify

**All three projects in this repo target UiPath.** Each carries its own `docs/uipath-reference.md` as the source of truth for how the platform behaves and what conventions the project has adopted. Every design must conform to its project's reference doc.

`invoice-signature-verification-bot/` additionally carries `docs/teda-validation-api-reference.md` — a **platform-independent** reference for the external ETDA validation service it integrates with. That file is authoritative on what *ETDA* does; its `uipath-reference.md` is authoritative on how *our bot* is built. Don't conflate them.

- Rules marked ✅ are **project-adopted conventions** — the project's own hard constraints. Rules marked ⚠️ / `U`-numbered are believed-but-unverified platform behavior — treat with caution, flag inline in the design with a documented fallback, and say so explicitly.
- **Where the reference doc is silent, flag the assumption rather than guessing.** Add it to the rulebook's "Unverified platform behaviors" section with a fallback.
- **When the user reports back a live test result** (pass or fail), that overrides any prior assumption immediately — update the reference doc's rule status, add a **Lessons Learned** entry describing what was assumed vs. what's actually true, and fix every affected spot in the design docs in the same pass. Don't leave stale references to a disproven approach anywhere (design doc, reference doc, or `PROGRESS.md`) — sweep for all of them, not just the one the user pointed at.
- **Watch for uninitialized variables.** A UiPath `Boolean` with no Default is `False` and a `DataTable` with no Default is `Nothing`. Guard flags and accumulator tables need explicit initialization — in concur's case a prologue *before* the outer Try (`concur-cash-advance-bot/docs/uipath-reference.md` R8). This has already produced two would-be silent-failure bugs: a bot that reports success while doing nothing, and a missing run log on the one path where it matters most.

### Legacy: `pa-desktop-reference.md`

`concur-cash-advance-bot/` was originally built for Power Automate Desktop and still carries a banner-marked `docs/pa-desktop-reference.md` as a historical record. **It is not a rulebook and must never be enforced against a UiPath design.** Its Lessons Learned (L1: never precompute a Boolean for a multi-condition `If`; L2: `Set variable` can never be blank, use `N/A`) are **PA Desktop parser quirks with no UiPath equivalent** — UiPath's `Assign` has neither restriction, and `If` takes an ordinary VB.NET boolean expression. Applying them to a UiPath design would be a defect, not a safeguard.

## Workflow architecture

### Skill hard constraints (repo-wide, non-negotiable)

From the `rpa-bot-dev` skill's UiPath hard constraints and naming convention — these bind every project here:

- **Single `Main.xaml`.** No `Invoke Workflow File`, no splitting into separate `.xaml` files. UiPath *supports* it; we deliberately don't use it. Organize with nested `Sequence` containers carrying descriptive `DisplayName` values as logical sections.
- **Linear Sequences only** — no Flowchart, no State Machine, no REFramework (REFramework requires Invoke Workflow).
- **Dictionary for structured data** — `Dictionary(Of String, Object)` / `(Of String, String)`. Avoid `DataTable` unless the case is genuine tabular row iteration; each project's rulebook defines where it's sanctioned.
- **Config.xlsx at startup**, read once into a config Dictionary. No hardcoded environment values or credentials (other than the path to `Config.xlsx` itself, which necessarily can't live inside it).
- **Windows project** — target UiPath Windows projects. VB.NET and C# expressions are both acceptable.
- **Verb + Object naming** for every activity and Sequence `DisplayName` ("Read Config File", "Click Submit Button").

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
| `detailed-design.md` | Phase 4 output — step-by-step UiPath activities, reviewed per sub-phase |
| `uipath-reference.md` | Project constraints, standard patterns, unverified platform behaviors + Lessons Learned — **the rulebook** |
| `PROGRESS.md` | Resume file — read this first every session |

`invoice-signature-verification-bot/docs/` additionally carries `teda-validation-api-reference.md` — a **platform-independent** reference for the external ETDA validation service (endpoints, result codes, limits, and the traps in interpreting them). It is authoritative on what *ETDA* does; that project's `uipath-reference.md` is authoritative on how *our bot* is built. Its `PROGRESS.md` also carries a **Confirmed decisions** section (D1, D2, …) that binds later phases.

`concur-cash-advance-bot/docs/pa-desktop-reference.md` also exists but is banner-marked superseded — historical record only, see above.
