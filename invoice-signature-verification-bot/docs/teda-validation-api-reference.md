# TEDA Web Validation — external service reference

Facts about the **external service this bot depends on**, gathered 2026-08-17. This is a
platform-independent document: it describes ETDA's service, not our bot. It stays true regardless of
whether the bot is eventually built in UiPath or anything else, and it is the document the external
developer integrates against.

> This is **not** the project rulebook. The platform rulebook (`uipath-reference.md` or equivalent)
> gets written once the platform is decided — see `PROGRESS.md`.

## Confidence legend

Nothing here has been live-tested by us. Three states:

| Mark | Meaning |
|---|---|
| 📄 | **Documented** in an official ETDA document — the API spec, the portal FAQ, or the terms of service. Quoted or translated, not inferred — but not yet proven against the live service. |
| ⚠️ | **Inferred** by us from the documents. Plausible, unconfirmed, needs a live test. Each carries a fallback. |
| ❓ | **Unknown** — the documents don't say. Must be asked or tested. |

A 📄 item is still capable of being wrong: the spec is **version 2.2, dated 9 May 2022**, and the
service has visibly moved on since (see "Spec is stale in at least one respect"). Treat 📄 as "the best
available written authority", not as "verified".

## Sources

| What | Where |
|---|---|
| Validation portal (the site the manual process uses) | https://validation.teda.th/th/validate |
| Portal FAQ — size limits, result colours | https://validation.teda.th/th/faq |
| Portal terms of service — automation, accuracy disclaimer *(read 2026-08-17; clause numbers cited in this doc come from that reading)* | https://validation.teda.th/th/terms-and-condition |
| Service overview — confirms API exists, free of charge | https://www.etda.or.th/th/Our-Service/Digital-Trusted-services-Infrastructure/TEDA/Web-Validation.aspx |
| Document index — API spec + access request form | https://www.etda.or.th/th/Our-Service/Digital-Trusted-services-Infrastructure/TEDA/Web-Validation/Example/API-Specification.aspx |
| **API Specification v2.2 (9 May 2022)** — primary technical source | https://www.etda.or.th/getattachment/f6cc5a84-5aa2-4b68-a7ef-412e18ca7309/API-Specification-Document.aspx |
| Web Validation service request form V3 | linked from the document index, which lists it as published **6 Aug 2026**. Its filename (`20260713-WebVLD-Request-form-V3.pdf`) corroborates the **version**, not the publication date — the two dates differ, so re-confirm currency before relying on it |
| Contact for API access | `eservice@etda.or.th` · 02-123-1234 |

---

## The headline: there is an API, and it is free

📄 ETDA states access is available "ทั้งรูปแบบ website และ API" (both website and API) and
"ไม่คิดค่าใช้จ่ายในการให้บริการ" (no service charge).

**This removes the most fragile component from the design.** The manual process uploads a PDF to a web
form; a bot doing the same would have to drive a third-party page it doesn't control, with selectors
that break whenever ETDA restyles the site — and that breakage would land outside the external
developer's warranty. The API replaces that with a documented HTTP contract.

**Design decision — confirmed by the user 2026-08-17 as D1 in `PROGRESS.md`: the bot calls the API and
does not automate the website.** The website remains useful as the human fallback and as the thing to
compare results against during testing.

📄 ETDA's terms of service (read 2026-08-17) say, at **clause 3**, that users must not interfere with,
obstruct, or damage the service, nor reverse-engineer it. There is **no clause addressing automation,
bots, or bulk use** either way.

⚠️ From that absence we read "automated access is not prohibited" — but that is a legal inference from
silence, not something ETDA has stated. It is also the weakest link in D1's reason 4. Fallback, and it
costs nothing: **ask ETDA to confirm that automated/bulk submission via the API is permitted** when
requesting the key — added as question 9 in the ETDA list below.

📄 **Clause 2 — ETDA does not guarantee the accuracy of a validation result. Clause 7 — broad
disclaimer of liability for damages arising from reliance on one.** Tracked under `PROGRESS.md` Q9: the
bot's output is **evidence, not a warranty**, which bears directly on the automatic Accept and Reject
dispositions, where no human ever sees the invoice.

⚠️ Clause **numbers** are cited above from a single reading; ToS pages get renumbered silently.
Fallback: re-check the numbering before quoting a clause in anything contractual.

### Access has a lead time — start it now

📄 The API key is not self-service. It is obtained by submitting the **Web Validation service request
form** to ETDA.

⚠️ Consequence: the external developer cannot write or meaningfully test integration code without it.
Fallback if the key is slow to arrive: the developer can build and unit-test the request construction,
SHA-256 hashing, polling loop, and result-parsing logic against **recorded sample responses** taken
from this document, then do a single integration pass when the key lands. That limits, but does not
eliminate, the delay.

**This is on the critical path and it is ours to obtain, not the developer's.** Requested during
design, in parallel, it costs nothing. Left until kickoff, it becomes paid dead time.

---

## API shape: two calls, asynchronous

