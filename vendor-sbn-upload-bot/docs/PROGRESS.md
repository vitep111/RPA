# Project Progress — Daily Vendor SBN Upload Bot

> Resume file. A new session should read this first to know exactly where we are.

## Skill in use
`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review → Implementation Guide). Never skip phases. No bot code/files until Phase 5 sign-off (design docs are fine before then).

## Platform decision
- **UiPath** (confirmed by process characteristics; awaiting explicit user sign-off with the PDD).
- Rationale: SAP GUI automation (SE16N/LFA1), retry/exception handling, and the SBN status-polling loop — none of which suit PA Desktop.
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
  - [x] Phase 1/6 — Initialize & Read Config (reviewer PASS on 2nd pass — fixed: bootstrap error-email paradox → added `FallbackErrorRecipient`; `RunDate` scoped to date-only/SE16N filter, upload-name `HHmm` from `Now` at Phase 3; flagged ⚠️ U4 Excel-scope auto-close. Awaiting user confirmation.)
  - [ ] Phase 2/6 — Extract Vendors from SAP
  - [ ] Phase 3/6 — Map Data to SBN Template
  - [ ] Phase 4/6 — Upload to SBN & Poll Status
  - [ ] Phase 5/6 — Send Summary Email
  - [ ] Phase 6/6 — Cleanup
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Key facts captured (from Discovery)
- **Process:** daily extract of newly-created vendors from SAP → map to SBN CSV → upload to SAP Business Network → summary email.
- **Extraction:** SAP **GUI**, transaction **SE16N**, table **LFA1**, filtered on **Create date = today**; result grid **exported to file**. **DECIDED:** SAP GUI Scripting is **enabled**; extraction uses a **parameterized recorded `.vbs`** invoked from UiPath (date + output path injected), not screen-by-screen native SAP activities. Runs via Invoke VBScript/Invoke Code, stays in Main.xaml.
- **Mapping:** **6 fields**, straight copy (no transformation): Vendor Name, Vendor ID, Tax ID, City, Country, Email. Target CSV layout is **fixed by SBN** (exact headers/order from user's template — user has the file).
- **Upload (SBN web, "Upload Vendors" page, TEST MODE seen):** set **Name** = `RPA_Upload_ddMMyyyy_HHmm`, Choose File, leave **Perform AN Supplier Matching UNCHECKED** (one-way door), click **Upload**. New row appears in **Upload Details** table, matched by the unique Name.
- **Empty-day check:** done in **Phase 2 (SAP step)** — SE16N shows a "no values were found" status-bar message after execute when no records match; bot branches to "nothing to process" email then, skipping export/mapping. (Vendor count/IDs still captured in Phase 3 for the email.)
- **Status:** click **Refresh Status**; statuses = **Created Vendors**, **Errors Found**, **Queued**. Wait while Queued; resolves in **seconds**. On Errors Found, report status only (no drill-in).
- **Email:** to the user's **team**; contents = upload name, vendor count, vendor IDs, final status; **CSV attached**. Empty day → "nothing to process" email.
- **Exceptions:** SAP GUI won't open / login fails → retry, then error email + stop.
- **Volume/Trigger:** ~10–50 vendors/day, once per day (schedule time TBC).

## Open items to resolve in later phases
1. Scheduled run time.
2. Credential storage / login method for SAP and SBN (deferred by user).
3. Exact SBN CSV header names/order (from user's template).
4. Exact LFA1 source column names for the six mapped fields.

See `PDD.md` for the full Process Definition Document.
