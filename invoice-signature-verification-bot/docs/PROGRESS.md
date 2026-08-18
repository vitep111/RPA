# Project Progress — Invoice Signature Verification Bot

> Resume file. A new session should read this first to know exactly where we are.

## What this project is

Invoices arrive by email as attachments — **PDF and/or XML** (decision **D3**), including the
**PDF/A-3-with-embedded-XML** form Thai e-Tax invoices commonly take (**Q17**). Someone has to establish
whether each one carries a **digital signature** and whether that signature is **valid** — today done by
hand, by uploading the file to **https://validation.teda.th/th/validate** (ETDA's TEDA Web Validation
service) and reading the result off the screen. This bot automates that check.

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

✅ **Settled 2026-08-18 — UiPath.** See decision **D2** below. The project rulebook
`uipath-reference.md` is seeded and is now the authority on how this bot is built;
`teda-validation-api-reference.md` remains platform-independent and authoritative on what ETDA does.

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
   automation does exist, so this is a statement about the usual RPA tooling — now UiPath, per D2 —
   rather than an absolute. It does not change the conclusion: headless browser driving would still
   carry every other drawback below.)*
   ⚠️ **This reason is partly undercut by `uipath-reference.md` U4:** if Outlook desktop retrieval needs
   an interactive Windows session anyway (Q4), the deployment is interactive regardless and reason 1
   buys less than it appears to. D1 stands on reasons 2–5, which are unaffected.
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

### D2 — Platform is UiPath

**Confirmed by user, 2026-08-18.** Closes Q7. No waiver of the repo-wide `rpa-bot-dev` constraints is
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

**Status as of 2026-08-18**, after the user's answers:

- ✅ **Closed:** Q1, Q2, **Q3** (defaults accepted), **Q7** (UiPath — D2), **Q11** (PDF *and* XML — D3).
- 🟡 **Partly answered:** **Q4** (Outlook desktop; mailbox, recognition rule and multi-attachment still
  open), **Q6** (~10/week; trigger still open), **Q8** (numbers proposed, awaiting approval).
- ⬜ **Open:** Q5, Q9, Q10, Q12, Q13, Q14, Q15, and the two new ones D3 created — **Q16** (structure
  validation) and **Q17** (PDF/A-3 with embedded XML).

**Q5 (where the verdict goes) is now the single largest blocker to the PDD** — it is the only unanswered
question that shapes a whole logical phase rather than a setting.

## Phase status

- [~] Phase 1 — Discovery (Q1, Q2, Q3, Q7, Q11 closed; Q4/Q6/Q8 partial; Q5, Q9, Q10, Q12–Q17 open)
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
dead time. **Owner: user. Not yet started as of 2026-08-18.**

**Nine** questions to ask ETDA in the same request (none answerable from published documents) are listed
at the end of `teda-validation-api-reference.md`. Two matter most: the **production host URL** is
outright blocking for deployment, and **question 9 — is automated/bulk submission permitted?** closes
the inference D1's **reason 4** rests on. **Rate limits** (question 2) are still worth asking but, at
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
- [~] **Q4. The email side.** *Owner: user.* **Partly answered 2026-08-18: Outlook desktop.** Still open,
      and each of these changes the design:
      - **Which mailbox** — a personal one, or a shared/functional mailbox?
      - **How an invoice email is recognised** — sender list, subject pattern, a folder people drag mail
        into, or "everything in this inbox"? *(The sibling `concur-cash-advance-bot` settled on
        **folder membership** rather than read/unread state, which proved much more robust; worth
        considering the same here.)*
      - **Can one email carry several attachments**, or non-invoice ones mixed in? *(Ties to Q10.)*

      ⚠️ **Carried-forward risk — this project's `uipath-reference.md` U4** (carried from
      `concur-cash-advance-bot` U1, where it is the same load-bearing risk). Classic Outlook
      activities drive Outlook via Interop/MAPI and need Outlook installed with a **loaded mail profile
      in an interactive Windows session**. An unattended robot in a session-0 context is the classic
      failure. This matters more here than it first appears: **D1's leading argument was that the API
      lets the bot run unattended** — but if the *mail* side needs an interactive session anyway, that
      benefit is reduced (not eliminated: the validation step still gains stability, testability and
      speed). Fallback: Microsoft 365 / Graph activities against a service mailbox, which changes the
      auth story and needs an app registration. **Decide this before Phase 2 fixes the deployment
      model.**