📄 Validation is **not** a single request/response. It is submit-then-poll:

```
1. POST /WVP/v2/verification/verify   → returns TransactionID immediately
2. POST /WVP/v2/verification/result   → poll with TransactionID until it stops
                                         returning "in progress"
```

📄 Base URL in the spec is the **UAT** host: `https://api-uat.teda.th`. 📄 The spec writes the endpoint
as `https://{{URL}}/WVP/...`. ⚠️ We read the `{{URL}}` placeholder as meaning the host is intended to be
configurable per environment. Fallback: put it in config regardless — a hardcoded host is wrong even if
the placeholder means something else.

❓ **The production host is not stated anywhere in the documents.** Must be obtained with the API key.

### 1. Verify API — submit the file

📄 `POST https://{{URL}}/WVP/v2/verification/verify`

**Headers**

| Header | Value |
|---|---|
| `Content-Type` | `multipart/form-data` |
| `apikey` | the key issued by ETDA |

**Body** (form-data)

| Field | Type | Notes |
|---|---|---|
| `file` | File | the PDF |
| `digest` | Text | **SHA-256 of the file, lowercase hexadecimal** |

The `digest` is mandatory and checked: a mismatch is rejected with `P1002`. So the bot must hash the
file itself before sending — see "byte integrity" in the implications, which is where this gets
dangerous.

**Response**

| Field | Meaning |
|---|---|
| `InputName` | filename submitted; `null` means the transaction failed |
| `ResultCode` | `P1xxx`, below |
| `ResultMessage` | 📄 documented as always `null` in every listed case |
| `TransactionID` | Unix time + 8 random chars, **18 chars**; `null` on failure |
| `TransactionDate` | `yyyy-MM-dd hh:mm:ss.S` |

**Verify result codes** — 📄 the codes and meanings; ⚠️ the **Bot action** column is our
recommendation, not ETDA's. Fallback: if live behaviour contradicts a row, the code/meaning stands and
only the action changes.

| Code | Meaning | Bot action |
|---|---|---|
| `P1000` | Success | proceed to poll the Result API |
| `P1001` | Invalid File Type | **business exception** — not a PDF the service accepts. Report, don't retry |
| `P1002` | Invalid Digest Value | **defect in our bot**, not a property of the invoice. Log loudly, fail the item, don't retry — a retry reproduces it |
| `P1003` | File Size Limit Exceeded | **business exception** — route to manual handling. Don't retry |
| `P1004` | No Input File | **defect in our bot** — request built wrongly. Don't retry |
| `P1005` | No Digest Value | **defect in our bot** — request built wrongly. Don't retry |
| `P1999` | Internal Error | ETDA-side. **Bounded retry**, then manual review |

⚠️ **`TransactionID` can be non-null on a failure code.** The spec's own examples are inconsistent: the
`P1002` example on p.7 shows a populated `TransactionID`, the `P1002` example on p.11 shows `null`.
Fallback: **branch on `ResultCode`, never on whether `TransactionID` is populated.** A bot that treats
"got an ID" as "submission succeeded" would poll for a result that will never exist.

### 2. Result API — poll for the verdict

📄 `POST https://{{URL}}/WVP/v2/verification/result`, `Content-Type: application/json`, `apikey`
header, body `{"transid": "..."}`.

**Result codes** — 📄 codes and meanings; ⚠️ **Bot action** is our recommendation, same caveat as above.

| Code | Meaning | Bot action |
|---|---|---|
| `P2000` | Success | read the result |
| `P2001` | Transaction ID Not Found | ⚠️ a bot/state defect (an ID we never held, or lost). Outcome *Could not check*, disposition *Manual review*. Do not retry — the ID will not appear later |
| `P2002` | **Transaction in progress** | wait and poll again, up to the configured cap |
| `P2003` | Unable to Process the File | outcome *Could not check*, disposition *Manual review*. **Not** one of the `P1001`/`P1003` business exceptions — ETDA never established anything about the file |
| `P2004` | Verification timed out | ETDA gave up — manual review |
| `P2999` | Internal Error | bounded retry, then manual review |
| `P1001`–`P1999` | 📄 the Verify codes can also come back here, when polling an ID whose submission errored | treat exactly as in the Verify table above — do not keep polling |

❓ **No polling interval, maximum wait, or `P2004` threshold is documented.** The bot needs its own poll
interval and its own overall timeout, both in config, and must never poll indefinitely on `P2002`.
Values to be chosen — see `PROGRESS.md` Q8.

❓ **No rate limit is documented.** Absence of a documented limit is not absence of a limit.

### HTTP and authentication failures

📄 Both endpoints document the same HTTP status codes:

| Status | Documented meaning | Bot action |
|---|---|---|
| `200` | parameters correct | parse the body — **note a `200` can still carry a failure `ResultCode`** |
| `400` | Bad Request — wrong/missing parameter or malformed body | ⚠️ defect in our bot. Fail the item, don't retry |
| `401` | Unauthorized — not registered, or wrong credentials | ⚠️ **fatal to the whole run**, not to one invoice. Stop and alert — every subsequent call will fail identically |
| `404` | Not Found — wrong URL | ⚠️ configuration error. Fatal to the run |
| `405` | Method Not Allowed — wrong HTTP method | ⚠️ defect in our bot. Fatal to the run |
| `500` | Internal Server Error | ⚠️ ETDA-side. Bounded retry with backoff, then manual review |

