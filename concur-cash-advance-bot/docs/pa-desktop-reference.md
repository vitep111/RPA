# Power Automate Desktop — Syntax & Behavior Reference

**Purpose:** The source of truth for how PA Desktop actually parses fields and behaves. Every step in `detailed-design.md` must conform to this. The `rpa-design-reviewer` agent checks the design against this file. Grows whenever a new discrepancy is found and verified in PA Desktop.

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
| 1.7 | Boolean / logical operators inside `%...%` | `%A = "" OR B = ""%`, `AND`, `NOT`, `=` (comparison), empty-string literal `""`. Used to precompute a Boolean flag for a multi-condition test (see 4.4 / L1). | ⚠️ |

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
| 4.2 | `If` condition structure | Separate fields: First operand `%A%` · Operator (dropdown, e.g. "Less than or equal to") · Second operand `%B%`. Not a single expression box. | ⚠️ |
| 4.3 | Increment variable | "Increment variable" action: Variable `%RetryCount%` + Increment-by value `1`. Not `RetryCount + 1` inline. | ⚠️ |
| 4.4 | `If` takes **one** condition only — no multi-condition AND/OR builder | **Resolved pattern (see L1):** never write "OR of 5 things" in one `If`. Precompute the combined condition into a single **Boolean** with one `Set variable` using in-`%%` logical operators (rule 1.7), then `If %Flag% Equal to %True%`. Keeps any shared Then-body written once. **Fallback** if the inline OR expression won't evaluate: init `Flag = %False%`, then one plain single-condition `If … → Set Flag = %True%` per term, then the flag test. | ⚠️ |
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

These are places where the design originally assumed UiPath/VB-style behavior that PA Desktop does **not** support. Recorded so the same trap isn't reintroduced, and so the `rpa-design-reviewer` agent explicitly checks for each.

| # | Lesson | Where it bit us | Fix applied | Rule |
|---|---|---|---|---|
| L1 | **PA Desktop `If` is single-condition** — there is no "OR of N conditions" in one `If` action (unlike a UiPath `If` with a full boolean expression). | detailed-design.md Step 1.10b (config-empty check, OR of 5) and Step 3.10 (bad-headers check, OR of 2). | Precompute the OR into one Boolean via `Set variable` (rule 1.7), then `If %Flag% Equal to %True%`. Fatal body stays written once. | 4.4, 1.7 |

**Reviewer rule:** any step whose `If`/`Loop Condition` needs more than one operand-operator-operand triple is an L1 violation → flag it and require the precomputed-flag pattern. Scan every new phase for this.

> Other candidate traps to watch for as later phases are designed (not yet hit, but same family):
> - **AND-combined conditions** in one `If` — same limitation as OR; same flag-precompute fix.
> - **Compound conditions inside a `Loop Condition`** (7.1) — the loop condition is also single-triple; a multi-part loop guard needs the same precomputed Boolean.
> - **Inline `If`/ternary inside a value field** (e.g. `%IsX ? "a" : "b"%`) — PA Desktop has no ternary; use a preceding `If`/`Set` instead.

---

## Open items to verify in PA Desktop
- 1.7 confirm the exact in-`%%` logical-operator syntax (`OR`, `AND`, `NOT`, `=`, `""`) — load-bearing for the L1 flag-precompute pattern.
- 3.2 / 3.3 exact action names and output variable names.
- 4.1 exact "If file exists" block wording.
- 4.4 confirm `If` is single-condition (drives the L1 pattern) and the exact "is empty" operator name.
- 4.5 exact "Stop flow" / end-run action name.
- 5.1 confirm off-by-one on the retry operator with a real failing case.
- 7.1–7.4 loop/throw-error/datatable action names, exactly as PA Desktop labels them.
- Datatable column-membership expression `%PendingList.Columns.Contains("...")%` (Phase 3 Step 3.10) — not yet confirmed; fallback is reading the header row explicitly and comparing cells.
- 9.1 whether `Go to`/`Label` really are flow-scoped — this is load-bearing for the one-Main-flow architecture decision; confirm before build.

Add new rows here as they're discovered and tested.
