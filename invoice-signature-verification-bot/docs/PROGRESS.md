# Project Progress — Invoice Signature Verification Bot

> Resume file. A new session should read this first to know exactly where we are.

## What this project is

Invoices arrive as PDF attachments by email. Someone has to establish whether each PDF carries a
**digital signature** and whether that signature is **valid** — today done by hand, by uploading the
PDF to **https://validation.teda.th/th/validate** (ETDA's TEDA Web Validation service) and reading the
result off the screen. This bot automates that check.

## Delivery model — read this before designing anything

**This bot will be built by an external developer, not in-house** (user instruction, 2026-08-17).

That changes what "done" means here. The deliverable is the **design package**, not a running bot: the
external developer receives the PDD, the design docs, and the Phase 6 Implementation Guide, and builds
from them alone. Consequences that bind every phase:

- **No tacit knowledge is transferable.** Anything left implicit becomes a change request, a wrong
  assumption, or an argument about scope after the contract is signed. Where an in-house design could
  say "the usual mailbox", this one names it.
- **Open items are contractual, not just design debt.** An unanswered question here is a gap the
  developer will either guess at or bill for. Each one below carries an owner.
- **Acceptance criteria matter more than usual.** Phase 5/6 must give the user something they can test
  the delivered bot against without reading the developer's code.

## Platform decision

**Not yet decided — Q7 below.** The repo's other two projects are UiPath and the `rpa-bot-dev` skill's
hard constraints assume it.

⚠️ **Note the conflict before answering Q7:** repo `CLAUDE.md` states the skill's UiPath hard
constraints (single `Main.xaml`, linear Sequences only, Config.xlsx, Dictionary over DataTable,
Verb+Object naming) are **repo-wide and non-negotiable**. Letting an external developer propose their
own platform therefore requires the user to **explicitly waive those constraints for this project** —
it is not a neutral default. Tracking it as an open question is right; it just isn't free.

Until it's settled, no project `uipath-reference.md` is seeded — the rulebook can't be written before
the platform is known. `teda-validation-api-reference.md` is deliberately platform-independent and
stands regardless of the choice.

## Confirmed decisions

Decisions the user has explicitly confirmed. These are settled and bind later phases — a later phase
that contradicts one of these is a defect, not a revision.

### D1 — Validate via ETDA's API, not by automating the website

**Confirmed by user, 2026-08-17.** The bot calls the TEDA Web Validation **API**. It does **not** drive
the upload form at https://validation.teda.th, which is what the current manual process does.

Reasons, in the order that decided it:

1. **The bot can run unattended.** ⚠️ RPA-style UI automation typically needs a logged-in Windows
   session with a visible browser — a machine that can't be locked, that breaks if someone connects
   over RDP, and that constrains scheduling. An HTTP call runs headless on a server. *(Headless browser
   automation does exist, so this is a statement about the usual RPA tooling rather than an absolute —
   and the platform is still undecided under Q7. It does not change the conclusion: headless browser
   driving would still carry every other drawback below.)*
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
5. **Maintenance asymmetry matters more on a fixed-price external build.** A documented HTTP contract
   changes rarely and visibly; third-party selectors break silently, after the warranty ends.

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

## Skill in use

`rpa-bot-dev` — phased RPA design assistant (Discovery → High-Level → Medium-Level → Detailed → Review
→ Implementation Guide). Never skip phases. No bot code/files until Phase 5 sign-off (design docs are
expected before then).

`CLAUDE.md` governs: **mandatory automatic `rpa-design-reviewer` loop** on every new/edited phase and
before every `docs/` commit — loop fix → re-review until PASS (zero BLOCKER/MAJOR). Run it via a
`general-purpose` agent mid-session, since custom agents only load at session start.

## Current phase

**Phase 1: Discovery — in progress.** The validation service has been identified and researched from
ETDA's official documentation; findings are in `teda-validation-api-reference.md`. **Q1 and Q2 are
closed; Q3–Q15 remain open** and block the PDD.

## Phase status