📄 Auth failures return a body with a `message` field rather than a `ResultCode`:

- `{"message": "Invalid authentication credentials"}` — key wrong, expired, or revoked
- `{"message": "No API key found in request"}` — header missing

⚠️ The **Bot action** column above is our recommendation, and the fatal-vs-retryable split is the
inferred part. Fallback: if a `401` turns out to be per-call rather than persistent (e.g. a transient
gateway fault at ETDA), downgrade it to a bounded retry; if a `500` proves persistent rather than
transient, promote it to fatal-to-run. Both are one-line config changes if the retry policy is
parameterised, which is why Q8 in `PROGRESS.md` covers them.

⚠️ **Fatal-to-run and per-invoice reporting must not be confused.** A `401`/`404`/`405` aborts the run,
but the invoices already picked up and not yet resolved still need to be **reported as "Could not
check"** rather than silently dropped. An invoice that vanishes because the run died is worse than one
reported as unchecked: nobody knows to look at it. Fallback: emit the unresolved set on the way out.

⚠️ **The response shape differs between success and auth failure** — `ResultCode` is absent in the auth
cases. A parser that assumes `ResultCode` always exists will throw rather than report a clear
"authentication failed". Fallback: check for the `message` field before assuming the documented schema.

⚠️ Note the deliberate asymmetry between `400` (fail the **item**) and undocumented 4xx (fatal to the
**run**): a `400` can be provoked by one malformed request — an odd filename, an unusual byte in a
field — so the next invoice may well succeed, whereas an unrecognised 4xx more likely means the
contract itself has changed. Fallback: if `400`s cluster across many invoices rather than appearing
singly, treat that as the contract having changed and abort, per the Q8 threshold.

❓ **Nothing is documented about throttling responses (e.g. `429`), connection timeouts, or TLS
requirements.** Fallback: treat any undocumented 4xx as fatal-to-run (it will not fix itself), any
undocumented 5xx or network timeout as a bounded retry with backoff, and surface both distinctly from
business outcomes so an infrastructure problem is never reported as an invoice verdict.

### 3. Export Excel API — not useful here

📄 `POST /WVP/v2/verification/export-xls` returns **XML schema/schematron** structure errors.

**Irrelevant to this project.** It reports on XML structure validation; our inputs are PDFs and our
question is about signatures. Recorded only so nobody spends time on it.

### Endpoints that are NOT for us

📄 The spec documents these under "ลำดับการทำงานและรายละเอียด API ย่อยภายใน" — *internal* sub-APIs
describing ETDA's own service-to-service calls:

- `/WVP/v2/verification/verify-extract`
- `/WVP/v1/verification/verify-control`
- `/WVP/v2/verification/verify-pdfsig`
- `/WVP/v1/verification/result-query`

They appear in the same document, in the same format, and **some of them take no `apikey`** — which
makes them look easier to use. They are not part of the public contract and must not be called. State
this explicitly in the developer brief: `verify-extract` in particular looks like a drop-in alternative
to `verify` and is not one.

---

## The result body, for a PDF

📄 Top level: `TransactionID`, `FileType` (`"pdf"` / `"xml"` / `null`), `FileName`, `FileSize` (KB),
`TransactionStartTime`, `TransactionFinishTime`, `TransactionProcessTime` (seconds), `ResultCode`,
`ResultMessage`.

For PDFs, the parts that matter:

| Field | Cardinality | What it holds |
|---|---|---|
| `pdfDigitalSignatureResult` | **0–5** | one entry per digital signature — **the 5 most recent** |
| `pdfTimeStampingResult` | **0–5** | one entry per timestamp token — the 5 most recent |
| `pdfaResult` | 0–1 | PDF/A-3 compliance (`pdfaCode`, `pdfaMessage`, `pdfaCompliance`) |

📄 Each `pdfDigitalSignatureResult` entry:

| Field | Meaning |
|---|---|
| `signingTime` | when it was signed |
| **`signatureCode`** | **the verdict — see the signature status table below** |
| `certBeginDate` | certificate valid-from |
| `certExpireDate` | certificate valid-until |
| `certIssuerCN` | who issued the certificate |
| `certSubjectCN` | signer common name |
| `certSubjectO` | signer organisation |
| `certSubject` | full subject |
| `reason` | stated reason for signing |
| `embedTimestampResult` | 0–1 nested block, same shape — **has its own `signatureCode`** |
| `ltvCode` | Long-Term Validation status — **different code table** |
| `ltaCode` | Long-Term Archival status — **different code table** |
| `signatureType` / `signatureTypeCode` | Approval vs Certification signature — **different code table** |
| `signatureSeqNo` | 1-based order of signing, counted separately per type (Sig / TS) |

