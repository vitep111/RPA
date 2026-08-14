# Project Progress — Daily Vendor SBN Upload Bot

> Resume file. A new session should read this first to know exactly where we are.

## Skill in use
`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review → Implementation Guide). Never skip phases. No bot code/files until Phase 5 sign-off (design docs are fine before then).

## Platform decision
- **UiPath** — confirmed with the PDD (user sign-off, Phase 1).
- Rationale: SAP GUI automation (SQVI query over LFA1 ⋈ ADRC ⋈ ADR6), retry/exception handling, and the SBN status-polling loop — none of which suit PA Desktop.
- UiPath hard constraints apply: linear nested Sequences only, Dictionary for structured data, no Invoke Workflow (all in Main.xaml), Config.xlsx at startup, Verb+Object naming, Windows project.

## Working model
Working **directly on `main`** from now on (user instruction). Feature branch `claude/rpa-bot-development-t9ra41` was merged into main. `CLAUDE.md` governs: **mandatory automatic `rpa-design-reviewer` loop** on every new/edited phase and before every `docs/` commit — loop fix→re-review until PASS (zero BLOCKER/MAJOR). Reviewer's updated definition is generalized to any bot (UiPath or PA Desktop); run it via a `general-purpose` agent mid-session since custom agents only load at session start.

## Current phase
**Phase 3: Medium-Level Design — in progress.** Designing each of the 6 phases one at a time (purpose/scope, key steps, variables, error handling, internal flow), reviewer-PASS each before user confirmation. Platform rulebook seeded at `uipath-reference.md`.

## The 6 phases (from confirmed high-level design)
1. Initialize & Read Config
2. Extract Vendors from SAP
3. Map Data to SBN Template
4. Upload to SBN & Poll Status
5. Send Summary Email
6. Cleanup (Finally — always runs)
All wrapped in an outer Try-Catch-**Finally**.

## Phase status
- [x] Phase 1 — Discovery (PDD confirmed by user)
- [x] Phase 2 — High-Level Design (confirmed by user; reviewer PASS. Six phases + outer Try-Catch-Finally.)
- [~] Phase 3 — Medium-Level Design (in progress)
  - [x] Phase 1/6 — Initialize & Read Config (CONFIRMED by user. Reviewer PASS.)
  - [~] Phase 2/6 — Extract Vendors from SAP (**REVISED: extraction transaction SE16N → SQVI** query joining LFA1 ⋈ ADRC ⋈ ADR6, so email is included. Native UiPath SAP UI automation; empty-day = direct SAP status-bar read; export via menu. Added config key `SAPQueryName`, reference ⚠️ U9 (SQVI navigation). **SAP login sub-step BLOCKED** pending credential method (Open Item #2). Re-review after SQVI switch. Awaiting user re-confirmation.)
  - [~] Phase 3/6 — Map Data to SBN Template (template-driven columns, straight copy of 6 fields, upload name generated once from `Now`, captures VendorCount/VendorIDs, writes dated CSV. ⚠️ U8 (SBN CSV format). **Email source** = ADR6 `SMTP_ADDR` (SMTP table; ADRC is postal), names TBC (Open Item #4). **Multi-email handled:** query filters to default email (`ADR6.FLGDEFAULT='X'`) → 1/vendor, OUTER join so no-default vendors come through blank (SBN flags), + bot-side dedup by Vendor ID as safety net; blank email is non-fatal. Awaiting user confirmation.)
  - [ ] Phase 4/6 — Upload to SBN & Poll Status
  - [ ] Phase 5/6 — Send Summary Email
  - [ ] Phase 6/6 — Cleanup
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Key facts captured (from Discovery)
- **Process:** daily extract of newly-created vendors from SAP → map to SBN CSV → upload to SAP Business Network → summary email.
- **Extraction:** SAP **GUI**, transaction **SQVI** (revised from SE16N/LFA1) — a pre-built **query joining LFA1 ⋈ ADRC ⋈ ADR6** so vendor **email** (held in ADR6, absent from LFA1) is included; filtered on **Create date = today**; result grid **exported to file**. **DECIDED (revised):** **native UiPath SAP UI automation, screen-by-screen** (UiPath.UIAutomation.Activities), NOT a `.vbs` script — chosen for maintainability. SAP GUI Scripting is **enabled** (required for UiPath's SAP selectors either way). Empty-day check = read SAP status bar directly in UiPath. **Prerequisite:** the SQVI query must be built by the business and accessible to the bot's SAP user (SQVI queries are user-specific) — **confirmed done 2026-08-14, Open Item #5** (existence/accessibility only; the join design is still to be verified from the sample export).
- **Mapping:** **6 fields**, straight copy (no transformation): Vendor Name, Vendor ID, Tax ID, City, Country, Email. Target CSV layout is **fixed by SBN** (exact headers/order from user's template — user has the file).
- **Upload (SBN web, "Upload Vendors" page, TEST MODE seen):** set **Name** = `RPA_Upload_ddMMyyyy_HHmm`, Choose File, leave **Perform AN Supplier Matching UNCHECKED** (one-way door), click **Upload**. New row appears in **Upload Details** table, matched by the unique Name.
- **Empty-day check:** done in **Phase 2 (SAP step)** — the SQVI query shows a "no values were found" status-bar message after execute when no records match; bot branches to "nothing to process" email then, skipping export/mapping. (Vendor count/IDs still captured in Phase 3 for the email.)
- **Status:** click **Refresh Status**; statuses = **Created Vendors**, **Errors Found**, **Queued**. Wait while Queued; resolves in **seconds**. On Errors Found, report status only (no drill-in).
- **Email:** to the user's **team**; contents = upload name, vendor count, vendor IDs, final status; **CSV attached**. Empty day → "nothing to process" email.
- **Exceptions:** SAP GUI won't open / login fails → retry, then error email + stop.
- **Volume/Trigger:** ~10–50 vendors/day, once per day (schedule time deferred — Open Item #1, needed at deployment).

## Open items to resolve in later phases
1. Scheduled run time — **deferred by user** (2026-08-14), not needed until deployment.
2. Credential storage / login method for SAP and SBN — **deferred by user** (2026-08-14, reconfirmed): design around it, build it later. Phase 2/6's login sub-step stays a designed-but-unfilled placeholder (step 4.Try.1); Phase 4/6's SBN login gets the same treatment. The retry/exception structure around both is settled and won't change when the mechanism is chosen.
3. Exact SBN CSV header names/order (from user's template) — **user to upload** to `reference-files/` (2026-08-14).
4. Exact SQVI query output column names for the six mapped fields — **user to upload** a sample SAP export to `reference-files/` (2026-08-14). Also settles the two straight-copy TBCs: **Tax ID** (`STCD1` vs `STCEG`/VAT) and **Country** (code vs. name) — both silent-bad-data risks, since a wrong value uploads successfully.
5. SQVI query built (LFA1 ⋈ ADRC ⋈ ADR6, 6 fields, create-date parameter) and accessible to the bot's SAP user — **RESOLVED: confirmed built and accessible by user** (2026-08-14). **That confirmation covers existence and accessibility only.** The query-design points in the PDD Prerequisites — LEFT OUTER join to ADR6, with `FLGDEFAULT = 'X'` in the **JOIN ON** condition rather than a WHERE clause — are **not** confirmed and must be verified from the sample export: expect **one row per vendor**, and vendors with **no default email present with a blank** rather than missing from the file. If they're missing, the predicate is in the wrong place and the query needs fixing before go-live.

### `reference-files/` drop zone
`vendor-sbn-upload-bot/reference-files/` exists for the two source files behind Open Items #3 and #4 (see its README). Everything in it is **gitignored except the README** — live vendor names, tax IDs, and emails must not reach GitHub.

Once the files land:
- Fill in the Phase 3 mapping table in `medium-level-design.md` with real column names, and resolve the Tax ID / Country TBCs.
- Narrow ⚠️ **U8** (CSV format) and ⚠️ **U10** (export file shape) in `uipath-reference.md`; **U7** (driving the export) and **U2** (empty-day status bar) are *not* answerable from these files — U7 needs a live run, U2 needs a status-bar screenshot from a no-records run. The optional screenshots asked for in the README also narrow **U5** (SAP date format) and **U9** (SQVI navigation).
- Verify the query's outer-join / default-email behavior per #5 above.
- Close #3 and #4 here.

See `PDD.md` for the full Process Definition Document.
