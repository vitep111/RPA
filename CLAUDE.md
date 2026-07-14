# CLAUDE.md — RPA Repo Instructions

This repo holds RPA bot design/build work. Read this file first, every session, before doing anything else.

## Always resume from PROGRESS.md

Before any work, read the active project's `docs/PROGRESS.md` (currently `concur-cash-advance-bot/docs/PROGRESS.md`). It states the current phase, what's confirmed, what's blocked, and what's next. Don't re-derive this from guessing at file contents — `PROGRESS.md` is the source of truth for where we are.

## Use the `rpa-bot-dev` skill for all RPA/bot design work

Any task involving UiPath, Power Automate Desktop, RPA, bot development, process automation, or "let's automate X" goes through the `rpa-bot-dev` skill. It is the only skill installed in this repo (`.claude/skills/rpa-bot-dev/SKILL.md`) — deliberately. Don't install or restore other skills.

The skill enforces a **phased process** (Discovery → High-Level Design → Medium-Level Design → Detailed Design → Full Review & Sign-off → Implementation Guide). Rules:
- **Never skip phases.** Each phase must be confirmed by the user before moving to the next.
- **No code or automation files until Phase 5 sign-off.** Everything before that is documentation.
- Confirm **one sub-phase at a time** within Detailed Design — don't draft all 6 sub-phases and present them together.
- If a phase is blocked on an external decision (e.g., login method), flag it explicitly, mark it blocked in `PROGRESS.md`, and keep designing the phases that don't depend on it.

## Review loop for every detailed-design phase

After building or editing **any** detailed-design phase, run the `rpa-design-reviewer` agent (`.claude/agents/rpa-design-reviewer.md`) against it before presenting it to the user for confirmation:
- It checks **correctness** against `docs/pa-desktop-reference.md` and **completeness** against the medium-level design + PDD.
- Loop **fix → re-review** until it returns a clean **PASS** (zero blockers/majors). Minors tied to still-unverified PA Desktop behavior can ship flagged inline, as long as a fallback is documented.
- If the custom agent type isn't loaded mid-session, run the same review instructions via a `general-purpose` agent instead — don't skip the review.

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

## Docs map (per project, e.g. `concur-cash-advance-bot/docs/`)

| File | Purpose |
|---|---|
| `PDD.md` | Process Definition Document — confirmed scope, trigger, steps, exceptions |
| `high-level-design.md` | Phase 2 output |
| `medium-level-design.md` | Phase 3 output — purpose/scope, key steps, variables, error handling, flow diagrams per logical phase |
| `detailed-design.md` | Phase 4 output — step-by-step PA Desktop actions, reviewed per sub-phase |
| `pa-desktop-reference.md` | Verified/unverified PA Desktop syntax rules + Lessons Learned |
| `PROGRESS.md` | Resume file — read this first every session |
