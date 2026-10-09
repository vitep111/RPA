# Project Progress — Invoice Signature Verification Bot

> Resume file. A new session should read this first to know exactly where we are.

## What this project is

Invoices arrive by email as attachments — **PDF and/or XML** (decision **D3**), including the
**PDF/A-3-with-embedded-XML** form Thai e-Tax invoices commonly take (**Q17**). Someone has to establish
whether each one carries a **digital signature** and whether that signature is **valid** — today done by
hand, by uploading the file to **https://validation.teda.th/th/validate** (ETDA's TEDA Web Validation
service) and reading the result off the screen. This bot automates that check.

## Delivery model — read this before designing anything

**Changed 2026-08-19: the user builds this in-house.** It was previously scoped for an external
developer (2026-08-17); decision **D5** moving the platform to PA Cloud removed the need, since the
user builds PA Cloud flows themselves.

What that relaxes: the "nothing may be left implicit" bar was set for a contract handoff, where an
unanswered question becomes a change request or a bill. Building it yourself, the open questions become
things decided during the build, and tenant-specific knowledge no longer has to be written down.

**What it does not relax — and this is the part worth protecting.** The traps in
`teda-validation-api-reference.md` bite whoever builds this, in-house or not:

- expired-certificate is **Trusted**, so date arithmetic silently rejects legitimate invoices;
- `N0002`/`N0001` conflate "unsigned" with "signed in an unsupported format";
- *Could not check* must never collapse into "unsigned", or an ETDA outage reports as a wall of
  unsigned invoices;
- re-saving a file manufactures `E0002`, evidence of tampering, against an innocent supplier.

None of those are handover artifacts. They are the reason the design exists, and they survived both the
platform change and the delivery-model change untouched.

⚠️ One thing gets *harder* in-house, not easier: there is no second pair of eyes. A contractor would
have read the brief and asked questions. Fallback: the reviewer loop stays mandatory, and the Phase 6
guide is still written as if for a stranger — because in twelve months, that is who maintains it.

## Platform decision

