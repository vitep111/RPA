# Project Progress — Daily Vendor SBN Upload Bot

> Resume file. A new session should read this first to know exactly where we are.

## Skill in use
`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review → Implementation Guide). Never skip phases. No bot code/files until Phase 5 sign-off (design docs are fine before then).

## Platform decision
- **UiPath** (confirmed by process characteristics; awaiting explicit user sign-off with the PDD).
- Rationale: SAP GUI automation (SE16N/LFA1), retry/exception handling, and the SBN status-polling loop — none of which suit PA Desktop.
- UiPath hard constraints apply: linear nested Sequences only, Dictionary for structured data, no Invoke Workflow (all in Main.xaml), Config.xlsx at startup, Verb+Object naming, Windows project.

## Current phase
**Phase 2: High-Level Design — written to `high-level-design.md`, awaiting user confirmation.**
Five sequential phases + cross-cutting exception handling. Flow diagram also in `phase-flow.mmd`.

## Phase status
- [x] Phase 1 — Discovery (PDD confirmed by user)
- [~] Phase 2 — High-Level Design (drafted; awaiting user "yes")
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Key facts captured (from Discovery)
- **Process:** daily extract of newly-created vendors from SAP → map to SBN CSV → upload to SAP Business Network → summary email.
- **Extraction:** SAP **GUI**, transaction **SE16N**, table **LFA1**, filtered on **Create date = today**; result grid **exported to file**. **DECIDED:** SAP GUI Scripting is **enabled**; extraction uses a **parameterized recorded `.vbs`** invoked from UiPath (date + output path injected), not screen-by-screen native SAP activities. Runs via Invoke VBScript/Invoke Code, stays in Main.xaml.
- **Mapping:** **6 fields**, straight copy (no transformation): Vendor Name, Vendor ID, Tax ID, City, Country, Email. Target CSV layout is **fixed by SBN** (exact headers/order from user's template — user has the file).
- **Upload (SBN web, "Upload Vendors" page, TEST MODE seen):** set **Name** = `RPA_Upload_ddMMyyyy_HHmm`, Choose File, leave **Perform AN Supplier Matching UNCHECKED** (one-way door), click **Upload**. New row appears in **Upload Details** table, matched by the unique Name.
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
