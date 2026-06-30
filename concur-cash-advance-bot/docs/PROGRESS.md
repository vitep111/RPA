# Project Progress — Concur Cash Advance Auto-Submit Bot

> Resume file. A new session should read this first to know exactly where we are.

## Skill in use
`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review → Implementation Guide). Never skip phases. No code/files until Phase 5 sign-off.

## Platform decision
- **Primary:** Power Automate Desktop (PA Desktop)
- **Fallback:** UiPath — kept ready if web-element reliability (locating the pending block) or error-handling depth blocks development.
- Design is kept **portable**: clear logical phases, self-contained loop body with per-item error isolation, a distinct "config" variable group, and Verb+Object naming — so a switch to UiPath is low-friction.

## Current phase
**Phase 1: Discovery — COMPLETE & CONFIRMED by user.**
Next: **Phase 2 — High-Level Design** (decompose into 3–7 phases + Mermaid flow).

## Phase status
- [x] Phase 1 — Discovery (PDD confirmed)
- [ ] Phase 2 — High-Level Design
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