### Which structures decide the verdict

Three separate structures each carry a `signatureCode`, and the spec does not say how to combine them.
Our position, to be confirmed with the user (`PROGRESS.md` Q3(c)):

| Structure | Role |
|---|---|
| `pdfDigitalSignatureResult[]` | **decides the verdict.** This is "does the invoice have a valid digital signature" |
| `pdfTimeStampingResult[]` | ⚠️ **reporting only by default.** A document-level timestamp proves *when* it existed, not *who* signed it. A PDF with a timestamp but no digital signature is **not** a signed invoice |
| `embedTimestampResult` (nested) | ⚠️ **reporting only.** It qualifies its parent signature's time, and its status is already reflected in whether the parent is Trusted |
| `pdfaResult`, `ltvCode`, `ltaCode`, `signatureTypeCode` | reporting only — but `signatureTypeCode` `E0007`/`E0008` are worth surfacing (see below) |

⚠️ **A PDF can carry up to five signatures with five different verdicts, and only the five most recent
are reported at all.** The combination rule is a business decision, not something the API answers
(`PROGRESS.md` Q3(c)).

Fallback until decided — **most-severe-wins**, which yields a single outcome for the invoice rather than
just a yes/no:

```
Could not check  >  Untrusted  >  Warning  >  No supported signature  >  Trusted
```

Worked examples:

- one `S0001` + one `E0005` → **Warning**, not Trusted.
- one `N9999` + four `S0001` → **Could not check**, because part of the signing could not be assessed.
- one `N9999` + one `E0002` → **Could not check**, *not* Untrusted. ⚠️ This ordering is deliberate: a
  definite bad finding does **not** short-circuit an unknown one. It routes to a human rather than an
  automatic reject, on the reasoning that "one signature is bad **and** we couldn't read another" is a
  case someone should look at properly. Fallback if this proves to route too much to humans: rank
  *Untrusted* above *Could not check* instead — but make that an explicit decision, since it means
  auto-rejecting documents that were only partly assessed.

The per-entry codes and the entry count are recorded alongside the aggregate, so a human reviewing the
case can see what drove it. A ≥6-signature invoice is unlikely here but would silently drop the oldest
signature from the answer.

---

## Signature status codes — the heart of the design

📄 **Translated and regrouped** from the spec, pp.38–40 (the spec's own row order interleaves the
statuses; the Meaning column is a translation of the Thai, not a quotation).

| Code | Status | Meaning |
|---|---|---|
| `S0001` | **Trusted** | the digital signature is trustworthy |
| `S0002` | **Trusted** | the timestamp is trustworthy |
| `S0003` | **Trusted** | certificate has expired *(see trap 1)* |
| `S0004` | **Trusted** | certificate has since been revoked *(see trap 1)* |
| `E0001` | Warning | certificate status cannot be proven right now *(see trap 3 — transient, retry)* |
| `E0004` | Warning | signed with a certificate not matching the document type |
| `E0005` | Warning | part of the document is not covered by the signature/timestamp |
| `E0002` | **Untrusted** | **document was modified after signing/timestamping** |
| `E0003` | **Untrusted** | certificate was used *after* it had expired *(see trap 1)* |
| `E0009` | **Untrusted** | certificate was used *after* it had been revoked |
| `E0006` | **Untrusted** | the certificate holder's identity cannot be proven |
| `N0001` | null | no signature/timestamp, **or** unsupported format — **XML results only** |
| `N0002` | null | no signature/timestamp, **or** unsupported format — **PDF results** *(see trap 2)* |
| `N9999` | null | **system error — could not check** *(see trap 5)* |

📄 **There is no `E0007` or `E0008` in this table.** The numbering gap is real, not an omission on our
part: those two codes exist, but in the *SignatureType* table below, where they mean something
completely different. This is noted because a developer spotting the gap will otherwise go looking.

⚠️ **Rule for unrecognised codes:** any `signatureCode` not in this table → **manual review**. Never
pass, never auto-reject. The spec is from 2022 and demonstrably lags the live service, so new codes are
a realistic possibility. Fallback if this proves noisy: log the unknown code and alert, rather than
queueing every occurrence.

### The other code tables — same strings, different meanings

📄 Each of these uses the **same code strings** as the signature table, with unrelated meanings.

**SignatureType** (`signatureTypeCode`)

| Code | Meaning |
|---|---|
| `S0001` | Approval signature |
| `S0002` | Certification signature |
| `E0007` | part of the document lies outside the Certification signature |
| `E0008` | the document carries more than one Certification signature |
| `N0001` | cannot check the signature |
| `N0002` | Not Implemented |
| `N9999` | Internal Error |

⚠️ `E0007` and `E0008` are worth surfacing to a human even though `signatureTypeCode` is otherwise
reporting-only — both describe a document structured in a way that undermines what the signature
appears to cover. Fallback: report them alongside the verdict rather than changing the verdict.

