# Project Progress — SHANA AR Cloud Flows

> Resume file. A new session should read this first to know exactly where we are.

## What this project is

Automation for the **SHANA AR (Accounts Receivable) team**, built as a **Power Automate cloud flow
(PA Cloud)** using **AI Builder**.

Customers email the AR team at **`AccountReceivable@pttep.com`**, a Microsoft 365 group, so every AR
team member receives every email. Among that mail are two documents the team has to read by hand:
**payment advices** and **withholding-tax (WHT) certificates**. The flow picks up each incoming email,
reads every PDF attachment, decides whether each one is a payment advice, a WHT certificate, or
something else, and extracts a pre-determined set of fields from the two recognised types. It then
sends the extracted fields, with the document type, back to the AR group, in the original email thread
if the platform allows it (`docs/power-automate-reference.md` P10). The customer never receives the reply.

Location: `RPA for SHANA/AR/ar-cloud-flows/`. Unlike the earlier projects this one is not a top-level
folder — SHANA work is grouped by owning finance team (`RPA for SHANA/AR`, `/AP`, `/Tax`), and this is
the first project under AR. The folder name is **provisional**; rename it once the process has a name,
before content accumulates. On rename, sweep the hard-coded path out of `CLAUDE.md` ("Always resume
from PROGRESS.md" and the "Solution options" platform table), `.claude/agents/rpa-design-reviewer.md`
("Locating the project under review" and item 1 of the docs convention), and this project's own
`docs/power-automate-reference.md` header.

**Not this project:** the `AR Email Classification` flow in the PTTEP (Default) environment is the
user's own proof of concept. Leave it untouched (user instruction, 2026-10-12). It is not a design
input and not a deployment target.

## Platform

**PA Cloud, with AI Builder — still provisional.** The user named it up front, and Discovery so far
supports it: every step is email, attachments, and AI Builder, and **no step drives a user interface**, so
the skill's UiPath test points to PA Cloud. It becomes settled when the user confirms the PDD, which
records it with its rationale; update `CLAUDE.md`'s "provisional, pending PDD confirmation" wording in the same pass.

**Governance checks — still to establish in Phase 1, because they change the design:**

1. **Target environment** — must not be the Default environment (`CLAUDE.md` → PA Cloud tooling). As of
   the FlowAgent trial the tenant had only two environments: PTTEP (Default, ruled out) and SHANA AP
   (Dataverse for Teams, tied to a real Team). A new non-Default environment probably has to be created
   (`flowagent-trial/test-plan.md`, "Blocker found at T0"). ⬜ Open.
2. **Dataverse / Solution** — decides between environment variables and a config list or file
   (`docs/power-automate-reference.md` R5, R11, P2). Follows from item 1. ⬜ Open.
3. **Tenant DLP policy** — Office 365 Outlook and AI Builder are expected to be allowed together; any
   P7 fallback to an external service (via a custom connector or connection reference,
   `docs/power-automate-reference.md` P7) would need its own DLP and data-residency check. ⬜ Open.
4. **Licensing** — ✅ The user confirms AI Builder credits / Power Automate Premium are available (2026-10-12).

Rulebook: `docs/power-automate-reference.md`, seeded 2026-10-12 from `templates/power-automate-reference.md`
(template rules R1–R13 copied in directly; project rules start at R14). Checked jointly with the template.
Project-specific unverified behaviours **P7–P10** were added there during Discovery; each is a feasibility
check to settle before the design leans on it.

## Confirmed decisions

Each was stated, chosen, or explicitly delegated by the user on 2026-10-12; where the assistant filled in
detail the user didn't state, it is marked as a design inference. A later phase contradicting one is a
defect, not a revision.

### D2 — The reply goes to the AR group only

The result is sent **only to `AccountReceivable@pttep.com`**, never to the customer and never to anyone
else on the original email. The group delivers it to the whole AR team. The user proposed this in place
of an earlier "reply-all minus the sender" idea, which would have leaked the extracted data to customer
colleagues on CC. Because only one fixed address receives it, no domain guard is needed. The address
comes from config, not the flow definition (`docs/power-automate-reference.md` R5). How to keep the
reply in the original thread is unverified (`docs/power-automate-reference.md` P10).

### D3 — One reply per email, covering every recognised PDF (delegated; re-confirm with the PDD)

When an email carries several recognised PDFs (for example a payment advice and a WHT certificate), the
flow sends **one** reply that lists each document's type and fields. The user delegated this choice to
the design ("whichever fits the design more"), so it is the assistant's choice and is re-confirmed with
the PDD. One reply was chosen because it keeps one message per customer email in the AR thread.
*Assumption to confirm:* the team reads the two documents together when matching a payment.

The same single reply also carries any unlock request from D5: an email with one recognised PDF and one
unreadable PDF gets one reply containing both the fields and the request.

### D4 — An email with nothing recognised gets no reply (except D5)

The user said "no reply for other email". If no attachment is a payment advice or a WHT certificate, and
no PDF was unreadable (D5), the flow sends nothing. *Design inferences from that rule, to confirm with the
PDD:* emails with no attachments, or with no PDFs, also get no reply; and "other" PDFs in a mixed email
are left out of the reply.

### D5 — A PDF that can't be read gets a request for an unlocked copy

Some customers send password-protected PDFs. The user's rule: reply saying the PDF requires a password;
an AR team member then removes the password and replies to the original email with the new PDF. That
reply arrives in the group like any other email and is processed normally.

*Design inferences, to confirm with the PDD:* the rule is widened from "password-protected" to "can't be
read", because telling the two apart is unverified (`docs/power-automate-reference.md` P9, whose
fallback this is); and a reply containing only the unlock request is still sent, since D4 applies only
when no PDF was unreadable.

