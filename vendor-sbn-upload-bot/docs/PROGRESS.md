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
  - [~] Phase 3/6 — Map Data to SBN Template (template-driven columns, straight copy of 6 fields, upload name generated once (date from `RunDate`, `HHmm` from `DateTime.Now`, so a midnight rollover can't misdate it), captures VendorCount/VendorIDs, writes dated CSV. ⚠️ U8 (SBN CSV format). **Email source** = ADR6 `SMTP_ADDR` (SMTP table; ADRC is postal), names TBC (Open Item #4). **Multi-email:** query was designed to filter to the default email (`ADR6.FLGDEFAULT='X'`) → 1/vendor, OUTER join so no-default vendors come through blank (SBN flags). ⚠️ **1/vendor is NOT achieved by the query as built — see "Live finding" below (L1).** Bot-side dedup by Vendor ID is therefore **load-bearing**, not a safety net; blank email is non-fatal. Awaiting user confirmation.)
  - [ ] Phase 4/6 — Upload to SBN & Poll Status
  - [ ] Phase 5/6 — Send Summary Email — **design input carried forward:** report raw row count vs. deduped vendor count in the email whenever they differ (see `medium-level-design.md` Phase 3 step 3). This outlives the L1 finding — don't drop it when the Live-finding section goes.
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

## ⚠️ Live finding — SQVI returns duplicate rows (2026-08-14)
The built query returns **2 identical rows per vendor**. Reported from a live run; recorded as **Lesson L1** in `uipath-reference.md`, with the diagnosis path and the candidate causes in `PDD.md` Prerequisites.

- **Platform reconfirmed:** staying on **SQVI**; SQ01/SQ02 SAP Query was considered and declined (2026-08-14).
- **Next action (business/SAP side):** for one affected vendor's `LFA1~ADRNR`, count rows in ADRC and in ADR6 for that `ADDRNUMBER`. Whichever returns 2 is the culprit; **if both return 1**, the fan-out isn't in the address join — inspect the query's full table list and re-export to rule out a list artifact. Also check whether *every* vendor duplicates or only some: only-some points at the address tables, all-of-them points elsewhere.
- **Dropping ADRC is conditional**, not automatic — it only works if City/Country come from LFA1 (`ORT01`/`LAND1`) rather than ADRC (`CITY1`/`COUNTRY`), which is still open under Open Item #4.
- **Closed when:** a re-run's export has row count == distinct Vendor ID count, with no-default-email vendors present carrying a blank email.
- **Design impact already applied:** Phase 3's de-dup reclassified from safety net to **load-bearing**, and extended to compare all six mapped columns so that "2 identical rows" is distinguished from "2 rows that disagree" (`medium-level-design.md` Phase 3 step 3).
- **Carry into Phase 5 (undrafted):** the summary email must report raw row count vs. deduped vendor count when they differ. While L1 is open the de-dup Warning fires every run, so a run-log entry alone is noise — recorded in P3 and in Phase 3 step 3 so it isn't lost.
- **Watch for:** if ADRC is dropped, the join is **LFA1 ⋈ ADR6**, and every doc still saying `LFA1 ⋈ ADRC ⋈ ADR6` (PDD, PROGRESS, high-level design, medium-level design) must be swept in the same pass.

## Open items to resolve in later phases
1. Scheduled run time — **deferred by user** (2026-08-14), not needed until deployment.
2. Credential storage / login method for SAP and SBN — **deferred by user** (2026-08-14, reconfirmed): design around it, build it later. Phase 2/6's login sub-step stays a designed-but-unfilled placeholder (step 4.Try.1); Phase 4/6's SBN login gets the same treatment. The retry/exception structure around both is settled and won't change when the mechanism is chosen.
3. Exact SBN CSV header names/order (from user's template) — **user to upload** to `reference-files/` (2026-08-14).
4. Exact SQVI query output column names for the six mapped fields — **user to upload** a sample SAP export to `reference-files/` (2026-08-14). Also settles the two straight-copy TBCs: **Tax ID** (`STCD1` vs `STCEG`/VAT) and **Country** (code vs. name) — both silent-bad-data risks, since a wrong value uploads successfully.
5. SQVI query built (LFA1 ⋈ ADRC ⋈ ADR6, 6 fields, create-date parameter) and accessible to the bot's SAP user — **RESOLVED: confirmed built and accessible by user** (2026-08-14). **That confirmation covers existence and accessibility only** — and one of the uncovered points is now **disproven**: the query does **not** return one row per vendor (see Live finding above). Still to verify from the sample export once the duplication is fixed: that vendors with **no default email are present with a blank** rather than missing (if they're missing, `FLGDEFAULT = 'X'` is in a WHERE clause instead of the JOIN ON, collapsing the outer join).

### `reference-files/` drop zone
`vendor-sbn-upload-bot/reference-files/` exists for the two source files behind Open Items #3 and #4 (see its README). Everything in it is **gitignored except the README** — live vendor names, tax IDs, and emails must not reach GitHub.

Once the files land:
- Fill in the Phase 3 mapping table in `medium-level-design.md` with real column names, and resolve the Tax ID / Country TBCs.
- Narrow ⚠️ **U8** (CSV format) and ⚠️ **U10** (export file shape) in `uipath-reference.md`; **U7** (driving the export) and **U2** (empty-day status bar) are *not* answerable from these files — U7 needs a live run, U2 needs a status-bar screenshot from a no-records run. The optional screenshots asked for in the README also narrow **U5** (SAP date format) and **U9** (SQVI navigation).
- Verify the query's outer-join / default-email behavior per #5 above.
- Close #3 and #4 here.

See `PDD.md` for the full Process Definition Document.
