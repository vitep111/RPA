# Reference files — drop zone

**Nothing you drop in this folder gets committed.** The repo's `.gitignore` excludes everything here
except this README, so real supplier names, bank details, and invoice amounts never reach GitHub. I
can still read the files locally.

> **Updated 2026-08-18.** The validation service publishes a free API, and calling it rather than
> driving the website is now **confirmed decision D1** (`../docs/PROGRESS.md`; detail in
> `../docs/teda-validation-api-reference.md`). That **raised** the value of sample PDFs and **lowered**
> the value of portal screenshots. Priorities below reflect that.

---

## 1. Sample invoices — the priority

These are what the external developer's integration tests run against, and what proves the bot's logic
is right before anyone pays for a build.

- **Signed and currently valid** — the happy path.
- **No digital signature at all** — the most common real-world case, and the one designs get wrong.
- **Signed, with a certificate that has since expired** — if you have one.

That third one matters more than it looks, and **not for the reason you'd expect**. ETDA classifies
*"certificate has since expired"* as **Trusted** — the signature was made while the certificate was
live, so it stays good. Only *"certificate was used after it expired"* is Untrusted. So this sample's
job is to come back **Trusted**, exactly like the happy path. If a build returns "invalid" for it,
that build has implemented "check the valid date" literally and will reject legitimate older invoices.
It's the regression test for trap 1 in `../docs/teda-validation-api-reference.md`, and the only way to catch that empirically
rather than by reading code.

⚠️ **Which means the three above do not cover the "Untrusted" verdict at all** — the most serious
answer the bot can give. If you have an invoice that was **tampered with after signing**, or one signed
*after* its certificate expired, that's the sample that matters most. If you don't (and most people
won't), we can manufacture it: take the signed-and-valid sample and alter it after the fact. That's
precisely what ETDA's `E0002` detects. Say so if you'd like me to note that in the build brief.

*(The remaining two outcomes — Warning and "Could not check" — can't be produced by any file at all,
since they depend on ETDA-side conditions. Those get tested against simulated responses.)*

Also useful if you have them: an invoice from a supplier using an **unusual signing tool** (tests the
`N0002` unsupported-format case), a **password-protected** one, and anything over the documented
**20,480 KB** size limit — the last two feed Discovery Q10 (malformed inputs), which currently has no
answer at all.

### Now also needed: XML samples (scope decision D3, 2026-08-18)

XML invoices are in scope alongside PDF, so the same range is needed again on that side:

- **A signed XML e-Tax invoice** — the XML happy path. Note the XML size ceiling is **3,072 KB**, far
  lower than PDF's.
- **A PDF/A-3 with the XML embedded inside it** — this is how Thai e-Tax invoices commonly arrive, and
  it's the only way to settle **Q17**: ETDA may return both a PDF and an XML verdict for one file, and
  nothing tells us which governs if they disagree. A real sample answers in minutes what speculation
  cannot answer at all.
- **An XML that fails structure validation**, if you have one — feeds **Q16**.

> **Do not re-save or re-export a PDF to redact it.** Re-saving usually strips the digital signature,
> which destroys the exact thing being tested. If an invoice is too sensitive to share as-is, send a
> test invoice or one from a supplier you don't mind me seeing instead.

## 2. Access details — needed to unblock the API key

- Has anyone **already requested a TEDA API key**, or is this starting from zero?
- Which **entity/organisation** would the request be made under? ETDA's request form will ask.
- Can the machine running the bot **reach the internet** (specifically `api-uat.teda.th` and the
  production host), or is it on a restricted network? This decides where the bot can run at all.

## 3. Portal screenshots — now optional

Only useful as a **human cross-check**: confirming the API's verdict matches what a person sees on the
site for the same file. If convenient, the result screen for a signed and an unsigned PDF is enough.
No longer needed for building selectors, since we aren't automating the page.

## 4. Anything defining "valid" for your organisation — optional

An audit/compliance rule or a policy document stating what makes an invoice signature acceptable. This
would confirm or revisit **decision D4** in `../docs/PROGRESS.md` — the outcome/disposition mapping,
settled 2026-08-18 on the proposed defaults. A written policy beats a reconstruction from memory, and
D4's mappings all live in config so revising one is an edit rather than a rebuild.

Separately, if there is a **data-protection or outbound-data policy**, that feeds Q9: sending every
supplier invoice to a third-party service automatically is a different proposition from a person
uploading the occasional one, and ETDA does store the validation results. Q9 also covers a second
point worth putting in front of the same people: **ETDA's terms disclaim the accuracy of a validation
result and any liability for relying on it.** The bot's verdict is evidence, not a warranty — which
matters most where an invoice would be accepted or rejected automatically, with nobody looking.

---

## What happens next

Once files land, I'll update `../docs/PROGRESS.md` (closing what they answer) and write `../docs/PDD.md` —
though the PDD is currently blocked on the still-open Discovery questions (**Q5** most of all), most of
which are conversation rather than files.