**LTV / LTA** (`ltvCode`, `ltaCode`) — 📄 `S0001` Validate Successfully · `E0001` **Not LTV** ·
`E0002` **Not LTA** · `N0001` cannot be checked · `N0002` Not Implemented · `N9999` Internal Error.

**PDF/A** (`pdfaCode`) — 📄 `S0001` complied · `E0001` not complied (message lists the failures) ·
`N0001` cannot be checked · `N0002` Not Implemented · `N0003` no compliance specified ·
`N9999` Internal Error.

**Schema / Schematron / FHIR** — 📄 `S0001` Valid · `E0001` Invalid Version · `E0002` Invalid structure ·
`N0001`/`N0002`/`N9999` as above. XML only; not used on our path.

> ⚠️ **These tables reuse the same code strings with unrelated meanings — see trap 4 below.** Read each
> code field against its own table, never a shared one.

---

# The five traps

Each of these is a way a competent developer, reading the requirement and the spec honestly, arrives at
a wrong implementation. They are listed here because they change *requirements*, not just code.

## Trap 1 — "check the valid date" gives the wrong answer

The single most important finding in this document, and it contradicts the obvious reading of the
requirement.

The manual process is described as checking "the digital signature **and the valid date**". Implemented
literally — compare `certExpireDate` against today, reject if past — the bot would be **wrong**, and
wrong in the expensive direction: rejecting valid invoices.

📄 The spec draws the distinction explicitly:

- **`S0003` — certificate expired — is `Trusted`.** The signature was made while the certificate was
  valid; the certificate expiring afterwards does not retroactively invalidate it.
- **`E0003` — certificate used after expiry — is `Untrusted`.** The signature was made when the
  certificate was already dead.

The same pattern applies to revocation: `S0004` (revoked after signing) is Trusted; `E0009` (used after
revocation) is Untrusted.

So `certExpireDate` in the past is **completely normal** for a legitimately signed older invoice — any
invoice signed more than a certificate lifetime ago will show one.

**Rule: the verdict comes from `signatureCode`. `certBeginDate` / `certExpireDate` are for reporting
and audit trail, never for computing pass/fail.** State this in the developer brief in exactly those
terms, because a developer implementing "check the valid date" from the requirement text alone will get
it wrong, and the failure is silent — the bot returns a confident, well-formatted, incorrect answer.

## Trap 2 — `N0002` conflates two different business answers

📄 `N0002` means "the document has no digital signature/timestamp **or** was signed in a format the
system does not yet support."

The requirement is precisely "does this PDF have a digital signature or not". **The API cannot fully
answer that**, because a genuine signature in an unsupported format returns the same code as no
signature at all.

The risk is asymmetric and needs a business decision. The **outcome** is fixed either way — *No
supported signature*. What's open is the **disposition**:

- **Reject** (i.e. act as though it is simply unsigned) — simple, matches what the portal shows a human
  today, but will occasionally reject a genuinely signed invoice from a supplier using an exotic format.
- **Manual review** — safer, at the cost of a queue someone has to work.

⚠️ Our reading is that for e-Tax invoices under the Thai schemes the unsupported-format case is rare,
since those schemes mandate supported certificate types. Unverified. Fallback: **route `N0002` to manual
review rather than auto-rejecting**, at least initially, and count how often it fires. If it never fires
on real supplier traffic it can be downgraded to auto-reject later, with evidence. The reverse — starting
with auto-reject and discovering rejected valid invoices — is discovered by an angry supplier, not by a
log.

## Trap 3 — Warning is a third outcome, not a flavour of pass or fail

`E0001`, `E0004`, `E0005` are `Warning`, and they are not the same kind of thing as each other:

- **`E0001`** ("certificate status cannot be proven right now") is a **transient infrastructure
  condition** — ETDA could not reach a revocation source. It says nothing about the invoice.
  Re-running the same file later may legitimately return `S0001`.
- **`E0005`** ("part of the document is not covered by the signature") is a **genuine document
  property** and a real fraud vector — content can be added outside the signed region.
- **`E0004`** ("certificate doesn't match the document type") is also a document property.

⚠️ `E0001` should therefore be **retried**, not recorded as a verdict. Fallback and terminal rule, since
the retry can fail: **retry `E0001` a bounded number of times over a bounded window (values in config —
`PROGRESS.md` Q8); when exhausted, the invoice's outcome is *Could not check* and its disposition is
*Manual review* — never Accept and never Reject.** (See implication 5 for the outcome/disposition
split.) Without that terminal rule an invoice can sit in a retry loop with no verdict — which is the
failure mode the whole design exists to prevent.

## Trap 4 — one shared code-mapping function will produce garbage

Look at what `E0001` means in three different places:

- signature status → **Warning**, certificate status unprovable *(retryable)*
- `ltvCode` → **Not LTV** *(a neutral fact about the signature)*
- `pdfaCode` → **not PDF/A compliant** *(a document-format observation)*

And `E0002`: **"document modified after signing"** in the signature table — the most serious finding the
service can return — versus **"Not LTA"** in the LTA table, which is unremarkable.

