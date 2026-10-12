# Project Progress — SHANA AR Cloud Flows

> Resume file. A new session should read this first to know exactly where we are.

## What this project is

Automation for the **SHANA AR (Accounts Receivable) team**, built as **Power Automate cloud flows
(PA Cloud)** — one or two flows, depending on the design (see **D1** below). The process itself has
**not been described yet**; everything about *what* the flows do is Phase 1 (Discovery) work.

Location: `RPA for SHANA/AR/ar-cloud-flows/`. Unlike the earlier projects this one is not a top-level
folder — SHANA work is grouped by owning finance team (`RPA for SHANA/AR`, `/AP`, `/Tax`), and this is
the first project under AR. The folder name is **provisional**; rename it once the process has a name,
before content accumulates. On rename, sweep the hard-coded path out of `CLAUDE.md` ("Always resume
from PROGRESS.md" and the "Solution options" platform table), `.claude/agents/rpa-design-reviewer.md`
("Locating the project under review" and item 1 of the docs convention), and this project's own
`docs/power-automate-reference.md` header.

## Platform

**PA Cloud — stated by the user up front (2026-10-12), not yet validated against the process.** The
skill's platform test still has to be applied at the end of Discovery and recorded in the PDD:

- **Does any step need to drive a user interface** (SAP GUI, a thick client, a portal with no API)?
  If yes, that step is UiPath territory, and a PA Cloud + desktop hybrid is a deliberate, recorded
  decision — never a default.
- **Governance checks that change the design, not just the build — establish them in Phase 1:**
  1. **Target environment** — must not be the Default environment (`CLAUDE.md` → PA Cloud tooling).
  2. **Dataverse / Solution** — whether the environment has Dataverse decides between environment
     variables and a config list/file (`docs/power-automate-reference.md` R5, P2).
  3. **Tenant DLP policy** — which connectors may be combined, especially HTTP or any non-M365 connector.
  4. **Licensing** — whether any connector needed is Premium.

Rulebook: `docs/power-automate-reference.md`, seeded 2026-10-12 from `templates/power-automate-reference.md`
(template rules R1–R13 copied in directly; project rules start at R14). Checked jointly with the template.

## Confirmed decisions

*None yet.*

## Pending decisions

### D1 — One cloud flow or two ⬜ OPEN

The user expects **one or two** flows, to be settled by the design. This is not a free choice under
`docs/power-automate-reference.md` R1 (single cloud flow per process, no child flows):

- **Two parts of one process** (one hands work to the other) → **one flow**, split into Scopes. A
  second flow here would be a child-flow split by another name, which R1 forbids.
- **Two genuinely different processes** (different triggers, different outcomes, either useful alone)
  → **two flows**, each its own single flow. Record the second one's reason and bounds as an explicit
  decision, as `invoice-signature-verification-bot` D6 does for its companion flow (D6 is itself still
  pending the user's confirmation, so it shows the shape of the record, not settled precedent).

Decide during Discovery, once the process is understood; record it here and in the PDD. If the answer
is two independent processes, also decide whether they stay one project (one `docs/` set) or split into
two project folders under `RPA for SHANA/AR/`.

## Skill in use

`rpa-bot-dev` — phased design assistant (Discovery → High-Level → Medium-Level → Detailed → Review →
Implementation Guide). Never skip phases; each is confirmed by the user before the next.

**No flow is created in any environment before Phase 5 sign-off** (`CLAUDE.md`; skill PA Cloud hard
constraint 11). The FlowAgent MCP tooling can create flows directly in a live tenant — invisible to git
and possibly running — which is exactly why the gate matters more here than for a `.xaml`.

`CLAUDE.md` governs: **mandatory automatic `rpa-design-reviewer` loop** on every new/edited phase and
before every `docs/` commit — loop fix → re-review until PASS (zero BLOCKER/MAJOR).

## Current phase

**Phase 1: Discovery — not started.** Project scaffolding is in place (this file + the rulebook).
Next step: the user describes the AR process.

## Phase status

- [ ] Phase 1 — Discovery (→ `PDD.md`, platform validated, D1 decided)
- [ ] Phase 2 — High-Level Design
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide

## Open Discovery questions

Asked conversationally, not as a checklist — tracked here so nothing is lost between sessions.

| # | Question | Status |
|---|---|---|
| Q1 | What is the AR process, and what business problem does it solve? Does it relate to the existing `AR Email Classification` flow, which was Started in the PTTEP (Default) environment as of the FlowAgent trial (`flowagent-trial/test-plan.md`, "Blocker found at T0")? | ⬜ Open |
| Q2 | Which systems are involved (Outlook, SharePoint, Excel Online, Teams, Dataverse, SAP, a bank or customer portal)? Does any step need UI automation? | ⬜ Open |
| Q3 | What triggers each flow — event (new email/file/row), schedule, or manual? | ⬜ Open |
| Q4 | Inputs — what data, in what format, from where? | ⬜ Open |
| Q5 | Outputs — what is produced, where does it go, who receives it? | ⬜ Open |
| Q6 | Decision points and business rules. | ⬜ Open |
| Q7 | Exceptions — system errors, business exceptions, edge cases, and how each is handled today. | ⬜ Open |
| Q8 | Volume and frequency. | ⬜ Open |
| Q9 | Which connections/accounts the flows run as (a service account or a named person). | ⬜ Open |
| Q10 | Target environment, Dataverse availability, DLP constraints, Premium licensing (see Platform). As of the FlowAgent trial the tenant had only two environments — PTTEP (Default, ruled out) and SHANA AP (Dataverse for Teams, tied to a real Team) — so a new non-Default environment probably has to be created (`flowagent-trial/test-plan.md`, "Blocker found at T0"). | ⬜ Open |
| Q11 | Delivery model — who builds and maintains the flows (in-house, as for `invoice-signature-verification-bot`, or a handoff). | ⬜ Open |
| Q12 | One flow or two — answered by Q1–Q3; see **D1**. | ⬜ Open |
