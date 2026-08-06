# Process Definition Document — Concur Cash Advance Auto-Submit Bot

**Status:** Confirmed by user (Phase 1 complete). Revised for the UiPath rebuild, the email-sourced report, and folder-membership state — **revision confirmed 2026-08-06**.

## Process Overview
Cash Advance Requests created via an upstream app land in SAP Concur in a *pending submission* state and require a manual Submit click inside Concur to move forward. This bot eliminates that manual step by impersonating each affected user (via the admin "Act as" feature) and clicking Submit on their behalf, then logging the result.

## Trigger
Scheduled — runs hourly (unattended).

## Steps (Happy Path)
1. Initialize run state, then read configuration.
2. Check the configured Outlook **report folder** on the bot machine for scheduled *Cash Advance open items* report emails from Concur — **matched by sender/subject and folder membership, not by read status** — sorted newest-first by received time. Take the newest and save its Excel attachment to the configured attachment folder under a per-run unique filename.
3. Read the attachment into structured data (one record per pending request, including User ID), then **move that email — and any older report emails still in the folder — to the configured `Processed` subfolder**.
4. Launch browser and log into Concur web as the admin account (login method TBD — see Credentials Required).
5. For each pending record:
   1. Enter the user's name/ID into the **"Act as"** field to impersonate them.
   2. Navigate to that user's **Cash Advances** screen.
   3. Locate the request block in pending submission status.
   4. Click into the block.
   5. Click **Submit**.
   6. Confirm the submission registered, and log the outcome.
   7. Clear "Act as" / return to admin context before the next user.
6. Write the run summary to the Excel log.
7. Delete (or archive) the saved attachment file.
8. Close the browser cleanly — only if one was launched.