✅ **Settled 2026-08-19 — Power Automate Cloud** (decision **D5**, superseding D2's UiPath choice).
The live rulebook is **`power-automate-reference.md`**; `uipath-reference.md` is retained
banner-marked as superseded, because D5 depends on an unverified tenant DLP policy and the design
reverts to UiPath if that check fails.

`teda-validation-api-reference.md` is platform-independent and was unaffected by the change.

## Confirmed decisions

Decisions the user has explicitly confirmed. These are settled and bind later phases — a later phase
that contradicts one of these is a defect, not a revision. *(One provisional entry — **D6**, marked
inline — is recorded here because later content already depends on it, but is not yet user-confirmed.)*

### D1 — Validate via ETDA's API, not by automating the website

**Confirmed by user, 2026-08-17.** The bot calls the TEDA Web Validation **API**. It does **not** drive
the upload form at https://validation.teda.th, which is what the current manual process does.

Reasons, in the order that decided it:

1. **The bot can run unattended.** ⚠️ RPA-style UI automation typically needs a logged-in Windows
   session with a visible browser — a machine that can't be locked, that breaks if someone connects
   over RDP, and that constrains scheduling. An HTTP call runs headless on a server. *(Headless browser
   automation does exist, so this is a statement about the usual RPA tooling — then UiPath, per the
   superseded D2 —
   rather than an absolute. It does not change the conclusion: headless browser driving would still
   carry every other drawback below.)*
   ⛔ **Historical caveat, void under D5.** While the platform was UiPath this reason was undercut by
   `uipath-reference.md` U4 (Outlook Interop needing an interactive session). D5 removed that entirely —
   the Office 365 Outlook connector needs no session — so **reason 1 is now stronger, not weaker**. The
   caveat returns only if the project reverts to D2.
2. **Two of the five outcomes are untestable through the website.** *Warning* and *Could not check*
   depend on ETDA-side conditions that cannot be produced on demand. Against the API the developer
   tests them with recorded JSON; through the UI those paths ship unexercised — including the one that
   stops an ETDA outage being reported as "unsigned".
3. **Explicit codes beat rendered colours.** The API returns `S0003` vs `E0003` (the trap-1
   distinction) as data. The page renders a colour and Thai prose. ⚠️ We have **not seen the portal's
   result screens** (no screenshots yet — see the drop zone), so "it may not display the full
   per-signature detail" is an inference from the FAQ's four-colour description, not an observation.
   Fallback: it does not affect the decision, because even in the best case the UI route means deciding
   invoice validity by matching rendered Thai text, which a restyle changes silently.
4. **It is the sanctioned route.** ⚠️ ETDA's terms of service contain **no clause about automation
   either way** — "not prohibited" is our inference from that silence, not something ETDA has stated,
   and it is the softest of these five reasons. What *is* documented: the terms are written for a
   person using a website, and ETDA publishes the API expressly for programmatic use. Fallback, costing
   nothing: **ETDA question 9** asks them to confirm automated/bulk submission is permitted, alongside
   the key request.
5. **Maintenance asymmetry.** A documented HTTP contract changes rarely and visibly; third-party
   selectors break silently. ⛔ Originally argued in terms of a fixed-price external build ("after the
   warranty ends"); under the in-house model (D5) the argument is unchanged but the cost lands on the
   user rather than on a contract.

**Binding design constraint that follows:** the validation call is **isolated as a single logical step**
with a defined output contract — see **implication 1** in the reference doc for what counts as isolated
and exactly what the step must hand back. Nothing outside it reads raw JSON, HTTP codes, or page
content. Phases 2–4 must preserve that boundary.

⚠️ **What the boundary does and does not buy.** It means most of the bot — mailbox reading, the
outcome/disposition model, reporting, dispatch — does not care how validation happened. It does **not**
make the two routes interchangeable: the audit trail (implication 8, Q14) depends on `TransactionID`,
which only the API produces; **reason 3** says a UI route may not yield per-signature codes; and
**reason 2** says two of the five outcomes could not be tested at all. So the boundary **limits** the
cost of a fallback rather than eliminating it. Fallback if the key is refused: re-open implication 8
and Q14 then, rather than assuming a clean swap.

**Explicitly not doing:** building both paths. That doubles the build cost to insure against something
there is no evidence will happen.

⚠️ **Residual risk — the API key is not self-service** and comes from a formal request to a government
agency, with an unknown lead time. Mitigated by starting the request during design (see below); and
**limited, not eliminated,** by the isolation constraint above. *This risk was disclosed before the decision was taken.* Note that the
user confirmed D1 without raising the two caveats offered — prior compliance sign-off on the manual
website process, or procurement friction over an API key — so neither is treated as blocking. Q9
(compliance sign-off for automated bulk submission) remains open on its own merits regardless.

### D2 — Platform is UiPath ⛔ SUPERSEDED BY D5 (2026-08-19)

> **No longer in force.** D5 moved the platform to PA Cloud. Retained because D5 rests on an unverified
> tenant DLP check (`power-automate-reference.md` U1) — if that fails, D2 is what the project reverts to.
> Its consequences below describe the **UiPath** path and must not be applied to the PA Cloud design.

**Confirmed by user, 2026-08-18; superseded 2026-08-19.** Closed Q7 at the time. No waiver of the repo-wide `rpa-bot-dev` constraints is
needed: single `Main.xaml`, linear nested Sequences, Config.xlsx at startup, Dictionary over DataTable,
Verb+Object naming, Windows project — all apply as written.

Consequences now settled rather than conditional:

- The **SHA-256 digest** requirement means `UiPath.Cryptography.Activities` is a **confirmed package
  dependency**, not a maybe. ❓ Still to verify: that it emits **lowercase hex** rather than Base64 or
  uppercase, since `P1002` is the only feedback on getting it wrong — tracked as `uipath-reference.md`
  **U3**.
- D1's isolation boundary is realised as a **named `Sequence`** — the rulebook's permitted form, since
  `Invoke Workflow File` is banned. The contract matters, not the packaging (implication 1).
- The project rulebook `uipath-reference.md` is now seeded, as required by repo `CLAUDE.md`.

### D3 — Both PDF and XML invoices are in scope

**Confirmed by user, 2026-08-18.** Closes Q11, and **widens the project** — the original requirement
said "invoice pdf". Thai e-Tax invoices circulate in both forms, so this is the right call, but it is
not a free one:

- ETDA returns **different result structures** for XML (`XmlSignatureResult`, `XmlStructureResult`,
  `XMLfhirResult`) than for PDF. More parsing, and a second set of codes.
- **`N0001`** — previously treated here as an anomaly, because it is the XML-only "no signature or
  unsupported format" code — becomes an **ordinary business outcome** on the XML path.
- The **size limit differs by nearly 7×** (PDF 20,480 KB vs XML 3,072 KB), so the pre-flight check is
  per file type.
- ⚠️ It raises **two new questions that did not exist while the scope was PDF-only — Q16 and Q17.**
  Q16 in particular is not a detail: ETDA validates XML **structure** against registered e-Tax schemas,
  which asks a completely different question from "is it signed", and the business may want one, both,
  or either.

### D4 — Outcome and disposition mapping

**Confirmed by user, 2026-08-18** (closes Q3, by accepting the proposed defaults in full).

| Result | Outcome | Disposition |
|---|---|---|
| `S0001` `S0002` `S0003` `S0004` | Trusted | **Accept** |
| `E0002` `E0003` `E0006` `E0009` | Untrusted | **Reject** |
| `E0004` `E0005` | Warning | **Manual review** |
| `N0002` (PDF) / `N0001` (XML) | No supported signature | **Manual review** |
| `E0001` after retries, `N9999`, unrecognised codes, `P2001`/`P2003`/`P2004`, `P1002`/`P1004`/`P1005`, transport & auth failures | Could not check | **Manual review** |
| `P1001` `P1003` | *(business exception, not an outcome)* | **Manual review** |

⚠️ This table is the authority on the *mapping*; see **implication 5** in the service reference for the
full trigger list and for the **Retry** staging state, which is not a resting outcome — it resolves to
*Could not check* / Manual review when exhausted. `N0001` on a **PDF** result is anomalous and routes to
*Could not check* (trap 5); on an **XML** result it is the ordinary *No supported signature* (D3).

Plus: **multiple signatures combine most-severe-wins** (Could not check > Untrusted > Warning > No
supported signature > Trusted), and a **timestamp-only document is not "signed"**.

⚠️ Deliberately conservative — **nothing auto-accepts except Trusted**. At ~10 invoices/week (Q6) the
manual-review queue costs roughly one item a week, so the cautious reading is close to free here, which
is what makes it the right call rather than merely the safe one. Fallback: every row lives in config
(implication 5), so tightening or loosening is an edit, not a rebuild. A documented alternative — ranking
Untrusted above Could not check, so a definite bad finding auto-rejects — is recorded with the
aggregation rule in the service reference and can be adopted later.

### D5 — Platform moves to Power Automate Cloud, built in-house

**Confirmed by user, 2026-08-19.** Supersedes **D2**. The bot is a **PA Cloud flow** (Office 365 Outlook
trigger) calling an **Azure Function** that performs the whole ETDA exchange. The user builds it
themselves; no external developer.

**What drove it.** Once D1 removed the browser automation, *there is no UI automation left in this
process* — it reads email and makes HTTP calls. That is integration work, and using an RPA robot for it
meant paying for a licensed machine and a Windows session to do something a connector does natively.

Three concrete gains:

1. **`uipath-reference.md` U4 disappears.** Classic Outlook activities need Interop/MAPI with a loaded
   profile in an interactive Windows session — the largest deployment risk in the UiPath design, and the
   thing that partly undercut D1's own "runs unattended" reason. The Office 365 Outlook connector needs
   none of it. The mailbox is **M365** (confirmed 2026-08-19), so the connector applies.
2. **The trigger question mostly answers itself** — "when a new email arrives" is event-driven, so Q6's
   outstanding half needs no polling interval.
3. **No robot licence, no VM, no external build cost.** At ~10 invoices/week this is far better
   proportioned.

**The one hard dependency: SHA-256.** PA Cloud has no hash expression or standard action, and ETDA's
`digest` is mandatory. Resolved by putting the hash — and the whole ETDA call — inside an **Azure
Function**, which doubles as D1's isolation boundary. ⚠️ A third-party hashing connector was
**rejected**: hashing requires handing it the invoice bytes, so it would send supplier invoices to an
unrelated party, a worse version of what Q9 already scrutinises. Fallback if no Function can be had: see
`power-automate-reference.md`, "The shape of the solution".

⚠️ **D5 is conditional on two unverified checks**, and is the only decision here that can be invalidated
by something outside our control:

- **Tenant DLP policy must permit the HTTP (or Azure Functions) connector to an external host** —
  `power-automate-reference.md` U1. Commonly blocked. **Cheap to test: build a throwaway flow with an
  HTTP action and try to save it.**
- **An Azure Function must be deployable** — `power-automate-reference.md` U4. ⚠️ Not to be confused
  with `uipath-reference.md` U4, the superseded Outlook-Interop item cited elsewhere in this file. Cost is not the barrier (~43 *invoices*/month, each possibly several invocations, sits
  inside the free grant); subscription access and deploy rights are.

Fallback if either fails: **revert to D2**. `uipath-reference.md` is retained banner-marked for exactly
this reason, and `teda-validation-api-reference.md` — the bulk of the work — is platform-independent and
unaffected either way.

⚠️ **A revert also re-opens the delivery model, and that is not automatic.** The in-house model rests on
"the user builds PA Cloud flows themselves"; it does **not** follow that they would build a UiPath bot.
So a DLP or Azure failure re-opens the external-developer question — tracked as **Q18** rather than left
to be rediscovered.

**Also changed by D5:** the delivery model, from external developer to in-house. See the section at the
top of this file; the traps are the part that does *not* relax.

⚠️ **Governance note.** PA Cloud is a first-class platform in repo `CLAUDE.md`. This rulebook predated
`templates/power-automate-reference.md`; **the template now exists and the two were reconciled on
2026-08-20** — three project rules were promoted into the template, and the template's behaviours
V1–V5 (verified) plus V6–V7 (template-asserted, not trial-verified) were absorbed downward. The project rulebook adopts the template's R1–R13 by reference
and numbers its own rules from R14 so IDs never collide — though citations must still be file-qualified.

### D6 — A second, scheduled companion flow is permitted

⚠️ **Proposed 2026-08-20, not yet explicitly confirmed by the user** — unlike D1–D5, this entry
records the assistant's structural analysis, not a decision the user has signed off. It sits in this
section because later design content (the breaker's untrip path, the parked-queue drain) already
depends on it, but treat it as provisional until the user confirms it, and note it explicitly when this
phase is presented for sign-off. Template R1 and repo `CLAUDE.md` state **one cloud flow, no child flows** — a
rule about not splitting *one process* across artifacts via "Run a Child Flow". A **separately-triggered
monitoring/recovery flow is a second, independent process, so it sits outside R1's scope rather than
being an exception to it.** Recorded here so the distinction is deliberate rather than assumed. The
reason a second flow is unavoidable is structural: it must run precisely when **no email has arrived**,
which an event-triggered flow definitionally cannot do.

It does three things nothing else can:

1. **The `power-automate-reference.md` ⚠️ V7 heartbeat** — assert the main flow has run recently. A dead connection stops the trigger
   with no run and no error, so absence-of-runs is only detectable from outside.
2. **Untrip the circuit breaker**, by probing via the Azure Function (never ETDA directly — that would
   breach `power-automate-reference.md` R14 and need the `apikey`).
3. **Drain the parked queue.** A per-email trigger will not re-fire for a message it already consumed,
   so invoices parked during an outage are stranded unless something goes back for them.

⚠️ **Bounded deliberately — and the boundary needed a correction.** It carries **no *new* validation
logic**: the drain re-enters the *same* Azure Function contract and reuses the same outcome and output
handling as the main flow. That is a duplicated call path, and the duplication is accepted knowingly —
the alternative is stranded invoices. What it must **never** do is grow its own verdict rules, its own
code tables, or a second output format; if the two ever disagree about an outcome, that is a defect.

⚠️ A cleaner shape exists but is unverified (`power-automate-reference.md` **U10**): have the drain
**move the parked message back into the watched folder** so the main flow's own trigger re-fires, giving
the companion flow no validation path at all. Fallback if the trigger does not re-fire on a moved
message — likely, since it fires on arrival rather than folder membership — keep the re-entrant call
above. Fallback if a second flow is refused: the
parked queue is drained by hand and that goes in the runbook, because nothing else will do it.

## Skill in use

`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review
→ Implementation Guide). Never skip phases. No bot code/files until Phase 5 sign-off (design docs are
expected before then).

`CLAUDE.md` governs: **mandatory automatic `rpa-design-reviewer` loop** on every new/edited phase and
before every `docs/` commit — loop fix → re-review until PASS (zero BLOCKER/MAJOR). Run it via a
`general-purpose` agent mid-session, since custom agents only load at session start.

## Current phase

**Phase 1: Discovery — in progress.** The validation service has been identified and researched from
ETDA's official documentation; findings are in `teda-validation-api-reference.md`.

**Status as of 2026-08-20**, after the platform change and the post-review restructure:

- ✅ **Closed:** Q1, Q2, **Q3** (→ D4), **Q7** (→ D2, then **D5**), **Q11** (→ D3).
- 🟡 **Partly answered:** **Q4** (M365 mailbox via the Outlook connector; *which* mailbox and the
  recognition rule still open), **Q6** (~10/week; trigger now event-driven per D5), **Q8** (numbers
  proposed, awaiting approval), **Q13** (Function config per D5 — Key Vault or app settings, managed
  identity preferred; ownership and rotation open).
- ⬜ **Open:** Q5, Q9, Q10, Q12, Q14, Q15, Q16, Q17.
- 🟣 **Conditional:** **Q18** — live only if D5 reverts to UiPath (delivery model would re-open).

⚠️ **Two verification tasks now gate the platform itself**, not just a phase — see D5:
**the tenant DLP check** and **Azure Function availability**. Both are cheap; neither is done.

⚠️ **D6 also needs explicit user confirmation**, not just the assistant's structural recording — get it
before or at Phase 2 sign-off, since the breaker's untrip path and the parked-queue drain already assume it.

**Q5 (where the verdict goes) remains the single largest blocker to the PDD** — the only open question
that shapes a whole logical phase rather than a setting. Now that the build is in-house and PA Cloud, a
SharePoint list is the obvious default, but it is still the user's call.

## Phase status

- [~] Phase 1 — Discovery (Q1, Q2, Q3, Q7, Q11 closed; Q4, Q6, Q8, Q13 partial; Q5, Q9, Q10, Q12, Q14–Q17 open; Q18 conditional)
- [ ] Phase 2 — High-Level Design
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide (the build guide — now for the user, and for whoever maintains it later)

---

## ✅ Major finding — the validation service has a free API (2026-08-17)

**The design calls ETDA's API, not the website — confirmed as decision D1 above.** Full detail in
`teda-validation-api-reference.md`; the short version:

- ETDA offers TEDA Web Validation as **both a website and an API, free of charge**.
- The API is a **two-step async flow**: `POST /WVP/v2/verification/verify` (multipart: `file` +
  SHA-256 `digest`) responds with a `ResultCode` — **the only field to branch on** — and, on success, a
  `TransactionID`. `POST /WVP/v2/verification/result` is then polled with that ID until it stops
  returning `P2002` (in progress). *(⚠️ The spec's own examples disagree on whether `TransactionID` is
  populated on a failure code, so its presence must never be read as "submission succeeded" — branch on
  `ResultCode`.)*
- Auth is an **`apikey` header**, issued by ETDA on request — **not self-service**.
- Spec: **API Specification v2.2, 9 May 2022**, obtained from ETDA's site and read in full.

This removes the most fragile component from the original picture. A bot driving a third-party upload
form would break whenever ETDA restyled the page, and that breakage would sit outside the external
developer's warranty. Two documented endpoints, the second of them polled, do not have that problem.

### ⏳ Action on the critical path — request the API key now

The API key comes from submitting ETDA's **Web Validation service request form** (V3) to
`eservice@etda.or.th`. No integration code can be meaningfully tested without it.

Requested during design, in parallel, it costs nothing. Left until build time, it is dead time. **Owner: user. Not yet started as of 2026-08-20.**

**Ten** questions to ask ETDA in the same request (none answerable from published documents) are listed
at the end of `teda-validation-api-reference.md`. Two matter most: the **production host URL** is
outright blocking for deployment, and **question 9 — is automated/bulk submission permitted?** closes
the inference D1's **reason 4** rests on. **Question 10** (added 2026-08-20) settles whether an `E0001`
transaction is terminal — `power-automate-reference.md` R19's resubmit-not-repoll behaviour is inferred,
not confirmed. **Rate limits** (question 2) are still worth asking but, at
~10 invoices/week (Q6), are no longer blocking.

### ⚠️ Findings that change what the bot must do

Each is flagged here because it changes **requirements**, not just implementation. The pointer before
each finding names its home in `teda-validation-api-reference.md` — note they are not in trap order,
and two of them point at implications as well as, or instead of, traps.

1. *(trap 1)* **"Check the valid date" implemented literally gives wrong answers.** ETDA's `S0003` — *certificate
   expired* — is classified **Trusted**, because a signature made while the certificate was live stays
   valid after the certificate lapses. Only `E0003` (*used after expiry*) is Untrusted. Comparing
   `certExpireDate` to today would reject legitimate older invoices. **The verdict must come from
   `signatureCode`; the dates are for reporting only.** This one is silent — the bot would return
   confident, well-formatted, wrong answers.
2. *(trap 2)* **"Has a signature or not" is not fully answerable.** Code `N0002` means *no signature* **or**
   *signed in a format ETDA doesn't support* — one code, two business meanings. Needs a policy decision
   (auto-reject vs manual review) — ✅ **settled by D4: Manual review**, initially with a count, and
   downgradeable later with evidence.
3. *(trap 5 + implication 5)* **There are five outcomes, not two.** Trusted / Untrusted / Warning / **No supported signature** /
   **Could not check**. The fifth is the one that gets lost: `N9999` ("system error, could not check")
   shares `Status = null` with `N0002` ("no signature"), so collapsing them means **an ETDA outage gets
   reported to the business as "these invoices are unsigned"** — a confident, wrong, actionable-looking
   answer produced by an infrastructure failure. Transport and auth failures land in the same bucket.
   "We don't know" is a different instruction to a human than "this invoice is unsigned", and the bot's
   output must keep them visibly distinct. **Outcome and disposition are separate vocabularies** —
   ETDA determines the outcome, the business chooses the disposition (Accept / Reject / Manual review /
   Retry). "Manual review" is a disposition, never an outcome.
4. *(trap 3)* **Warning is a real third state, and `E0001` is transient.** `E0001` ("certificate status
   cannot be proven right now") is an ETDA-side condition that should be **retried**, not recorded as a
   verdict. When retries are exhausted the outcome is **Could not check** with a **Manual review**
   disposition — never Accept, never Reject. Filing it under Warning would let it inherit Warning's
   disposition, so had Q3(a) been answered "Warnings are acceptable" the bot would have silently
   auto-accepted invoices nobody ever managed to check.
5. *(implication 2)* **Re-saving the PDF manufactures a fraud signal.** The attachment must be hashed and uploaded
   byte-for-byte. Any re-save or normalisation produces either a digest mismatch or a genuine `E0002`,
   *"document was modified after signing"* — our own bot fabricating evidence of tampering against an
   innocent supplier. The same risk exists upstream in mail gateways and AV scanners that rewrite
   attachments.
6. *(trap 4)* **Code strings are reused across unrelated tables.** `E0002` means *"document modified after
   signing"* in the signature table and *"Not LTA"* in the LTA table. One shared code-mapping helper
   would turn an unremarkable fact into a tampering alert. Each field must be read against its own
   table.

---

## Open Discovery questions

Nothing is assumed — where an answer is missing at PDD time, it goes into the PDD as an explicit open
item rather than being silently filled in.

- [x] **Q1. Which validation site, and does it have an API?** — **CLOSED 2026-08-17.**
      https://validation.teda.th/th/validate, ETDA's TEDA Web Validation. **Yes, a free API exists.**
- [x] **Q2. What the site returns.** — **CLOSED 2026-08-17** for the API path: full result schema, every
      field name, and all status codes are in the reference doc. *(The portal's own screens are now
      needed only for human cross-checking during testing, not for building selectors.)*
- [x] **Q3. What "valid" means to the business.** ✅ **CLOSED 2026-08-18 — user accepted all proposed
      defaults.** The full mapping is recorded as decision **D4** above; it is the authority, and this
      entry is a pointer to it, not a second copy.
      *Original question text retained below for the record:*
      - **(a) Warning results** — what **disposition** do `E0004` (wrong certificate type) and `E0005`
        (document partly unsigned) get: Accept, Reject, or Manual review? *`E0005` is a real fraud
        vector.* Also: when `E0001` retries are exhausted, is Manual review the right terminal
        disposition? *(Its outcome is fixed at* Could not check *— only the disposition is open.)*
      - **(b) `N0002`** — its outcome is fixed at *No supported signature*; the open choice is the
        **disposition**: Reject (i.e. treat as unsigned) or Manual review. (See finding 2.)
      - **(c) Multiple signatures and timestamps** — if a PDF carries several signatures (up to 5 are
        reported), how do they combine into one answer? *(Our default: **most-severe-wins** —
        Could not check > Untrusted > Warning > No supported signature > Trusted. So one bad signature
        among four good ones does not pass. A documented alternative ranking — putting Untrusted above
        Could not check, so a definite bad finding auto-rejects — is set out with the aggregation rule
        in the reference doc.)* And: is a PDF carrying only a *timestamp* but no digital
        signature "signed"? *(Our default: no — a timestamp proves when a document existed, not who
        approved it.)* Both defaults are stated so silence isn't read as agreement to an unstated rule.
- [~] **Q4. The email side.** *Owner: user.* ✅ **Mailbox is M365**, reached by the **Office 365 Outlook
      connector** (D5) — not Outlook desktop, and not Interop. Still open, and each changes the design:
      - **Which mailbox** — personal, or a shared/functional one? Shared changes who owns the
        connection (`power-automate-reference.md` ⚠️ V6) and who is affected when it expires
        (`power-automate-reference.md` ⚠️ V7).
      - **How an invoice email is recognised** — sender list, subject pattern, a folder people drag mail
        into, or "everything in this inbox"? *(The sibling `concur-cash-advance-bot` settled on folder
        membership rather than read/unread state, which proved far more robust.)*
      - **Can one email carry several attachments**, or non-invoice ones mixed in? *(Ties to Q10, and to
        Q12 — the trigger fires per email, not per attachment.)*

      ⛔ **The former "Outlook desktop / Interop / interactive session" risk is void under D5** —
      superseded `uipath-reference.md` U4 applies **only if the project reverts to D2**. Removing it was
      D5's leading gain: the connector needs no robot machine and no Windows session.

- [ ] **Q5. Where the verdict goes.** *Owner: user.* Excel/log row, reply to sender, move mail to a
      Valid/Invalid folder, notify a person, feed another system? Who consumes the result and what do
      they do with it? *Must accommodate all five outcomes, including "could not check".*
- [~] **Q6. Volume and trigger.** *Owner: user.* **Volume answered 2026-08-18: ~10 per week.** ✅ **Trigger effectively
      answered by D5** — the Office 365 Outlook "when a new email arrives" trigger is event-driven, so
      there is no polling interval to choose. What remains is only whether any *scheduled sweep* is also
      wanted as a safety net against a missed trigger event (see `power-automate-reference.md` ⚠️ V7 and Q15 — a missed trigger event is the V7 case; `power-automate-reference.md` U7 is the *duplicate*-delivery consequence of adding a sweep).

      That volume is **low, and it should shape the design**: rate limits are a non-issue (ETDA question
      2 drops from blocking to routine), throughput and parallelism are non-issues, and a manual-review
      queue costs about one item a week — which is what makes D4's conservative defaults cheap. ⚠️ It
      also means **the bot will spend most of its runs finding nothing**, so the "no new invoices" path
      is the *common* path, not an edge case, and must be silent rather than noisy. Fallback: if the
      trigger ends up frequent (say hourly), consider whether a quiet run should log at all.
- [x] **Q7. Platform.** ✅ **CLOSED — reopened and re-closed.** First settled 2026-08-18 as UiPath (D2);
      **re-settled 2026-08-19 as Power Automate Cloud (D5)**, which supersedes it. Live rulebook is
      `power-automate-reference.md`.
- [~] **Q8. Timing values.** *Owner: user — **numbers now proposed, awaiting approval.*** At ~10
      invoices/week (Q6) every one of these is generous and costs nothing; they are sized so that a
      transient ETDA problem resolves itself without human involvement, and a real outage surfaces
      quickly rather than after a long grind.

      | Setting | Proposed | Why |
      |---|---|---|
      | Poll interval (`P2002`) | **5 s** | the FAQ implies checks resolve in seconds. **Function-side** |
      | Per-attempt poll bound | **90 s** | ⚠️ **Re-scoped by D5.** The former "overall poll timeout **300 s**" is void — it sat exactly on the Consumption-plan Function ceiling (`power-automate-reference.md` R19, U9). One Function invocation now polls for at most 90 s, then hands back a `TransactionID` for the flow to re-call with. **Function-side** |
      | Overall validation ceiling | **45 min** | ⚠️ **New under D5.** Total elapsed across *all* invocations, so an invoice cannot loop forever (implication 4, trap 3). Covers the 30-minute revocation window plus slack; on expiry → *Could not check* / Manual review. **Flow-side** |
      | `E0001` retry | **3 retries, 10 min apart** (4 calls total, 30 min total wait). ⚠️ **Schedule Function-side, waiting flow-side** — the Function never sleeps for backoff (`power-automate-reference.md` R19); a 30-minute in-Function wait is impossible on Consumption. | a revocation source being unreachable is a minutes-to-hours outage; a 30-minute window catches most without stalling the run |
      | `P1999`/`P2999`/HTTP 5xx/`429` retry | **3 retries after the initial call** (4 calls total), backoff 5 s → 30 s → 120 s. ⚠️ **Schedule Function-side, waiting flow-side** — the Function returns `retryAfterSeconds` and never sleeps for backoff (`power-automate-reference.md` R19). | standard transient-error handling, sized so a brief ETDA hiccup resolves without human involvement |
      | `pending` re-call wait | **30 s** | how long the flow waits before asking again about an unresolved transaction. **Function-returned** |
      | `MaxReCalls` | **20** | hard cap on re-calls per invoice, in case a fault returns `retryAfterSeconds: 0`. Exhausting it ends the invoice as *Could not check* / Manual review. **Flow-side** |
      | Consecutive-failure **breaker** | **5 invoices** | ⚠️ **Re-scoped by D5.** Counted per *invoice/attachment*, not per HTTP call or per email, and held in a durable store **across runs** — see `power-automate-reference.md` R18 and its per-attachment note under "The shape of the solution" (gated on Q4). The old "abort the run" framing is void: an event-driven trigger gives one email per run, which may still carry several invoices, so there is no batch-level abort that protects anything. 5 consecutive unresolvable invoices now trips a breaker that parks subsequent arrivals and alerts. |
      | Clustered-`400` threshold | ⚠️ **not yet proposed** | a `400` is an our-bot request defect, counted **separately** from ETDA-side failures (`power-automate-reference.md` R18). Until a number is chosen the flow **logs the clustering and does not trip**. |
      | `MaxParkAttempts` | **3** | cross-run bound on the park → drain → re-park cycle, so a parked invoice can't loop forever across breaker trips. Exhausting it ends the invoice as *Could not check* / Manual review, alertable under Q15, and it leaves the parked queue (`power-automate-reference.md` R18). **Flow-side** |

      ⚠️ All are **configuration**, so changing them post-deployment is an edit rather than a rebuild — but
      they do not all live in the same place: the poll interval, per-attempt bound and retry schedules are
      **Function app settings**, the ceiling and breaker threshold are **flow config**. See the
      Configuration ownership table in `power-automate-reference.md`.
      Fallback: if ETDA's answer to question 4 contradicts any of them, ETDA's guidance wins.
      <details><summary><em>Original question text, retained for the record — superseded by the table
      above</em></summary>

      Poll interval and
      overall timeout for `P2002`; retry count and window for `E0001`; retry count and backoff for the
      ETDA-side internal errors `P1999` and `P2999`; retry policy for HTTP 5xx and connection timeouts.
      All are config values, all are currently deferred to "config" without numbers, and none can be
      left to the developer to invent. ETDA has documented no guidance — it is question 4 in the ETDA
      list at the end of the reference doc.
      Also here: **is there a point at which repeated failures — of any kind — should abort the whole
      run?** `P1999`/`P2999` are per-invoice ETDA-side errors, and a single `400` is a per-invoice
      request defect on our side — but a hundred of either in a row means ETDA is down, or the contract
      has changed under us. Grinding through the remaining invoices to mark them all "Could not check" wastes time
      and obscures the real cause. A consecutive-failure threshold is the usual answer; the number is a
      choice nobody has made.

      </details>
- [ ] **Q9. Compliance sign-off — sending invoices to a third party, and accepting ETDA's
      accuracy/liability disclaimer.** *Owner: user.* The manual
      process sets a precedent for **occasional one-off uploads by a person**, not for **automated bulk
      submission** of every supplier invoice received. ETDA states uploaded files are not retained but
      **validation results are stored** — and those results include signer/organisation identity. Worth
      confirming with whoever owns data protection before the bot goes live, not after.
      **Also, and separately from data protection:** ETDA's terms **disclaim the accuracy of a
      validation result** (clause 2) and **liability for relying on one** (clause 7). The business needs
      to accept that the bot's verdict is *evidence, not a warranty* — which matters most for the
      **automatic** dispositions, where an invoice is accepted or rejected with no human ever looking at
      it. If that isn't acceptable, the answer is not to abandon the bot but to move Accept and/or
      Reject to Manual review under **D4**, which is a configuration choice rather than a redesign.
- [ ] **Q10. Malformed and unusable inputs.** *Owner: user.* What should the bot do with a
      password-protected or encrypted PDF, a file over the size limit (`P1003`), an attachment that
      isn't a PDF at all, or a corrupt file? Q4 asks whether non-invoice attachments can be mixed in;
      this asks what happens to them. *Partly dependent on ETDA question 7 (whether the service accepts
      password-protected PDFs at all, and which code it returns) — see the end of the reference doc.*
- [x] **Q11. Scope boundary — XML in or out?** ✅ **CLOSED 2026-08-18 — both PDF and XML are in scope.**
      Recorded as decision **D3**. This widened the project beyond the original "invoice pdf" wording and
      raised **Q16** and **Q17** below.
- [ ] **Q12. Duplicate invoices.** *Owner: user.* What happens when the same PDF arrives twice — a
      re-send, a reply-all thread, or a forwarded chain? Re-validate, or recognise and skip? Feeds Q5.
- [~] **Q13. API key handling.** *Owner: user.* **Largely answered by D5:** the key lives in the
      **Function's own configuration** — Key Vault referenced by the Function, or the Function's
      application settings, managed identity preferred over a stored secret (`power-automate-reference.md`
      R14) — ⚠️ *not* a PA environment variable, whose value is visible to anyone who can open the
      solution. What remains: who owns the
      vault, and rotation. The external-developer half of this question is void (D5).
      *Original question text:* Where does the `apikey` live, who holds it, and is it
      rotated? Repo `CLAUDE.md` forbids hardcoded credentials, so it belongs in a secret store rather than a config cell — under D5 that is the Function's own configuration, per `power-automate-reference.md` R14.
      Also: what should the flow do at runtime if the key is missing or revoked? *(Our position: it sets the
      contract's run-fatality flag, which under `power-automate-reference.md` R18 trips the breaker
      immediately rather than counting — every subsequent call would fail identically.)* ⚠️ Under D5 a **UAT key**
      is still wanted separately from production, so the flow can be built and tested without touching
      live traffic — see ETDA question 6.
- [ ] **Q14. Audit-trail retention.** *Owner: user.* The design requires `TransactionID` and
      `TransactionDate` to be persisted per invoice — they are the only handle for an ETDA support
      query and the only link between an invoice and the verdict recorded against it. Where is that
      stored, for how long, and does the PDF itself need retaining alongside it? Related to Q5 but not
      answered by it: Q5 is about *reporting the verdict*, this is about *proving it later*.
- [ ] **Q15. Who is alerted when the run itself fails.** *Owner: user.* Distinct from Q5. A run-fatal
      condition — the **per-invocation run-fatality flag** in implication 1 (`401`/`404`/`405`, or any
      undocumented 4xx **except `429`/throttle responses**) — kills the **whole run** rather than one
      invoice. ⚠️ *(Pre-D5 framing; re-scoped a few lines below — under D5 a run is one invoice, so
      "kills the run" and "trips the breaker" are the same event.)* Clustered `400`s and the Q8 consecutive-failure threshold are a **separate,
      cross-invocation** condition — a single call can't set the flag for them — and are owned instead by
      `power-automate-reference.md` R18's breaker, which trips immediately on the flag or on reaching its
      own threshold. Either path, unresolved invoices must then be reported as "Could not check" rather
      than dropped.
      Who gets told, and how quickly? An invoice that vanishes because the run died is worse than one
      reported as unchecked: nobody knows to look at it.

      ⚠️ **D5 re-scopes "the run".** With an event-driven trigger at concurrency 1, a run is **one
      invoice** — so "kills the whole run" no longer means a batch is lost. Per
      `power-automate-reference.md` R18, a run-fatal condition now means *this invoice fails **and** the
      cross-run circuit breaker trips*. Q15 must therefore answer **three** notifications, not one:

      1. **A tripped breaker** — the flow has stopped validating and is parking arrivals. Most urgent.
      2. **The parked queue** — how anyone learns invoices are waiting, and who confirms they drained
         after the breaker cleared.
      3. **An individual invoice** ending *Could not check* — including one that exhausted
         `MaxValidationWaitMinutes`, `MaxReCalls` (`power-automate-reference.md` R19) or `MaxParkAttempts`
         (`power-automate-reference.md` R18) rather than failing outright.

      ⚠️ **And a worse case than any failed run: no run at all.** Per `power-automate-reference.md`
      ⚠️ V7, a PA Cloud connection expires after ~90 days idle and **nothing alerts** — the Outlook
      trigger simply stops firing. Invoices arrive, nothing happens, no run appears in history, no error
      is raised. It is indistinguishable from a quiet week, and this bot has quiet weeks by design
      (~10/week, Q6). **Any answer to Q15 that only watches *failed* runs cannot see this.** Fallback: a
      scheduled heartbeat asserting the flow has run recently, or a periodic reconciliation of invoices
      received against invoices validated. *(`P1999`/`P2999` are **per-invoice** ETDA
      errors, not fatal-to-run — but see the abort threshold in Q8.)*
- [ ] **Q16. Does *structure* validation count, or only signatures?** *Owner: user.* **Raised by D3.**
      For XML, ETDA runs a second, independent check: whether the document conforms to a **registered
      e-Tax schema** (`schemaCode`) and its business rules (`schematronCode`). That asks a different
      question from "is it signed" — a file can be correctly signed but structurally invalid, or
      structurally perfect but unsigned. **Does the bot report the structure verdict, and can a
      structure failure alone make an invoice unacceptable?**
      ⚠️ It has a version dimension too: `structureActiveStatus` returns `"Active"` or **`"Obsolete"`**,
      so an invoice can be valid against a schema version ETDA has retired. Whether "obsolete but valid"
      is acceptable is a business call. Fallback pending an answer: **capture the structure codes but
      don't act on them** — carrying them costs nothing, and re-running every invoice later to obtain
      them would not be cheap. Also decides whether the Export Excel API is used at all.
- [ ] **Q17. PDF/A-3 with embedded XML — one document or two?** *Owner: user.* **Raised by D3.** Thai
      e-Tax invoices are commonly issued as a **PDF/A-3 containing the XML inside it**. ETDA can return
      PDF *and* XML result blocks for a single such file. ⚠️ Which governs when they disagree — say the
      PDF wrapper is signed but the embedded XML is not? Fallback pending an answer: treat the **PDF
      signature as the verdict** and report any XML finding alongside it, since that matches what a
      human reading the portal today would see. Needs a real sample to settle properly — see the drop
      zone.

- [ ] **Q18. Delivery model if D5 reverts.** *Owner: user.* **Conditional — only live if D5's DLP (`power-automate-reference.md` U1)
      or Azure Function (`power-automate-reference.md` U4) check fails.** In-house build was chosen because the user builds PA Cloud
      flows; it does not follow that they would build a **UiPath** bot. If the project reverts to D2,
      does it also revert to an external developer? Recorded now so a revert does not silently
      resurrect a settled-looking question. Fallback: assume external-developer, since that was the
      position when D2 was live.

### Resolved design question

- **"Does this need a website at all?"** — raised 2026-08-17, **resolved the same day** and now settled
  formally as **decision D1**. The concern was the fragility of driving a third-party page. The answer
  turned out better than the alternatives considered: ETDA publishes an API, so the bot neither
  automates the website nor tries to validate signatures offline. Offline validation is **rejected** —
  ETDA's service is the authority for the Thai e-Tax schemes, and reimplementing trust-chain checking
  locally would be both harder and less defensible to an auditor.

### `reference-files/` drop zone

`invoice-signature-verification-bot/reference-files/` — sample PDFs and supporting material (see its
README). Everything in it is **gitignored except the README**; real invoices carry supplier names, bank
details, and amounts and must not reach GitHub.

Still valuable now that the API is the target: **sample PDFs** are what the integration tests run
against. But note carefully **which outcome each sample actually proves** — the
obvious trio does *not* cover five outcomes, or even three:

**PDF samples:**

| Sample | Outcome it produces | Why it's needed |
|---|---|---|
| Signed, currently valid | **Trusted** (`S0001`) | happy path |
| No signature | **No supported signature** (`N0002`) | the commonest real case |
| Signed, certificate since expired | **Trusted** (`S0003`) — *the same outcome as the happy path* | the **regression test for trap 1**: if this comes back Untrusted, the build has implemented date arithmetic and will reject legitimate invoices |
| **Modified after signing** | **Untrusted** (`E0002`) | ⚠️ **not covered by the trio** — without it the entire Untrusted path ships untested |
| — | **Warning**, **Could not check** | cannot be produced by any file; need recorded/simulated responses |

**XML samples — added by D3 (2026-08-18):**

| Sample | What it settles |
|---|---|
| A **signed XML** e-Tax invoice | the XML happy path, and that `XmlSignatureResult` parses. Note the ceiling is **3,072 KB**, far below PDF's |
| A **PDF/A-3 with the XML embedded** | the only way to settle **Q17** — ETDA may return both a PDF and an XML verdict for one file, and nothing tells us which governs when they disagree. A real sample answers in minutes what speculation cannot answer at all |
| An **XML that fails structure validation** | feeds **Q16**; exercises `schemaCode`/`schematronCode`, which are currently captured-but-unused |

The expired-certificate sample is worth having precisely *because* it must **not** come out Untrusted —
it is the only way to catch trap 1 empirically rather than by code review.

⚠️ **Untrusted has no natural sample.** The practical route is to take the signed-and-valid sample and
alter it after signing (change a byte, append a page) — that is exactly what `E0002` detects, so it is a
reliable way to manufacture the case. Worth stating in the Phase 6 implementation guide; otherwise the most
consequential verdict the bot can issue is the one path nobody tested. *Warning* and *Could not check*
must be driven from simulated responses built off the code tables in the reference doc.

Portal screenshots dropped in priority — they are now only a human cross-check.