- [ ] **Q5. Where the verdict goes.** *Owner: user.* Excel/log row, reply to sender, move mail to a
      Valid/Invalid folder, notify a person, feed another system? Who consumes the result and what do
      they do with it? *Must accommodate all five outcomes, including "could not check".*
- [~] **Q6. Volume and trigger.** *Owner: user.* **Volume answered 2026-08-18: ~10 per week.** Trigger
      still open — scheduled (at what interval?) or started by hand?

      That volume is **low, and it should shape the design**: rate limits are a non-issue (ETDA question
      2 drops from blocking to routine), throughput and parallelism are non-issues, and a manual-review
      queue costs about one item a week — which is what makes D4's conservative defaults cheap. ⚠️ It
      also means **the bot will spend most of its runs finding nothing**, so the "no new invoices" path
      is the *common* path, not an edge case, and must be silent rather than noisy. Fallback: if the
      trigger ends up frequent (say hourly), consider whether a quiet run should log at all.
- [x] **Q7. Platform.** ✅ **CLOSED 2026-08-18 — UiPath.** Recorded as decision **D2**. Repo-wide
      constraints apply unwaived; `uipath-reference.md` is seeded.
- [~] **Q8. Timing values.** *Owner: user — **numbers now proposed, awaiting approval.*** At ~10
      invoices/week (Q6) every one of these is generous and costs nothing; they are sized so that a
      transient ETDA problem resolves itself without human involvement, and a real outage surfaces
      quickly rather than after a long grind.

      | Setting | Proposed | Why |
      |---|---|---|
      | Poll interval (`P2002`) | **5 s** | the FAQ implies checks resolve in seconds |
      | Overall poll timeout | **300 s** (60 polls) | past this, something is wrong — hand to a human rather than wait |
      | `E0001` retry | **3 retries at +10 / +20 / +30 min** (4 calls total) | a revocation source being unreachable is a minutes-to-hours outage; a 30-minute window catches most without stalling the run |
      | `P1999`/`P2999`/HTTP 5xx/`429` retry | **3 retries after the initial call** (4 calls total), backoff 5 s → 30 s → 120 s | standard transient-error handling |
      | Consecutive-failure abort | **5 invoices** | counted per *invoice*, not per HTTP call (`uipath-reference.md` R11). At this volume a batch is 2–3 items, so it effectively only fires when someone submits a backlog and ETDA is genuinely down |
      | Clustered-`400` abort threshold | ⚠️ **not yet proposed** | a `400` is our-bot request defect, counted separately from ETDA-side failures (R11). Until a number is chosen the bot **logs the clustering and does not abort** on it |

      ⚠️ All five are **config keys**, so changing them post-deployment is an edit, not a rebuild.
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
      condition — `401`/`404`/`405`, any undocumented 4xx **except `429`/throttle responses**, clustered
      `400`s, or the Q8 threshold; the
      full list is the run-fatality flag in implication 1 — kills the **whole run** rather than one
      invoice, and unresolved invoices must then be reported as "Could not check" rather than dropped.
      Who gets told, and how quickly? An invoice that vanishes because the run died is worse than one
      reported as unchecked: nobody knows to look at it. *(`P1999`/`P2999` are **per-invoice** ETDA
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
reliable way to manufacture the case. Worth stating in the build brief; otherwise the most
consequential verdict the bot can issue is the one path nobody tested. *Warning* and *Could not check*
must be driven from simulated responses built off the code tables in the reference doc.

Portal screenshots dropped in priority — they are now only a human cross-check.