⚠️ A developer who writes one `mapCode(code)` helper and reuses it across fields will produce confident
nonsense, and the specific failure mode is alarming: `ltaCode = "E0002"` misread through the signature
table becomes **"this invoice was tampered with after signing."** Fallback: **each code field must be
interpreted by its own table.** Name the lookup functions after the field (`mapSignatureCode`,
`mapLtvCode`), not after the code shape, and say so in the developer brief.

## Trap 5 — "no signature" and "we couldn't check" must not share a bucket

`N0001`, `N0002` and `N9999` all carry `Signature Status = null`, so it is tempting to treat null as one
outcome meaning "unsigned". **They are not the same thing:**

- `N0002` — the PDF genuinely has no supported signature. **A business outcome about the invoice.**
- `N9999` — ETDA's system errored and could not check. **Says nothing about the invoice at all.**
- `N0001` — the XML-only variant. ⚠️ Appearing on a `pdfDigitalSignatureResult` would be anomalous;
  treat it as an error, not as "unsigned". Fallback: route to manual review and log the anomaly.

Collapsing these means an ETDA outage gets reported to the business as *"these invoices are unsigned"* —
a confident, wrong, and actionable-looking answer produced by an infrastructure failure. See the
five-outcome model in the implications below.

---

## Limits

📄 From the FAQ (**not** from the API spec — the spec documents `P1003` File Size Limit Exceeded but
states no number):

| Format | Maximum |
|---|---|
| PDF / PDF/A-3 | **20,480 KB** |
| XML | 3,072 KB |
| JSON FHIR | 3,072 KB |

⚠️ We read "KB" here as binary kilobytes, so **20,480 KB = 20,971,520 bytes** (20 MiB), not 20,000,000.
Getting this wrong in the safe direction costs nothing; getting it wrong the other way silently rejects
files between 20,000,000 and 20,971,520 bytes. Fallback: **express the configured limit in bytes
(`20971520`), not in "MB"**, and treat `P1003` as the authority — the pre-check is an optimisation to
avoid a pointless upload, not the real gate.

📄 Also from the FAQ: **only the 5 most recent signatures and 5 most recent timestamps are checked, and
that applies to PDF files only.**

⚠️ The FAQ's limits describe the **portal**; whether the API enforces identical numbers is not stated.
Fallback: keep the limit configurable and let `P1003` be authoritative.

📄 **Uploaded files are not retained** by ETDA; **validation results are stored** for display.

⚠️ Note what that second clause implies: the stored results include `certSubjectCN` / `certSubjectO` —
i.e. supplier identity. "Files aren't retained" is therefore **not** a complete answer to the
data-protection question. Fallback: treat the compliance question as open (`PROGRESS.md` Q9), not
settled by this line.

📄 **No login is required for the portal.** The API uses the `apikey` header instead.

---

## Spec is stale in at least one respect

📄 The API spec is v2.2 / May 2022 and describes `FileType` as `{null, "pdf", "xml"}`. But the portal
FAQ and the live site advertise **JSON FHIR (.json)** support and e-Medical Certificates, and the result
body already contains an `XMLfhirResult` block.

So the written spec lags the deployed service. ⚠️ Consequence: **treat the spec as authoritative on what
exists, not exhaustive on what exists** — the live service may accept parameters or return fields the
document does not mention. Fallback: the bot must not fail on unexpected extra JSON fields, and the
developer should re-request the current spec version when applying for the API key rather than building
from this 2022 document alone.

This does not affect our PDF path, which is documented consistently throughout. It does affect how much
weight a 📄 mark deserves.

---

## Implications for our design

Carried into the PDD and the design phases. **Except where marked as a confirmed decision — implication
1, which records D1 — nothing here is a decision yet; decisions are the user's.**

