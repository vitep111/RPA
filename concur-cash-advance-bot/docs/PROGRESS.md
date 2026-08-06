# Project Progress — Concur Cash Advance Auto-Submit Bot

> Resume file. A new session should read this first to know exactly where we are.

## Skill in use
`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review → Implementation Guide). Never skip phases. No build files until Phase 5 sign-off; design docs in `docs/` are written continuously.

## ⚠️ Two major changes — the project was rebuilt in place

Anything in git history before this point describes a **different design on a different platform**. Both changes were confirmed by the user.

1. **Platform: Power Automate Desktop → UiPath.** Rebuilt in place in this same folder (not a new project folder). The PA Desktop design survives only in git history.
2. **Report source: Concur admin grid export → scheduled report email.** Concur can schedule the *Cash Advance open items* report as an **hourly email**; the bot reads its Excel attachment from **Microsoft Outlook desktop on the bot machine**. This replaces admin-grid navigation, status filtering, the export click, and the download wait entirely — no grid-export fallback is retained.

   **The work signal is folder membership, never read/unread.** The bot reads a dedicated Outlook **report folder** and *moves* each processed email to a **`Processed` subfolder**; read status is deliberately never consulted. This is not incidental — an earlier unread-based version was rejected because unread status isn't owned by the bot: a human, a reading pane, or a mobile client silently marks reports read and destroys the only work signal, *and* that failure is invisible (reports still arrive on time, so an arrival-based staleness check never fires). Folder membership is state only the bot mutates. It also makes staleness measurable from the newest report across both folders, with no state file.

**Consequence — phases 2 and 3 swapped.** Reading Outlook needs no Concur session, so the report is fetched *before* login:

| # | Phase | Was |
|---|---|---|
| 1 | Initialize & Load Settings | same, minus browser launch |
| 2 | **Get Pending Report (email)** | was Phase 3, via admin grid |
| 3 | **Login to Concur** | was Phase 2 |
| 4 | Process Pending Requests (Loop) | same |
| 5 | Exception Handling | same |
| 6 | Cleanup & Reporting | same, now guarded |

The payoff: the two clean-exit paths (no new report email, empty report) never launch a browser or authenticate at all. On an hourly schedule with 1–5 items per run, most runs are expected to take one of those exits — which also shrinks exposure to the still-open login blocker.

## Rulebook
- **Active:** `uipath-reference.md` — R1–R9 project constraints, P1–P8 patterns, U1–U12 unverified behaviors. The `rpa-design-reviewer` agent checks correctness against **this** file. **Reviewed → PASS (2026-08-06)** after a six-round loop; an earlier draft encoded the rejected unread-based design and was re-synced to folder-membership. New this rebuild, so expect it to grow as the medium-level design lands and as U-items get verified.
- **Superseded:** `pa-desktop-reference.md` — annotated as the PA-era historical record. **Its Lessons Learned L1/L2 are PA parser quirks and must NOT be carried into the UiPath design** (UiPath `Assign` has neither restriction). Its rule 9.1 (`Go to`/`Label` scoping) is void — UiPath has no `Go to`; see `uipath-reference.md` R9 for the replacement guard-flag mechanism.

## Current phase
**Phase 3: Medium-Level Design — next up, not yet started (being rebuilt from scratch).**
Phases 1 and 2 are confirmed and committed. The existing `medium-level-design.md` is stale on both axes at once (PA Desktop constructs *and* the removed grid-export report source) and is being replaced phase by phase, not patched — start with sub-phase 1/6, review to PASS, then confirm with the user before moving on.

## Phase status
- [x] **Phase 1 — Discovery. Confirmed (2026-08-06).** PDD revised for UiPath + email source + folder-membership state, and signed off in that revised form.
- [x] **Phase 2 — High-Level Design. Confirmed (2026-08-06).** Includes the folder-membership revision (folder-based state, split attachment-save vs. attachment-readable failures, Outlook-availability branch, `Config loaded and valid?` branch, `More items?` loop node, 7 open items). Settled.
- [ ] **Phase 3 — Medium-Level Design.** Rebuild for UiPath, one sub-phase at a time, each reviewed to PASS then user-confirmed.
- [ ] **Phase 4 — Detailed Design.** Rebuild for UiPath. **Both previously recorded PASSes are void** (Phase 1/6 and old Phase 3/6) — they reviewed PA Desktop actions against the PA rulebook, and the old Phase 3/6 designed the grid export that no longer exists.
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Open blocker — login method (unchanged, still open)
Plain username/password is **ruled out** (the admin account requires 2FA). Deciding between:
1. **SSO via Windows Integrated Auth** (preferred — silent, no extra steps; needs IT/Azure AD confirmation). Note: **no secret to store** — auth rides on the robot's Windows identity.
2. **Email magic link** — automatable but fragile (inbox access, delivery delay, spam risk).

**Logical phase 3/6 (Login)** — the bot's Login phase, not the process's Phase 3 Medium-Level Design step — stays deferred at *every* design level until this is resolved. Do not draft a medium-level Login design against an undecided login method. Every other logical phase is designed independently of the login mechanism.

> **Note:** an earlier version of this file recorded "Login: plain username/password, no MFA/SSO" as a confirmed Discovery fact. That was **wrong** and contradicted the PDD; it has been corrected here.

## Environment prerequisite (new, shared)
The unattended robot must run as a **specific interactive Windows/AD account**. Two independent parts of the design need it: the Outlook desktop mail profile (classic Outlook automation is Interop/MAPI-based and fails in a disconnected/session-0 context — `uipath-reference.md` U1), and the WIA/SSO login option, which authenticates as that same identity.

## Open items to verify before build
1. **Is the Concur report a full snapshot or a delta?** (`uipath-reference.md` U11) — **the most load-bearing open item.** The **move-early** decision and the backlog-drain rule are safe only for a full snapshot. If it's a delta, both become unsafe: move the message only after all its items succeed, and drop the drain.
2. **Attachment file format** (U6) — Concur report attachments are often `.xls`-named HTML/CSV rather than true OOXML, which would break `Read Range`.
3. **Unattended Outlook access** (U1) — see prerequisite above.
4. **Browser lifetime across phases 3/4/6** (U7) — a single enclosing scope is **ruled out** (Try and Finally are siblings); choose between a browser variable and Close = Never + re-attach in the medium-level design.
5. Outlook specifics: returned-message ordering (U2), sender/subject filter syntax — DASL/MAPI query string, not a plain expression (U3), nested folder addressing (U4), attachment filename collisions across hourly runs (U5), and **`Move Outlook Mail Message` semantics (U12)** — the single load-bearing mechanism of the folder-membership design.
6. Concur UI specifics carried over from the PA design: Act-as impersonation (U8), pending block matching (U9), submit confirmation (U10).

## Key facts captured (from Discovery)
- Entity: **Cash Advance Request** in SAP Concur (web).
- Admin account impersonates each user via the **"Act as"** field.
- Bot already has access to all users.
- **Input: Excel attachment on Concur's hourly scheduled report email**, read from Outlook desktop on the bot machine. Includes User ID.
- Trigger: **scheduled hourly**, unattended. Volume **1–5 per run**.
- No business-validation errors expected (upstream validates) — exceptions are technical/UI only.
- Output: **Excel log** of outcomes — `Submitted` / `Skipped` / `Failed` per item, plus `No report` / `Stale report` / `No items` / `Fatal` at run level. (Daily email of the log remains a future, out-of-scope phase via Power Automate cloud.)

See `PDD.md` for the full Process Definition Document.

## Docs map (this project)

| File | Role |
|---|---|
| `PDD.md` | Process spec — **authority** |
| `high-level-design.md` | Phase 2 output — **authority on the phase flow** |
| `phase-flow.mmd` | Standalone copy of the HLD's Mermaid, for rendering only. **`high-level-design.md` wins** if they disagree — regenerate this file whenever the HLD flow changes. |
| `uipath-reference.md` | Platform rulebook — **authority** (new; see caveat above) |
| `medium-level-design.md` | ⛔ superseded, banner-marked, awaiting rebuild |
| `detailed-design.md` | ⛔ superseded, banner-marked, awaiting rebuild; both recorded PASSes void |
| `pa-desktop-reference.md` | ⛔ superseded, banner-marked, historical record only |
| `PROGRESS.md` | This file — resume authority |

## Things the rebuild must not forget

Carried out of review rounds 2–3, to be settled in the medium-level design:

1. **The R8 prologue.** `runShouldContinue`, `configLoaded`, `browserLaunched`, `attachmentSaved`, and `runLogTable` are all initialized in a Sequence at the top of `Main` that **precedes the outer Try** — *not* inside Phase 1, which sits inside the Try. `runShouldContinue` must start `True` (a UiPath Boolean defaults to `False`, which would silently skip Phases 3 and 4 on every run) and `runLogTable` must be `Build Data Table`'d rather than declared bare (a bare DataTable is `Nothing`, and `Append Range` on it throws — on exactly the path where the log matters most).
2. **The browser cannot live in one enclosing scope** across Phases 3/4/6 — those sit in the `Try` and the `Finally`, which are siblings (U7). Browser-variable or Close=Never + re-attach.
3. **Delete-vs-quarantine on the malformed-attachment path.** `attachmentSaved` is `True` there, so cleanup as written deletes the very file needed to diagnose the bad report. Decide explicitly.
4. **Run-level row convention** — `N/A` in `UserID`/`RequestID` for `No report` / `Stale report` / `No items` / `Fatal` rows (P8). A readability choice, explicitly *not* the void PA rule L2.
5. **`Processed` folder retention is load-bearing for performance, not just tidiness.** U2 says ordering isn't guaranteed, so the staleness query can't use `Top = 1` — it retrieves and sorts the whole folder, on the most common run path. An unbounded folder makes the cheapest path the slowest. Same question for archived attachments if archiving replaces deletion.

## Review loop (mandatory)
After creating or editing **any** phase, sub-phase, or design doc, run the `rpa-design-reviewer` agent against it and loop fix → re-review until **PASS** (zero BLOCKERS, zero MAJOR) before presenting to the user or committing. Reviewer model is **Opus** — don't downgrade it. Custom agent types only load at session start; mid-session, run the same instructions via a `general-purpose` agent rather than skipping the review.
