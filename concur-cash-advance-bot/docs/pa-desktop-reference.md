# Power Automate Desktop — Syntax & Behavior Reference (SUPERSEDED)

> # ⛔ SUPERSEDED — NOT THE RULEBOOK
>
> **This project was rebuilt on UiPath. The active rulebook is [`uipath-reference.md`](uipath-reference.md).**
>
> This file is retained only as the **historical PA Desktop-era record** — the live-verified findings below were real and were expensive to learn, so they are kept rather than deleted. But **nothing in this file governs the current design**, and the `rpa-design-reviewer` agent must check against `uipath-reference.md` instead.
>
> **Do not carry the Lessons Learned forward.** L1 (`If` multi-condition vs. Boolean precompute) and L2 (`Set variable` can never be blank — use `N/A`) are **PA Desktop parser quirks with no UiPath equivalent**. UiPath's `Assign` has neither restriction, and `If` takes an ordinary VB.NET boolean expression with `AndAlso`/`OrElse`. Applying these rules to the UiPath design would be a defect, not a safeguard.
>
> Likewise void: rule 9.1's flow-scoped `Go to`/`Label` behavior, which the old one-Main-flow architecture decision rested on. UiPath has no `Go to` — see `uipath-reference.md` → R9 for the replacement mechanism.

**Purpose (historical):** This *was* the source of truth for how PA Desktop parses fields and behaves, back when the bot targeted PA Desktop. Every step in the then-current `detailed-design.md` had to conform to it, and the `rpa-design-reviewer` agent used to check the design against this file. **Neither is true any more** — see the banner above; the active rulebook is `uipath-reference.md`. This file no longer grows.

> **Status of each rule:** ✅ = verified in PA Desktop by the user · ⚠️ = believed correct but **not yet verified** (treat with caution).

---

## 1. Variables & Expressions

| # | Rule | Correct (PA Desktop) | Wrong (UiPath/VB.NET) | Status |
|---|---|---|---|---|
| 1.1 | Reference a variable in any field | `%MyVar%` | `MyVar` | ✅ |
| 1.2 | Literal text in a value field — no quotes | `Hello World` | `"Hello World"` | ✅ |
| 1.3 | Build a path/string with variables (interpolation) | `%Folder%\File_%Stamp%.xlsx` | `Folder + "\File_" + Stamp + ".xlsx"` | ✅ |
| 1.4 | Set a **Number**-typed variable | `%3%` (the `%%` forces numeric) | `3` (becomes text "3") | ✅ |
| 1.5 | Any calculation / expression | wrap in `%...%`, e.g. `%RetryCount + 1%` | bare `RetryCount + 1` | ⚠️ |
| 1.6 | Concatenation inside `%...%` is allowed too | `%Folder + "\" + File%` also works | — | ⚠️ |
| 1.7 | `Set variable` cannot evaluate a comparison against an empty string literal | `%SomeVar = ""%` (or similar) inside a `Set variable` action's Value field errors ("value cannot be empty") — do **not** use `Set variable` to precompute a Boolean flag this way. Use the `If` action's native multi-condition list instead (rule 4.4). | ✅ |
| 1.8 | `Set variable`'s Value field cannot be left blank at all | Confirmed: `Set variable` errors ("parameter value can't be empty") if the Value field is left with **nothing** typed in it — not just for expressions (1.7), but for a plain literal too. There is no way to deliberately set a variable to a true empty string via `Set variable`. Where a "no value" case is needed (e.g. `LogUserID`/`LogRequestID` on a run-level log row with no specific user/request), set an explicit literal placeholder instead — this design uses `N/A`. | ✅ |

> Both interpolation (1.3) and in-`%%` concatenation (1.6) are valid. Prefer **interpolation** — it's what was tested and is easier to read.

## 2. Subflows

| # | Rule | Detail | Status |
|---|---|---|---|
| 2.1 | Subflows exist and are callable | "Run subflow" action | ✅ |
| 2.2 | **Subflows have NO parameters** | All variables are **global** across the main flow and every subflow. No argument passing, no local scope. | ✅ |
| 2.3 | "Passing" data to a subflow | Caller **sets global variables first**, then runs the subflow, which reads those globals. | ✅ |

## 3. Excel Actions

| # | Rule | Detail | Status |
|---|---|---|---|
| 3.1 | "Write to Excel worksheet" writes **one cell** | Passing a list to a single cell writes its text form `["a","b"]` into that one cell — it does NOT spread across columns. Write each column with its own action. | ✅ |
| 3.2 | Cell targeting | Use Column (number or letter) + Row, e.g. Column `3`, Row `%FirstFreeRow%`. | ⚠️ |
| 3.3 | Find next empty row | "Get first free column/row from Excel worksheet" → returns `FirstFreeColumn`, `FirstFreeRow`. | ⚠️ |
| 3.4 | Keeping a workbook open across the flow | Launch Excel once, keep the instance in a global var, save/close at the end. | ⚠️ |