1. **API, not browser automation** — confirmed decision D1. The fragile UI layer disappears; the bot
   uses two documented endpoints, the second of them polled (implication 4).

   **Binding constraint: the validation call is isolated as a single logical step**, whose **output
   contract** is what the rest of the bot may depend on:

   - the aggregate **outcome** (one of the five) **or** a **verify-stage business exception**
     (`P1001` invalid file type, `P1003` too large) — those two are not outcomes but must still be
     reportable distinctly, per implication 5;
   - the **disposition** (Accept / Reject / Manual review / Retry);
   - a **run-fatality flag** — whether this failure is item-scoped or fatal to the whole run
     (`401`/`404`/`405`, **any undocumented 4xx**, clustered `400`s, or the Q8 consecutive-failure
     threshold — see "HTTP and authentication failures"). Without this the caller would have to read
     HTTP codes to know whether to abort, which the boundary forbids. ⚠️ Two of those conditions are
     **cross-invocation** — a single call cannot know it is the hundredth consecutive failure — so
     **the consecutive-failure counter lives inside the boundary**, owned by the step. Fallback: if the
     chosen platform makes step-local state awkward, pass the counter in and out as part of the
     contract; what must not happen is the caller keeping its own tally by inspecting HTTP codes, which
     reintroduces exactly the coupling the boundary removes;
   - the **per-signature entries** — `signatureCode`, `signatureTypeCode` (so `E0007`/`E0008` can be
     surfaced as the code tables require), certificate fields, `signingTime`, and `ltvCode`/`ltaCode`
     if those are to be reportable at all. ⚠️ Timestamp entries (`pdfTimeStampingResult`) are omitted on
     two grounds together: Q3(c)'s default keeps them out of the verdict, **and** no reporting
     requirement for them exists yet (Q5). **A non-default answer to Q3(c)'s *timestamp* question
     widens this list** — a different aggregation ranking does not. Fallback: carry them from the start
     if either answer looks likely, since adding a field is cheaper than a second pass over the design;
   - the **transaction identifiers** `TransactionID` and `TransactionDate` (implication 8). ⚠️ Always
     handed back, but the field is unreliable as a success signal **in both directions**: it may be
     `null` on a failed submission, *and* the spec's examples show it populated on a failure code too
     (see the ⚠️ under the Verify API). So the caller must tolerate null and must never read its
     presence as success. Fallback: the outcome and the run-fatality flag are the only success signals
     in this contract.

   Nothing outside the step reads raw JSON, HTTP codes, or page content. ⚠️ This list is the minimum the
   already-written obligations in this document imply; Phases 2–4 may add to it. Fallback: if a later
   phase needs something not listed, **widen the contract rather than reaching around the boundary** —
   a single caller reading raw JSON dissolves the constraint entirely.

   ⚠️ **Be honest about what this boundary buys.** The output contract above is API-shaped: a UI
   fallback could not populate `TransactionID`/`TransactionDate` at all, and per D1's own reasons 2–3
   may not yield per-signature codes either. So the boundary **limits** what a fallback would cost — it
   does **not** make the two routes interchangeable, and it is not true that everything outside is
   identical either way. Fallback if the key is ever refused: expect the audit trail (implication 8,
   Q14) and possibly the five-outcome granularity to degrade, and re-open both at that point rather
   than assuming a clean swap.

   ⚠️ Fallback on the boundary itself: if a separate component is awkward in the chosen platform, a
   named Sequence is sufficient — the requirement is the contract, not the packaging.

   **Do not build both paths** — that doubles the build cost to insure against something there is no
   evidence will happen.

2. **Byte integrity is a hard requirement — and getting it wrong manufactures a fraud signal.**
   The bot must save the email attachment **byte-for-byte**, hash *that exact byte stream*, and upload
   *that same stream*. Any re-save, re-render, normalisation, "optimise/flatten PDF" step, or
   round-trip through a library that rewrites the file will either produce `P1002` (digest mismatch) or
   — far worse — a genuine `E0002`, **"document was modified after signing"**. That is our own bot
   fabricating evidence of tampering against an innocent supplier. Note this explicitly in the
   developer brief; it is the least obvious requirement in this document.
   ⚠️ The same risk exists upstream, outside our control: mail gateways and AV scanners that rewrite
   attachments will break signatures before the bot ever sees the file. Fallback: if `E0002` appears at
   an implausible rate on first run, suspect the mail path before suspecting the suppliers.

3. **SHA-256 hashing capability is mandatory**, not optional — the `digest` field is required.
   ⚠️ If UiPath is chosen (see `PROGRESS.md` Q7), this means the **`UiPath.Cryptography.Activities`**
   package — an extra dependency to declare. ❓ Confirm it emits **lowercase hex** rather than Base64 or
   uppercase, since `P1002` is the only feedback on getting it wrong. Fallback: normalise the hash
   string to lowercase hex explicitly rather than trusting the activity's default.

4. **A polling loop with a bounded timeout** is mandatory (`P2002`), with interval and cap in config,
   plus the `E0001` retry schedule from trap 3. See `PROGRESS.md` Q8 — nobody has chosen these numbers.