## Decision Points
- **Is there a report email waiting in the report folder?** → No: check staleness (below), then exit cleanly *without launching the browser or logging in*. Yes: continue.
- **Has no report arrived for longer than `StaleReportHours`?** → Yes: log a `Stale report` warning. No: log `No report`. Either way, clean exit.
- **Could the attachment be saved to disk?** → No: abort with a logged fatal error **without moving the email** — this is an environmental fault (path, permissions, disk), the report itself is fine, and it must stay in the folder to be retried next run. Yes: continue.
- **Is the saved attachment readable, with the expected columns?** → No: **move the email to `Processed` first** (so a malformed report can't fail the bot identically on every subsequent run), then abort with a logged fatal error. Yes: continue.
- **Is the report empty?** → No pending items; log `No items` and exit cleanly, again without logging in.
- **Was a matching pending block found for the user?** → Yes: submit. No: log "block not found / skipped".
- **Did Submit register successfully?** → Yes: log success. No: log failure with reason.

## Exceptions
- No report email waiting in the report folder (Concur schedule delayed or failed) → **not an error**: log `No report` and exit cleanly. The next hourly report re-lists any still-open item, so nothing is lost.
- **No report has arrived for longer than `StaleReportHours`** → still a clean exit, but log a **`Stale report` warning** so a permanently broken pipeline (schedule disabled, sender changed, a server-side rule filing the mail elsewhere, mailbox full) becomes visible instead of looking like a quiet hour forever. Measured as the received time of the newest report in **either** the report folder or the `Processed` subfolder — both are folders the bot itself controls, so this figure is always available and cannot be falsified by someone reading the mailbox.
- Outlook not available / mail profile not loaded / configured folder missing → abort run with logged error.
- Attachment cannot be saved to the attachment folder (path missing, permissions, disk) → abort run with logged error, and **leave the email in the report folder** so the next run retries it. This is an environmental fault, not a bad report — consuming the email here would discard a perfectly good one.
- Saved attachment is missing, unreadable, or missing expected columns → **move the email (and the rest of the folder's backlog) to `Processed` first**, then abort run with logged error. Moving before aborting prevents a malformed report from failing the bot identically on every subsequent run, and draining the backlog at the same time stops a later run from picking up a superseded snapshot.
- Concur login fails (bad credentials/SSO/magic-link error, page not loading) → retry, then abort run with logged error.
- "Act as" switch fails for a user → log and skip that user, continue with the next.
- Pending block not found on the user's screen → log and skip.
- Submit click fails / page error → retry the single item; on repeated failure, log and continue.
- One item failing must **not** stop the rest of the loop (per-item isolation).

*(Note: business validation is handled upstream, so no policy/validation errors are expected at submit — exceptions here are technical/UI only.)*

## Systems & Applications
- SAP Concur (web, browser-based) — for the Act-as impersonation and Submit clicks.
- Microsoft Outlook (desktop, on the bot machine) — receives Concur's scheduled report email and supplies the Excel attachment.
- Microsoft Excel (read the report attachment; write the run log).

## Input / Output
- **Input:** Excel attachment on Concur's scheduled *Cash Advance open items* report email, delivered hourly to the bot machine's Outlook mailbox (includes User ID). Replaces the earlier approach of navigating the Concur admin grid and exporting it manually — see Key Design Decisions.
- **Output:** Excel log capturing, per item: User ID, request identifier, outcome, reason, and timestamp. Outcome values: `Submitted` / `Skipped` / `Failed` (per-item), and `No report` / `Stale report` / `No items` / `Fatal` (run-level).
- **Intermediate:** the saved report attachment, written to the configured attachment folder with a per-run unique filename and **deleted** during cleanup so files don't accumulate across hourly runs. (If archiving is preferred over deletion, it needs an explicit retention window — otherwise it reintroduces the unbounded accumulation the cleanup step exists to prevent.)
- **Mailbox side effect:** processed report emails accumulate in the Outlook `Processed` subfolder. That folder is the staleness reference, so it must retain at least the most recent report; beyond that it needs its own retention/rotation policy (mailbox housekeeping, not bot logic).

## Credentials Required
- Concur admin account — login method **not yet decided (open blocker)**. Plain username/password is ruled out (account requires 2FA). Under consideration:
  - **SSO via Windows Integrated Auth** (preferred — silent, no extra steps, pending IT/Azure AD confirmation). Note this option has **no secret to store**: authentication rides on the robot's Windows identity, so nothing goes in Config.xlsx.
  - **Email magic-link** (automatable but fragile — inbox access, delivery delay, spam risk). This option *does* need credentials/settings in Config.xlsx — never hardcoded.
- Phase 3/6 (Login) design stays deferred until this is resolved; all other phases are designed independently of the login mechanism.

### Environment prerequisite (applies to both options)
The unattended robot must run as a **specific interactive Windows/AD account**, because two separate parts of the design depend on it: the Outlook desktop mail profile the bot reads (classic Outlook automation needs an installed Outlook with a loaded profile in an interactive session — it will not work from a disconnected/session-0 context), and the WIA/SSO option above, which authenticates as that same Windows identity. This is a single shared infrastructure requirement, not two independent ones.

## Volume & Frequency
- Hourly, unattended. 1–5 requests per run. Concur's scheduled report email is set to the same hourly cadence, so in steady state each bot run consumes one new report. Under schedule drift or a missed run (machine down, robot offline) several reports can be waiting in the folder — the bot processes the newest and drains the older ones, per the backlog rule below.

## Key Design Decisions
- **Report comes from email, not the admin grid.** Concur can schedule the *Cash Advance open items* report as an hourly email. Reading that attachment removes the four most fragile steps in the original design (admin-grid navigation, status filtering, the export click, and the download-completion wait), along with the unverified assumptions attached to them.
- **Report is read before login.** Reading Outlook needs no Concur session, so the bot only launches the browser and authenticates when the report actually contains work. On an hourly schedule with 1–5 items per run, most runs are expected to find nothing and will exit without ever logging in — which also limits exposure to the unresolved login blocker.
- **State is folder membership, not read/unread.** The bot reads a dedicated Outlook **report folder** and moves each processed email into a `Processed` subfolder. "Waiting in the report folder" means unprocessed; "in `Processed`" means done. Read status is never consulted.

  > This deliberately replaces an earlier unread-based design. Unread status is **not owned by the bot** — a human opening the mailbox, an Outlook reading pane, or a connected mobile client silently marks reports read and destroys the bot's only work signal. Worse, that failure is invisible: the reports still *arrive* on schedule, so a staleness check based on arrival time never fires, and the bot exits "No report" cleanly, forever. Folder membership is state only the bot changes, so the failure mode disappears rather than being documented around.

- **Selection order.** Report emails are matched by sender/subject within the report folder and **sorted explicitly by received time descending** — activity default ordering is not relied on. The newest is processed.
- **Move once the attachment is in memory** — not after the processing loop. Moving late would risk double-processing after a mid-loop crash; moving early costs at most one hour's report, which self-heals on the next run.
- **Backlog drain.** Older report emails left in the folder by a missed run are moved to `Processed` too, without being processed. They are superseded snapshots — anything still open appears in the newest report. This also runs on the malformed-attachment abort path, so no run can later pick up a stale leftover.
- **Staleness is measurable because the bot owns both folders.** The newest received time across the report folder and `Processed` gives a true "last time a report arrived", needing no persisted state file and immune to anyone reading the mailbox.

> ⚠️ **Load-bearing assumption to verify:** every rule above depends on Concur's scheduled report being a **full snapshot of all currently-open items**, not a delta of items created since the last send. If it is a delta, move-early and the backlog drain both become unsafe — a missed or failed item would be lost permanently — and the error strategy must change to move-after-successful-processing, with no backlog drain. **Confirm against the actual Concur report definition before build.**

## Platform
**UiPath.** Originally designed for Power Automate Desktop; rebuilt on UiPath per decision to standardize on it, and because the process needs per-item exception handling/isolation and multiple conditional decision points (empty report, block-not-found, submit-failure) — both criteria that favor UiPath per the platform-selection rule. The PA Desktop design is retained in git history for reference; this project's `docs/` now carry the UiPath design going forward.
