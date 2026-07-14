# CLAUDE.md — RPA Repo Instructions

This repo holds RPA bot design/build work. Read this file first, every session, before doing anything else.

## How we work on every project

The repo **is** the workspace. Every project — `concur-cash-advance-bot/` is the template — lives as its own top-level folder, and all of its artifacts (PDD, designs, reference doc, progress file, and eventually the build) are created **inside that folder in this repo**, never in scratch space or only in chat.

- **Claude Code is where we think out loud.** Use the conversation to ask questions, discuss options, and work through decisions. Nothing in chat is the deliverable — the files in the repo are.
- **Confirmed work gets committed.** When a discussion reaches a conclusion or a phase/result is confirmed by the user, capture it in the appropriate repo file and commit it (per the Git workflow below), so the repo is always the durable record of what's been decided. Unconfirmed exploration stays in chat until the user confirms; don't commit half-decided drafts.
- **A new project = a new top-level folder** mirroring the template's `docs/` layout (see Docs map). Start it the same way: Discovery → PDD, then the phased process, with a `PROGRESS.md` as its resume file from day one.
- The result is that anyone (including a future session) can reconstruct the whole state of a project — decisions, rationale, open questions — from the committed files alone, exactly as the cash-advance project already works.

## Always resume from PROGRESS.md

Before any work, read the active project's `docs/PROGRESS.md` (currently `concur-cash-advance-bot/docs/PROGRESS.md`). It states the current phase, what's confirmed, what's blocked, and what's next. Don't re-derive this from guessing at file contents — `PROGRESS.md` is the source of truth for where we are.

## Use the `rpa-bot-dev` skill for all RPA/bot design work

Any task involving UiPath, Power Automate Desktop, RPA, bot development, process automation, or "let's automate X" goes through the `rpa-bot-dev` skill. It is the only skill installed in this repo (`.claude/skills/rpa-bot-dev/SKILL.md`) — deliberately. Don't install or restore other skills.

The skill enforces a **phased process** (Discovery → High-Level Design → Medium-Level Design → Detailed Design → Full Review & Sign-off → Implementation Guide). Rules:
- **Never skip phases.** Each phase must be confirmed by the user before moving to the next.
- **No code or automation files until Phase 5 sign-off.** Everything before that is documentation.
- Confirm **one sub-phase at a time** within Detailed Design — don't draft all 6 sub-phases and present them together.
- If a phase is blocked on an external decision (e.g., login method), flag it explicitly, mark it blocked in `PROGRESS.md`, and keep designing the phases that don't depend on it.

## Review loop — mandatory and automatic

Running the `rpa-design-reviewer` agent (`.claude/agents/rpa-design-reviewer.md`) is **not optional and does not wait for the user to ask.** The moment you finish creating or editing **any new phase, sub-phase, or development step** — a detailed-design sub-phase, a medium/high-level phase, an implementation step, or any edit to a design/reference doc — you **automatically** run the reviewer against it, before you present anything to the user for confirmation and before you commit.

- It checks **correctness** against the project's platform reference doc (e.g. `docs/pa-desktop-reference.md`, including its Lessons Learned) and **completeness** against the medium-level design + PDD.
- **Loop `fix → re-review` until the reviewer returns a clean `PASS` with zero BLOCKERS and zero MAJOR items.** One review pass is not the loop — a `FAIL` means fix and re-run, every time, however many rounds it takes. Do not present or commit a phase that has not reached PASS.
- The only findings allowed to remain under a PASS are **MINORS tied to still-unverified platform behavior**, and only when each is flagged inline in the design with a documented fallback.
- **Never skip the review to save time or because a change looks trivial** — a small edit (a wording fix, a variable rename) is exactly where a stale cross-reference or dangling variable slips in. Default reviewer model is **Opus** (set in the agent's frontmatter); don't downgrade it.
- If the custom agent type isn't loaded mid-session (custom agents load at session start), run the same review instructions via a `general-purpose` agent instead — don't skip the review.
- Only after PASS do you present the phase to the user for confirmation, then commit.

## PA Desktop syntax — don't assume, verify

`docs/pa-desktop-reference.md` is the source of truth for how PA Desktop actually behaves (different from UiPath/VB.NET in several load-bearing ways: `%Var%` interpolation, no quotes on literals, `%3%` for Number values, subflows have no parameters — everything is global). Every design must conform to it.

- Rules marked ✅ are **live-verified by the user in real PA Desktop**. Rules marked ⚠️ are believed correct but unverified — treat with caution, and say so explicitly in the design.
- **Do not assume UiPath/VB.NET behavior carries over.** When a design needs a PA Desktop mechanism that isn't yet in the reference doc as ✅, mark it ⚠️ inline in `detailed-design.md`, give a documented fallback, and add it to the "Open items to verify" list.
- **When the user reports back a live test result** (pass or fail), that overrides any prior assumption immediately — update the reference doc's rule status, add a **Lessons Learned** entry describing what was assumed vs. what's actually true, and fix every affected spot in `detailed-design.md` in the same pass. Don't leave stale references to a disproven approach anywhere (design doc, reference doc, or `PROGRESS.md`) — sweep for all of them, not just the one the user pointed at.
- Known traps already on record (see `pa-desktop-reference.md` → Lessons Learned): `If` supports multiple conditions combined by OR/AND natively — never precompute a Boolean flag for this via `Set variable` (L1); `Set variable`'s Value field can never be left blank — use an explicit literal placeholder like `N/A`, never "(empty)" (L2).

## Flow & subflow architecture

One `Main` flow holds all phases inline (comment-delimited `>> SECTION:` blocks); in-flow `Go to`/`Label` pairs handle retries and only work within a single flow. `WriteLogRow` is the only real subflow, because it's the only piece of logic called from more than one place — PA Desktop subflows take no parameters, so splitting out a single-call-site block buys no encapsulation, only overhead. Don't propose new subflows unless the logic has ≥2 genuine call sites.

## Git workflow

- Design/build work happens on a feature branch per the session's assigned branch (see the session's system instructions for the exact name), never directly on `main`.
- Merge to `main` via a GitHub PR (`mcp__github__create_pull_request` → `mcp__github__merge_pull_request`), not a raw push, so there's a reviewable diff — except for small housekeeping changes (like repo config/skill cleanup) the user explicitly asks to commit directly.
- Commit messages: explain *why*, not *what* — the diff already shows what changed.
- Never push, merge, or force anything without the user's go-ahead for that specific action.
- **Before every commit, run the `rpa-design-reviewer` agent on the staged changes first.** Default reviewer model is **Opus** (already set in the agent's frontmatter — don't override it to a smaller model to save time). Loop fix → re-review until PASS, per the mandatory review loop above, then commit. This applies to any commit touching `docs/`, not just a freshly-built phase — small edits (a wording fix, a variable rename) still go through the reviewer before being committed, since a small edit is exactly where a stale cross-reference or dangling variable slips in unnoticed.

## Docs map (per project, e.g. `concur-cash-advance-bot/docs/`)

| File | Purpose |
|---|---|
| `PDD.md` | Process Definition Document — confirmed scope, trigger, steps, exceptions |
| `high-level-design.md` | Phase 2 output |
| `medium-level-design.md` | Phase 3 output — purpose/scope, key steps, variables, error handling, flow diagrams per logical phase |
| `detailed-design.md` | Phase 4 output — step-by-step PA Desktop actions, reviewed per sub-phase |
| `pa-desktop-reference.md` | Verified/unverified PA Desktop syntax rules + Lessons Learned |
| `PROGRESS.md` | Resume file — read this first every session |