5. **Five outcomes, not two — and outcome is not the same thing as what happens next.**
   The original "has a signature or not" framing is too narrow to specify the bot against. Two separate
   vocabularies are needed, and conflating them is how contradictions creep in:

   - **Outcome** = what the check *established about the invoice*. Determined by ETDA. Not negotiable.
   - **Disposition** = what the bot *does about it*. A business decision (`PROGRESS.md` Q3), and the
     only one of the two the user gets to choose.

   **Outcomes.** ⚠️ This table applies to `signatureCode` **inside `pdfDigitalSignatureResult` only** —
   it is not a general code map. `S0002` ("timestamp is trustworthy") appears in the Trusted row because
   it is a legal value of the field, **not** because a timestamp-only PDF is a signed invoice; see
   "Which structures decide the verdict". Fallback: if `pdfDigitalSignatureResult` is empty, the outcome
   is *No supported signature* regardless of what `pdfTimeStampingResult` contains.

   | Outcome | Triggered by | Nature |
   |---|---|---|
   | **Trusted** | `S0001` `S0002` `S0003` `S0004` | verdict about the invoice |
   | **Untrusted** | `E0002` `E0003` `E0006` `E0009` | verdict about the invoice |
   | **Warning** | `E0004` `E0005` | verdict about the invoice |
   | **No supported signature** | `N0002` (on a PDF result) | verdict about the invoice |
   | **Could not check** | *Immediately, no retry:* `N9999`; `N0001` on a PDF result; unrecognised `signatureCode`; `P2001` `P2003` `P2004` *(ETDA-side or anomalous)*; `P1002` `P1004` `P1005`; HTTP `400` `401` `404` `405` *(our-bot or config defects — they will not fix themselves)*. *Only once retries are exhausted:* `E0001` `P1999` `P2999`, HTTP 5xx, connection timeouts | **not a verdict** — an error state |

   ⚠️ **Exhausted `E0001` belongs in *Could not check*, not in *Warning*.** It reports that ETDA could
   not reach a revocation source — it says nothing about the invoice (trap 3). Filing it under Warning
   would let it inherit Warning's disposition, so a user answering Q3(a) "Warnings are acceptable" would
   silently auto-accept invoices nobody ever managed to check. Fallback: if this proves too noisy in
   practice, the fix is a longer retry window, never reclassification.

   ⚠️ **Verify-stage failures need outcomes too**, since an invoice rejected at submit time never
   reaches the Result API. `P1001` (invalid file type) and `P1003` (too large) are **business
   exceptions** about the file rather than error states — they carry their own dispositions and should
   be reported distinctly from *Could not check*, which implies "try again later". Fallback: if
   distinguishing them is not worth the complexity, fold them into *Could not check* — never into
   *No supported signature*, which asserts something about the invoice that was never established.

   **Dispositions.** ⚠️ Our recommended defaults, pending Q3:

   | Disposition | Meaning | Applies to |
   |---|---|---|
   | **Accept** | passes automatically | Trusted |
   | **Reject** | fails automatically | Untrusted |
   | **Manual review** | a human decides; the bot has done its job by routing it | Warning · No supported signature · **Could not check** · `P1001` · `P1003` |
   | **Retry** | **not a resting state** — a staging state that must resolve. On exhaustion the outcome becomes *Could not check* and the disposition *Manual review* | `E0001` · `P1999` · `P2999` · HTTP 5xx / connection timeouts. ⚠️ **Not** `400`/`401`/`404`/`405` — a malformed request, revoked key or wrong URL is not transient, and retrying wastes the run. *(If a `401` turns out to be transient at ETDA's end, see the fallback under "HTTP and authentication failures".)* |

   **Every one of the five outcomes maps to exactly one default disposition**, and nothing may end a run
   sitting in *Retry*. ⚠️ Fallback if Q3 is still unanswered when the build starts: ship these defaults
   **behind config**, so the user can change a mapping without a code change — the defaults are all
   conservative (nothing auto-accepts except Trusted), so shipping them is safe even if they are later
   revised.

   ⚠️ **Manual review is a disposition, not an outcome.** Everywhere this document says "manual review",
   it means the disposition — the invoice still carries whichever of the five outcomes it earned, and
   that outcome is what gets recorded. Fallback: if the eventual design has no manual queue, "manual
   review" collapses to "Reject **and** notify a human", which is materially different from a silent
   reject and must be built as such.

   The *Could not check* row is the one that is easy to lose. It must be visibly distinct in whatever
   the bot outputs, because "we don't know" is a different instruction to a human than "this invoice is
   unsigned."

6. **The verdict never comes from date arithmetic.** See trap 1.

7. **Each code field is read against its own table.** See trap 4.

8. **`TransactionID` and `TransactionDate` must be persisted per invoice.** ⚠️ They are the only handle
   for an ETDA support query and the only audit link between an invoice and the verdict recorded
   against it. Fallback: log them even for failed transactions — a `P2003` with no transaction ID cannot
   be investigated afterwards.

9. **Production host and rate limits must be obtained with the API key** — both are config values and
   neither is documented.

## Open questions for ETDA

To be asked when submitting the API access request, since none are answerable from the documents:

1. What is the **production** base URL?
2. Is there a **rate limit** or daily quota?
3. Is there a **current API spec** newer than v2.2 (May 2022)?
4. What is the maximum time a transaction can sit at `P2002` before `P2004`, and what polling interval
   does ETDA recommend?
5. Does the API enforce the same 20,480 KB PDF limit as the portal, and is that decimal or binary KB?
6. Is the UAT environment (`api-uat.teda.th`) available for the developer's integration testing, and
   does it need a separate key from production?
7. Are password-protected / encrypted PDFs supported, and which code is returned for one?
   *(Feeds the malformed-input question — `PROGRESS.md` Q10.)*
8. How long are validation results retained, and what personal or company data do they contain?
   *(Feeds the compliance question — `PROGRESS.md` Q9.)*
9. **Is automated / bulk submission via the API permitted?** The terms of service neither allow nor
   forbid it, and the whole design assumes it is fine. Confirming it in writing while requesting the key
   costs nothing and closes the one inference D1's reason 4 rests on.
