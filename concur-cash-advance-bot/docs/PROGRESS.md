# Project Progress — Concur Cash Advance Auto-Submit Bot

> Resume file. A new session should read this first to know exactly where we are.

## Skill in use
`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review → Implementation Guide). Never skip phases. No code/files until Phase 5 sign-off.

## Platform decision
- **Primary:** Power Automate Desktop (PA Desktop)
- **Fallback:** UiPath — kept ready if web-element reliability (locating the pending block) or error-handling depth blocks development.
- Design is kept **portable**: clear logical phases, self-contained loop body with per-item error isolation, a distinct "config" variable group, and Verb+Object naming — so a switch to UiPath is low-friction.

## Current phase
**Phase 4: Detailed Design — in progress.**
Phase 1/6 (Initialize & Load Settings) and Phase 3/6 (Get Pending Report) detailed designs saved in `detailed-design.md`, both reviewed → PASS. Awaiting user confirmation of Phase 3/6 before moving to Phase 4/6 (Process Pending Requests Loop). (Phase 2/6 Login remains blocked, skipped for now.)

## Login blocker (still open)
Password login is out (requires 2FA). Deciding between:
1. SSO with Windows Integrated Auth (preferred — silent, no extra steps) — needs IT/Azure AD confirmation.
2. Magic link via email — automatable but fragile (inbox access, delivery delay, spam risk).
Phase 2/6 detailed design is deferred until this is resolved. All other phases are designed independently of the login mechanism.

## Phase status
- [x] Phase 1 — Discovery (PDD confirmed)
- [x] Phase 2 — High-Level Design (confirmed)
- [x] Phase 3 — Medium-Level Design (complete, all 6 sub-phases; Phase 2/6 flagged blocked)
- [~] Phase 4 — Detailed Design (in progress)
  - **NOTE:** `detailed-design.md` now opens with a **PA Desktop Syntax Conventions** section. All step tables follow it: `%Var%` interpolation, no quotes on literals, `%3%` for Number values, `%...%` for expressions, and — critically — **PA Desktop subflows have NO parameters (all variables are global)**, so callers set `Log*` globals before running `WriteLogRow`.
  - **NOTE:** Right after that, a **Flow & Subflow Structure (decision)** section (reviewed → PASS) makes explicit what was previously implicit: one `Main` flow holds all 6 phases inline (`>> SECTION:` comments, in-flow `Go to`/`Label` retries — including Phase 3's cross-phase jump to `Phase6CleanupStart`), and `WriteLogRow` is the only real subflow. Phase 4's loop is index-based (`CurrentIndex` vs `PendingCount`, reading `%PendingList[CurrentIndex]%` before incrementing), not a `For each`, to match Phase 3's already-initialized `CurrentIndex`. Flags two new unverified PA Desktop behaviors to confirm before/at Phase 4/6's build: `Go to`/`Label` are flow-scoped (reference 9.1), and the datatable row-indexing syntax `%PendingList[CurrentIndex]%` (not yet a reference rule — add one, e.g. 7.5, once confirmed).
  - **REVIEW LOOP:** After building each detailed-design phase, run the `rpa-design-reviewer` agent (`.claude/agents/rpa-design-reviewer.md`) against it. It checks correctness (vs `pa-desktop-reference.md`) and completeness (vs medium-level design + PDD) and returns PASS/FAIL. Loop fix→re-review until PASS (zero blockers/major). Reference doc grows with each verified rule. NOTE: custom agent types only load at session start — mid-session, run the same instructions via a `general-purpose` agent.
  - [x] Phase 1/6 — Initialize & Load Settings (reviewed → PASS on 2nd pass; orphaned-browser retry fix + config-validation + RetryCount init applied. Awaiting user confirmation.)
  - [!] Phase 2/6 — Login to Concur (BLOCKED — deferred until login method decided)
  - [x] Phase 3/6 — Get Pending Report (reviewed → PASS on 3rd pass; fixed: missing fatal handler for unreadable export file, missing retry delay in export-download retry, step-numbering gap, empty-list export-file cleanup. Open assumptions flagged inline: exact admin-grid nav path/URL, filter-control action, Datatable `.Columns` "does not contain" expression. Awaiting user confirmation.)
  - [ ] Phase 4/6 — Process Pending Requests Loop
  - [ ] Phase 5/6 — Exception Handling
  - [ ] Phase 6/6 — Cleanup & Reporting
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Open assumptions to verify in later phases
1. **Block matching:** how to uniquely match the correct pending block when a user has multiple cash advances (likely match by request name/ID from the export, plus pending status).
2. **Submit confirmation:** no popup on submit; success is confirmed by the block leaving pending status or the Submit button disappearing — to be verified.
3. **Return to admin context** between users (clear "Act as") before processing the next row.

## Key facts captured (from Discovery)
- Entity: **Cash Advance Request** in SAP Concur (web).
- Status text shown in test instance was "Issued" as a stand-in; real target status is the **pending submission** block.
- Admin account impersonates each user via the **"Act as"** field (type user name/ID).
- Bot already has access to all users.
- Login: plain **username/password, no MFA/SSO**.
- Input list: **admin grid of pending Cash Advance Requests, exported to Excel**, includes **User ID**.
- Trigger: **scheduled hourly**, unattended. Volume **1–5 per run**.
- No business-validation errors expected (upstream validates) — exceptions are technical/UI only.
- Output: **Excel log** of outcomes (daily email of the log is a future, out-of-scope phase via Power Automate cloud).

See `PDD.md` for the full Process Definition Document.
