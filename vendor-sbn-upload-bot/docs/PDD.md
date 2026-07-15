# Process Definition Document — Daily Vendor SBN Upload Bot

**Status:** Confirmed by user (Phase 1 complete).

## Process Overview
Once per day the bot extracts vendor master records created that day from SAP (SE16N, table LFA1), maps six fields into the SBN-fixed CSV template, uploads that CSV to the SAP Business Network (SBN) web portal, polls the upload status until it resolves, and emails the team a summary with the CSV attached.

## Trigger
Scheduled — once per day (exact time TBC).

## Steps (Happy Path)
1. Initialize — read Config.xlsx, start logging.
2. Log into SAP GUI.
3. Drive SAP GUI screen-by-screen with **UiPath SAP UI automation**: open SE16N → table **LFA1**, enter **Create date = today**, execute, read the status bar for the no-records case, then export the result grid to a file (System → List → Export → Spreadsheet).
4. Pick up the exported file for mapping.
5. Map six fields (Vendor Name, Vendor ID, Tax ID, City, Country, Email) into the SBN CSV template — straight copy, no transformation, into SBN's fixed headers/order.
6. Save the CSV.
7. Log into the SBN web portal → **Upload Vendors** page.
8. Enter upload **Name** (`RPA_Upload_ddMMyyyy_HHmm`), choose the CSV file, leave *Perform AN Supplier Matching* **unchecked**, click **Upload**.
9. Locate the new row in *Upload Details* by its unique Name; click **Refresh Status** and re-read until the status settles.
10. Capture the final status (**Created Vendors** or **Errors Found**).
11. Send a summary email to the team (upload name, vendor count, vendor IDs, final status) with the CSV attached.
12. Close applications cleanly.

## Decision Points
- **No new vendors today** → skip upload; send a "nothing to process" email; end cleanly.
- **Status = Queued** → keep refreshing (every few seconds) until it changes to Created Vendors or Errors Found, up to a short timeout (~1–2 min) before reporting "still queued."
- **Status = Errors Found** → report the status only (no drill-in); a human investigates in SBN.

## Exceptions
- **SAP GUI won't open / login fails** → retry; if still failing, send an error email and stop.
- **SBN upload rejected / status not reached within timeout** → capture and report in the email.
- General/technical failures → logged; error email sent.

## Systems & Applications
- SAP GUI (SE16N, table LFA1) — source
- Microsoft Excel — CSV mapping/generation
- SAP Business Network (web) — upload target
- Microsoft Outlook — summary email

## Input / Output
- **Input:** LFA1 vendor records created today (Excel export from SAP GUI).
- **Output:** SBN-format CSV uploaded to SBN; summary email to the team with the CSV attached.

## Credentials Required
- SAP GUI login.
- SBN web portal login.
- Credential storage / login method — **TBC** (decided later). Stored in Config.xlsx — never hardcoded.

## Volume & Frequency
- ~10–50 vendors/day, once per day.

## Field Mapping (detail in Phase 4)
Six fields, direct copy from the LFA1 export → SBN CSV: Vendor Name, Vendor ID, Tax ID, City, Country, Email. Exact SBN header names/order taken from the user's SBN template file.

## Platform
**UiPath** — chosen for SAP GUI automation, retry/exception handling, and the status-polling loop. (PA Desktop ruled out: weak SAP GUI support, and the flow is not linear.)

## SAP Extraction Approach (decided)
**Native UiPath SAP UI automation, screen-by-screen** (revised from an earlier `.vbs`-scripting approach). **SAP GUI Scripting is enabled** in the environment — required for UiPath's SAP GUI selectors, which are built on the same scripting API. UiPath drives SE16N/LFA1 directly with UI activities (Type Into transaction code, enter table + create-date filter, execute, read the status bar for the empty case, export the grid to a file), then reads the exported file. Chosen for **maintainability**: all steps are visible and debuggable in Studio, no separate VBScript file and no `.vbs`↔UiPath result-file contract to maintain. Trade-off (a few more selectors, marginally slower) is negligible at this volume. All other work (mapping, web upload, status polling, email, error handling) stays in UiPath.

## Open Items (TBC)
1. Scheduled run time.
2. Credential storage / login method for SAP and SBN.
3. Exact SBN CSV header names and order (from the user's template).
4. Exact LFA1 source column names for the six mapped fields.
