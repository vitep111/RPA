# Reference files — drop zone

Put the source files here. They close Open Items #3 and #4 and let the Phase 3 mapping table carry real column names instead of placeholders.

**Nothing you drop in this folder gets committed.** The repo's `.gitignore` excludes everything here except this README, so live vendor names, tax IDs, and email addresses never reach GitHub. I can still read the files locally.

---

## 1. SBN upload template — required

The template from the SBN **Upload Vendors** page ("Download latest template version"). Any filename is fine.

**Tell me which format the download actually is** (`.csv` or `.xlsx`) — it changes how Phase 3 reads the header row, and an `.xlsx` template can't answer the CSV-format questions below at all.

Closes / narrows:
- **Open Item #3** — exact column headers and their order. Phase 3 builds its output table from this header row at runtime.
- **⚠️ U8** (CSV format: delimiter, encoding, quoting, line endings) — **only if the template is a CSV.**

Also needed alongside it:
- **Which columns SBN marks as mandatory.** Phase 3 maps six fields and leaves any other template column blank. A seventh *required* column would not fail the bot — it would surface as "Errors Found" in Phase 4, after the upload.
- **A file SBN has already accepted**, if you have one. That settles U8 by example rather than assumption, and shows the real Country format (`DE` vs `Germany`) and which Tax ID value SBN expects.

## 2. SAP SQVI export — required

A sample export of the query result — a normal day's output, exported the way the bot will export it (System → List → Export → Spreadsheet).

Closes / narrows:
- **Open Item #4** — the exact output column names for the six mapped fields, replacing the `NAME1` / `LIFNR` / `STCD1` / `ORT01` / `LAND1` / `SMTP_ADDR` placeholders in the Phase 3 mapping table.
- **Tax ID** — whether the query returns `STCD1` or `STCEG`/VAT.
- **Country** — code or name.
- **⚠️ U10** — the shape of the export file: the format SAP actually writes, which row the headers land on, and whether there are preamble rows. Phase 3's `Read Range` currently assumes a clean sheet with headers in row 1.
- **The query's join behavior** (PDD Prerequisites) — confirm **one row per vendor**, and that a vendor with **no default email appears with a blank** rather than dropping out of the file. If such vendors are missing, `FLGDEFAULT = 'X'` is sitting in a WHERE clause instead of the JOIN ON, which collapses the outer join and silently loses those vendors.

> This file does **not** answer ⚠️ U7 (driving the export via the SAP menu — menu path, file-format dialog, overwrite handling). That needs a live run during build.

## 3. Screenshots — optional, but cheap while you're in SAP

- **SQVI status bar on a no-records run** — the "no values were found" message text, verbatim. This is the only thing that closes **⚠️ U2**, the empty-day detection. An empty-day *export* can't close it: the message lives on screen, not in a file, and on the empty path the bot never exports at all. An empty-day export would only exercise U2's *fallback* (treat zero rows as empty).
- **The SQVI query-list / selection screen** — narrows **⚠️ U9** (how the bot picks the named query and reaches its selection screen).
- **The query's selection screen showing the create-date field** — narrows **⚠️ U5** (the SAP date display format the bot must type).

---

## What happens next

Once the files land, I'll read them and update:
- `docs/medium-level-design.md` — the Phase 3 mapping table, with real names.
- `docs/uipath-reference.md` — narrow or resolve U8 and U10 (plus U2/U5/U9 if the screenshots come).
- `docs/PDD.md` and `docs/PROGRESS.md` — close Open Items #3 and #4, and record the join-behavior verification.
