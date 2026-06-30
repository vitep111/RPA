# Process Definition Document — Concur Cash Advance Auto-Submit Bot

**Status:** Confirmed by user (Phase 1 complete).

## Process Overview
Cash Advance Requests created via an upstream app land in SAP Concur in a *pending submission* state and require a manual Submit click inside Concur to move forward. This bot eliminates that manual step by impersonating each affected user (via the admin "Act as" feature) and clicking Submit on their behalf, then logging the result.

## Trigger
Scheduled — runs hourly (unattended).

## Steps (Happy Path)
1. Launch browser and log into Concur web as the admin account (username/password).
2. Navigate to the admin grid listing pending Cash Advance Requests.
3. Export the grid to Excel.
4. Read the Excel export into structured data (one record per pending request, including User ID).
5. For each pending record:
   1. Enter the user's name/ID into the **"Act as"** field to impersonate them.
   2. Navigate to that user's **Cash Advances** screen.
   3. Locate the request block in pending submission status.
   4. Click into the block.
   5. Click **Submit**.
   6. Confirm the submission registered, and log the outcome.
   7. Clear "Act as" / return to admin context before the next user.
6. Write the run summary to the Excel log.
7. Close the browser cleanly.

## Decision Points
- **Is the exported report empty?** → No pending items; log "nothing to process" and exit cleanly.
- **Was a matching pending block found for the user?** → Yes: submit. No: log "block not found / skipped".
- **Did Submit register successfully?** → Yes: log success. No: log failure with reason.

## Exceptions
- Concur login fails (bad credentials, page not loading) → retry, then abort run with logged error.
- "Act as" switch fails for a user → log and skip that user, continue with the next.
- Pending block not found on the user's screen → log and skip.
- Submit click fails / page error → retry the single item; on repeated failure, log and continue.
- One item failing must **not** stop the rest of the loop (per-item isolation).

*(Note: business validation is handled upstream, so no policy/validation errors are expected at submit — exceptions here are technical/UI only.)*

## Systems & Applications
- SAP Concur (web, browser-based) — single application.
- Microsoft Excel (read the exported report; write the run log).

## Input / Output
- **Input:** Excel export of pending Cash Advance Requests from the Concur admin grid (includes User ID).
- **Output:** Excel log capturing, per item: User ID, request identifier, outcome (Submitted / Skipped / Failed), reason, and timestamp.

## Credentials Required
- Concur admin account (username/password). Stored in Config — never hardcoded.

## Volume & Frequency
- Hourly, unattended. 1–5 requests per run.

## Platform
**Power Automate Desktop (primary).** UiPath kept as a ready fallback if web-element reliability or error-handling depth becomes a blocker during development. Design is kept platform-portable to ease that switch.