- [~] Phase 1 — Discovery (service researched; Q1/Q2 closed, Q3–Q15 open)
- [ ] Phase 2 — High-Level Design
- [ ] Phase 3 — Medium-Level Design
- [ ] Phase 4 — Detailed Design
- [ ] Phase 5 — Full Design Review & sign-off
- [ ] Phase 6 — Implementation Guide (the external developer's build brief)

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
`eservice@etda.or.th`. The external developer cannot meaningfully test integration code without it, and
obtaining it is ours, not theirs.

Requested during design, in parallel, it costs nothing. Left until developer kickoff, it becomes paid
dead time. **Owner: user. Not yet started as of 2026-08-17.**

**Nine** questions to ask ETDA in the same request (none answerable from published documents) are listed
at the end of `teda-validation-api-reference.md`. Three matter most: the **production host URL** and
**rate limits** are outright blocking for deployment, and **question 9 — is automated/bulk submission
permitted?** — closes the inference D1's **reason 4** rests on.

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
   (auto-reject vs manual review). Recommended fallback: manual review initially, with a count, then
   downgrade with evidence.
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
   disposition, so answering Q3(a) "Warnings are acceptable" would silently auto-accept invoices nobody
   ever managed to check.
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
- [~] **Q3. What "valid" means to the business.** *Owner: user.* **Technically answered, commercially
      open.** ETDA supplies the trust classification, so validity needn't be defined from scratch. Three
      decisions remain, and they are the user's, not the developer's:
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
- [ ] **Q4. The email side.** *Owner: user.* Which mailbox, and Outlook desktop / Exchange–M365 / other?
      How is an invoice email recognised — sender list, subject pattern, a folder people drag mail into,
      a shared inbox? Can one email carry several PDFs, or non-invoice attachments mixed in?
- [ ] **Q5. Where the verdict goes.** *Owner: user.* Excel/log row, reply to sender, move mail to a
      Valid/Invalid folder, notify a person, feed another system? Who consumes the result and what do
      they do with it? *Must accommodate all five outcomes, including "could not check".*
- [ ] **Q6. Volume and trigger.** *Owner: user.* Invoices per day/week; scheduled (what interval?) or
      manually started. *Also feeds the rate-limit question to ETDA.*
- [ ] **Q7. Platform.** *Owner: user.* Locked to UiPath, or open for the external developer to propose?
      ⚠️ Answering "open" means waiving repo-wide `CLAUDE.md` constraints — see Platform decision above.
      *Whichever platform is chosen must be able to compute a SHA-256 file hash and preserve the
      attachment byte-for-byte.*
- [ ] **Q8. Timing values nobody has chosen.** *Owner: user, with our recommendation.* Poll interval and
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
      Reject to Manual review under Q3, which is a configuration choice rather than a redesign.
- [ ] **Q10. Malformed and unusable inputs.** *Owner: user.* What should the bot do with a
      password-protected or encrypted PDF, a file over the size limit (`P1003`), an attachment that
      isn't a PDF at all, or a corrupt file? Q4 asks whether non-invoice attachments can be mixed in;
      this asks what happens to them. *Partly dependent on ETDA question 7 (whether the service accepts
      password-protected PDFs at all, and which code it returns) — see the end of the reference doc.*
- [ ] **Q11. Scope boundary — XML in or out?** *Owner: user.* Thai e-Tax invoices also circulate as
      **XML** and as **PDF/A-3 with embedded XML**. ETDA validates all of these. The requirement as
      stated says "invoice pdf", so our working assumption is **PDF only, XML out of scope** — but for
      an external-developer contract this must be an explicit in/out-of-scope line, not an assumption.
- [ ] **Q12. Duplicate invoices.** *Owner: user.* What happens when the same PDF arrives twice — a
      re-send, a reply-all thread, or a forwarded chain? Re-validate, or recognise and skip? Feeds Q5.
- [ ] **Q13. API key handling.** *Owner: user.* Where does the `apikey` live, who holds it, and is it
      rotated? Repo `CLAUDE.md` forbids hardcoded credentials, so it belongs in the config mechanism —
      but for an **external developer** this is also a contract question: they will need a working key
      (or a UAT key) to build against, and someone must decide whether they hold the production one at
      all. Also: what should the bot do at runtime if the key is missing or revoked? *(Our position:
      fatal to the run, alert immediately — every subsequent call fails identically.)*
- [ ] **Q14. Audit-trail retention.** *Owner: user.* The design requires `TransactionID` and
      `TransactionDate` to be persisted per invoice — they are the only handle for an ETDA support
      query and the only link between an invoice and the verdict recorded against it. Where is that
      stored, for how long, and does the PDF itself need retaining alongside it? Related to Q5 but not
      answered by it: Q5 is about *reporting the verdict*, this is about *proving it later*.
- [ ] **Q15. Who is alerted when the run itself fails.** *Owner: user.* Distinct from Q5. A run-fatal
      condition — `401`/`404`/`405`, any undocumented 4xx, clustered `400`s, or the Q8 threshold; the
      full list is the run-fatality flag in implication 1 — kills the **whole run** rather than one
      invoice, and unresolved invoices must then be reported as "Could not check" rather than dropped.
      Who gets told, and how quickly? An invoice that vanishes because the run died is worse than one
      reported as unchecked: nobody knows to look at it. *(`P1999`/`P2999` are **per-invoice** ETDA
      errors, not fatal-to-run — but see the abort threshold in Q8.)*

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

Still valuable now that the API is the target: **sample PDFs** are what the external developer's
integration tests run against. But note carefully **which outcome each sample actually proves** — the
obvious trio does *not* cover five outcomes, or even three:

| Sample | Outcome it produces | Why it's needed |
|---|---|---|
| Signed, currently valid | **Trusted** (`S0001`) | happy path |
| No signature | **No supported signature** (`N0002`) | the commonest real case |
| Signed, certificate since expired | **Trusted** (`S0003`) — *the same outcome as the happy path* | the **regression test for trap 1**: if this comes back Untrusted, the build has implemented date arithmetic and will reject legitimate invoices |
| **Modified after signing** | **Untrusted** (`E0002`) | ⚠️ **not covered by the trio** — without it the entire Untrusted path ships untested |
| — | **Warning**, **Could not check** | cannot be produced by any file; need recorded/simulated responses |

The expired-certificate sample is worth having precisely *because* it must **not** come out Untrusted —
it is the only way to catch trap 1 empirically rather than by code review.

⚠️ **Untrusted has no natural sample.** The practical route is to take the signed-and-valid sample and
alter it after signing (change a byte, append a page) — that is exactly what `E0002` detects, so it is a
reliable way to manufacture the case. Worth stating in the build brief; otherwise the most
consequential verdict the bot can issue is the one path nobody tested. *Warning* and *Could not check*
must be driven from simulated responses built off the code tables in the reference doc.

Portal screenshots dropped in priority — they are now only a human cross-check.