## 4. Files & Conditions

| # | Rule | Detail | Status |
|---|---|---|---|
| 4.1 | File-existence check | "If file exists" is a **conditional block** (if exists / if does not exist), not a boolean-returning action. | ⚠️ |
| 4.2 | `If` single-condition form | Separate fields: First operand `%A%` · Operator (dropdown, e.g. "Less than or equal to") · Second operand `%B%`. Not a single expression box. Used for simple retry/count checks (e.g. `%RetryCount% Less than or equal to %MaxRetry%`). | ⚠️ |
| 4.3 | Increment variable | "Increment variable" action: Variable `%RetryCount%` + Increment-by value `1`. Not `RetryCount + 1` inline. | ⚠️ |
| 4.4 | `If` supports **multiple conditions combined by AND/OR**, added directly in the action's built-in condition list | Each condition is an operand + operator (e.g. `%ConcurBaseUrl%` `is empty`), and multiple such conditions can be OR'd (or AND'd) together in **one** `If` action — no separate flag-precompute step needed. Confirmed live: `%A% is empty OR %B% is empty OR %C% is empty ...` works directly. **Do not** try to precompute the OR into a Boolean via `Set variable` first (see rule 1.7 / Lessons Learned L1 — that approach fails live). | ✅ |
| 4.5 | Stop the whole run | Assumed action name "Stop flow" (a.k.a. "Exit" / end flow). Confirm exact action. | ⚠️ |
| 4.6 | Best-effort action | Set an action's "On error → Continue flow run" so a non-critical failure (e.g. closing an unset browser) doesn't abort. | ⚠️ |

## 5. Retry Loop Semantics

| # | Rule | Detail | Status |
|---|---|---|---|
| 5.1 | For exactly `MaxRetry` retries | Start `RetryCount = 0`; on error increment, then test `RetryCount <= MaxRetry` to retry. Using `<` gives `MaxRetry - 1` retries. | ⚠️ |

## 6. Sensitive Data

| # | Rule | Detail | Status |
|---|---|---|---|
| 6.1 | Secrets | Use the "Sensitive" data-type toggle so the value is hidden from the variables pane and logs. Never write a secret to the Excel log. | ⚠️ |

## 7. Loops & Manual Errors

| # | Rule | Detail | Status |
|---|---|---|---|
| 7.1 | `Loop Condition` (While-style) | Loops while a condition holds, same operand/operator structure as `If` (4.2). Used to poll for a file's existence up to a timeout. | ⚠️ |
| 7.2 | `Exit Loop` | Action that breaks out of the innermost enclosing loop. | ⚠️ |
| 7.3 | `Throw error` | Manually raises an error with a custom message, which is caught by the surrounding "On block error" handler like any action failure. Used to convert a "polled and gave up" condition into the same fatal/retry path as a thrown action error. | ⚠️ |
| 7.4 | Reading an Excel range to a table | "Read from Excel worksheet" (mode: read all/used range, first row as headers) outputs a **Datatable** variable. Row count is read via `%TableVar.RowsCount%`. | ⚠️ |

## 8. Global Retry Counters — Reuse Hazard

| # | Rule | Detail | Status |
|---|---|---|---|
| 8.1 | `RetryCount` is a single global reused across every retryable block in the flow | It is **not** auto-reset between blocks. Each new retryable section must explicitly `Set variable RetryCount = %0%` immediately before its own retry target label, otherwise a block that entered with a nonzero `RetryCount` (left over from an earlier retry elsewhere in the run) gets fewer retries than `MaxRetry` allows. | ⚠️ |

## 9. `Go to` / `Label` Scope

| # | Rule | Detail | Status |
|---|---|---|---|
| 9.1 | `Go to` + `Label` are scoped to a single flow | Assumed: a `Go to` action cannot jump into a `Label` that lives in a different flow/subflow — only within the same flow (Main, or within one subflow). This is the load-bearing assumption behind keeping all 6 phases inline in one Main flow (see detailed-design.md "Flow & Subflow Structure") rather than splitting each phase into its own subflow. | ⚠️ |

---

## Lessons Learned (PA-specific traps found during design)

> ⛔ **VOID — PA Desktop only.** These are parser quirks of PA Desktop with **no UiPath equivalent**, and the project is now on UiPath. UiPath's `Assign` has neither restriction, and `If` takes an ordinary VB.NET boolean expression. **Applying L1 or L2 to the UiPath design would be a defect, not a safeguard.** See the banner at the top of this file; the active rulebook is `uipath-reference.md`.

These are places where the design's first draft got PA Desktop's actual behavior wrong. Recorded so the same trap isn't reintroduced, and so the `rpa-design-reviewer` agent explicitly checks for each.

| # | Lesson | Where it bit us | Correction | Rule |
|---|---|---|---|---|
| L1 | **Two wrong turns, corrected in sequence:** (1) first assumed PA Desktop's `If` only takes one condition, so multi-condition OR checks (config-empty, bad-headers) were written wrong from the start; (2) "fixed" that by precomputing the OR into a Boolean via `Set variable` (`%A = "" OR B = ""%` → flag, then `If %Flag% Equal to %True%`) — **this also failed live**, because `Set variable` errors on a comparison against an empty-string literal ("value cannot be empty"). **Verified correct behavior:** `If`'s own condition list natively supports multiple `is empty`/other conditions combined with `OR` (or `AND`) in one action — no flag, no precompute, just add conditions directly in the `If` action. | detailed-design.md Step 1.10b (config-empty check, OR of 5) and Step 3.10 (bad-headers check, OR of 2) — both went through both wrong turns before landing on the verified form. | Use `If`'s built-in multi-condition OR list directly: `%A% is empty OR %B% is empty OR ...`, one `If`, one Then-body. | 4.4 ✅, 1.7 ✅ |
| L2 | **`Set variable` cannot be left blank — at all, not just as an expression.** The design's original "Set Log Fields" pattern used `LogUserID = (empty)` / `LogRequestID = (empty)` on every run-level log row (Fatal aborts, "No items", "Run Summary") to signal "no specific user/request for this row." Live testing showed `Set variable` throws "parameter value can't be empty" the moment the Value field is left with nothing in it — there is no way to assign a true empty string this way. | Every "Set Log Fields - ..." action across Phase 1 and Phase 3 (config invalid, credential fail, browser fail, grid load failed, export failed, export unreadable, bad headers, no pending items) — 8 call sites total. | Set an explicit literal placeholder instead of leaving the field blank. This design uses the literal `N/A` for `LogUserID`/`LogRequestID` on run-level rows. | 1.8 ✅ |

**Reviewer rule (⛔ VOID — PA Desktop only; do NOT enforce against the UiPath design):** flag any `Set variable` (or table cell describing one) whose Value is written as "(empty)", "(blank)", or similarly implies no characters at all — L2 means that never builds. It must be an explicit literal (this project's convention: `N/A`) or a real variable reference. Also flag any `Set variable` that precomputes a Boolean from a comparison against `""`/empty (L1/rule 1.7 — confirmed broken), or manually splits an OR-of-conditions into stacked single-condition `If`s when the built-in multi-condition `If` would do it directly (L1/rule 4.4). The correct defaults now are: **one `If`, multiple OR'd conditions, added directly** — and **never a truly blank `Set variable` value.**

> Still-open, same family — not yet hit, but worth checking as later phases are designed:
> - **AND-combined conditions** in one `If` — same multi-condition list mechanism as OR should apply (per 4.4), but not separately confirmed live; verify if a design needs it.
> - **Compound conditions inside a `Loop Condition`** (7.1) — unconfirmed whether the same OR/AND condition list applies to `Loop Condition` as it does to `If`.
> - **Inline `If`/ternary inside a value field** (e.g. `%IsX ? "a" : "b"%`) — PA Desktop has no ternary; use a preceding `If`/`Set` instead.

---

## Open items to verify in PA Desktop
- 3.2 / 3.3 exact action names and output variable names.
- 4.1 exact "If file exists" block wording.
- 4.4 whether the multi-condition `If` list also supports `AND` (only `OR` confirmed so far).
- 4.5 exact "Stop flow" / end-run action name.
- 5.1 confirm off-by-one on the retry operator with a real failing case.
- 7.1–7.4 loop/throw-error/datatable action names, exactly as PA Desktop labels them.
- Whether `Loop Condition` (7.1) also supports a multi-condition OR/AND list like `If` does (rule 4.4), or is single-triple only.
- Datatable column-membership expression `%PendingList.Columns%` `does not contain "..."` (Phase 3 Step 3.10) — not yet confirmed; fallback is reading the header row explicitly and comparing cells.
- 9.1 whether `Go to`/`Label` really are flow-scoped — this is load-bearing for the one-Main-flow architecture decision; confirm before build.

Add new rows here as they're discovered and tested.