### D6 — The flow runs as a service account

Connections are owned by, and replies sent from, a dedicated service account, not a named person.
**Loop guard (design inference from D2, to confirm with the PDD):** the flow's own reply lands back in the group, so the flow must ignore
any email sent by its service account. Without this guard it would re-trigger on its own output.

## Pending decisions

### D1 — One cloud flow ⬜ PROPOSED, confirm with the PDD

Discovery shows a **single process with a single trigger**: one email in, one reply out. Under
`docs/power-automate-reference.md` R1 that is one flow, with each phase as a Scope. The two document
types are branches inside it, not separate processes. Proposed by the assistant on 2026-10-12; the user
has not objected, but confirm it explicitly when confirming the PDD.

### D7 — Run record vs "no log" ⬜ OPEN, put to the user 2026-10-12

Asked whether results should also be recorded anywhere (an Excel or SharePoint log), the user answered
**"No."** That conflicts directly with `docs/power-automate-reference.md` R10, which requires every flow
to write a run record (start, end, outcome, key identifiers, error message) from its `Finally` Scope.
R10's reason is `docs/power-automate-reference.md` V3: the platform does not show what an action
produced on a successful run, so without a record a green run that sent wrong data, or sent nothing,
cannot be investigated afterwards. Options put to the user:

- **(a) Keep a minimal technical run log** — one row per email (time, sender, subject, document types
  found, outcome, error), holding no extracted field values. The assistant's recommendation.
- **(b) No log** — waive R10 for this project. The waiver is recorded as a project rule (R14) in
  `docs/power-automate-reference.md`, framed as a recorded, reasoned exception to
  `templates/power-automate-reference.md` R10 that cites V3's consequence, never as a silent override,
  and this entry points to it.

### D8 — Feasibility test of AI Builder before Phase 6 ⬜ OPEN, needs the user's explicit approval

`docs/power-automate-reference.md` P7 (can AI Builder read Thai, English and scanned PDFs?) is the risk most likely to change the design,
and the cheapest way to settle it is to try it on sample PDFs. But `CLAUDE.md` ("PA Cloud tooling") keeps
the tenant untouched until Phase 6, and an AI Builder prompt or model is a tenant artifact. Testing early
therefore needs an explicit exception, approved by the user, with these bounds:

- a **non-Default** environment only — never PTTEP (Default), and never SHANA AP (tied to a real Team)
  without the user's explicit say-so;
- **throwaway** artifacts: prompts or models made for the test are not the build;
- every artifact is **inventoried before and after, then deleted** (`flowagent-trial/baseline-inventory.md`
  is the pattern);
- **no flow** is created.

Until D8 is approved and governance item 1 (environment) is settled, the P7 test is blocked.

## Skill in use

`rpa-bot-dev` — phased design assistant (Discovery → High-Level → Medium-Level → Detailed → Review →
Implementation Guide). Never skip phases; each is confirmed by the user before the next.

**No flow is created in any environment before Phase 5 sign-off** (`CLAUDE.md`; skill PA Cloud hard
constraint 11). The FlowAgent MCP tooling can create flows directly in a live tenant — invisible to git
and possibly running — which is exactly why the gate matters more here than for a `.xaml`. An AI
Builder prompt or model made to test `docs/power-automate-reference.md` P7 is a tenant artifact too, so that test is blocked until D8 is
approved (see D8).

`CLAUDE.md` governs: **mandatory automatic `rpa-design-reviewer` loop** on every new/edited phase and
before every `docs/` commit — loop fix → re-review until PASS (zero BLOCKER/MAJOR).

## Current phase

**Phase 1: Discovery — in progress.** The process, its trigger, outputs, exceptions, volume and run
account are understood (Q1–Q9 answered), and D2–D6 are confirmed (D3 delegated; D3–D6 carry design
inferences to confirm with the PDD).

**Blocking the PDD:**

- **Q13 — the field list for each document type.** The user will provide it. It defines what "extract"
  means and what the reply contains.
- **D7 — run record.** Needs the user's answer.
- **D1 — one flow.** Proposed; confirm with the PDD.

**Blocking the design, not the PDD:** the governance checks (Q10), the delivery model (Q11), and the
feasibility checks `docs/power-automate-reference.md` P7–P10.
P7 (can AI Builder read these documents?) is the one most likely to change the design. Testing it early
needs D8 approved and an environment (Q10) first; sample PDFs and the field list are needed either way.

## Phase status

- [~] Phase 1 — Discovery (Q1–Q9 answered; Q12 proposed; D2–D6 confirmed; Q10, Q11, Q13, D1, D7, D8 open → `PDD.md`)
- [ ] Phase 2 — High-Level Design
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Discovery questions

| # | Question | Answer (2026-10-12) | Status |
|---|---|---|---|
| Q1 | What is the process, and what problem does it solve? Is it related to the `AR Email Classification` flow? | Read payment advices and WHT certificates arriving at the AR group, classify them, extract fixed fields, and send the fields back to the AR team. `AR Email Classification` is the user's POC: leave it alone. | ✅ |
| Q2 | Which systems? Any UI automation? | `AccountReceivable@pttep.com` (Microsoft 365 group), Office 365 Outlook, AI Builder. No UI automation. | ✅ |
| Q3 | What triggers it? | Each new email arriving at the group. Trigger mechanism unverified (`docs/power-automate-reference.md` P8). | ✅ |
| Q4 | Inputs? | PDF attachments only, in Thai, English or both, digital or scanned. Some are password-protected. One document per PDF, but one email can carry several PDFs (for example both types). | ✅ |
| Q5 | Outputs? | One reply per email to the AR group only, listing each recognised document's type and extracted fields (D2; D3, delegated — re-confirm with the PDD). | ✅ |
| Q6 | Decision points and business rules? | Per PDF: payment advice, WHT certificate, or other. No reply when nothing is recognised (D4). Request an unlocked copy when a PDF can't be read (D5). | ✅ |
| Q7 | Exceptions? | Password-protected PDFs (D5). The flow's own reply re-entering the group (D6 loop guard). Further exceptions to be worked through in design. | ✅ |
| Q8 | Volume? | About 40 emails a month per document type: up to about 80 emails and about 80 documents a month (fewer emails when one carries both types). | ✅ |
| Q9 | Which account? | A service account (D6). | ✅ |
| Q10 | Target environment, Dataverse, DLP, licensing? | Licensing confirmed. Environment, Dataverse and DLP still open (see Platform). | 🟡 Partial |
| Q11 | Delivery model — who builds and maintains it? | Not yet asked. | ⬜ Open |
| Q12 | One flow or two? | One process, one trigger, so one flow (D1, proposed). | 🟡 Proposed — confirm with the PDD |
| Q13 | Which fields are extracted from each document type? | The user will provide the list. | ⬜ Open — blocks the PDD |
