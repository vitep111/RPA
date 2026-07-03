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

## 5. Retry Loop Semantics

| # | Rule | Detail | Status |
|---|---|---|---|
| 5.1 | For exactly `MaxRetry` retries | Start `RetryCount = 0`; on error increment, then test `RetryCount <= MaxRetry` to retry. Using `<` gives `MaxRetry - 1` retries. | ⚠️ |

## 6. Sensitive Data

| # | Rule | Detail | Status |
|---|---|---|---|
| 6.1 | Secrets | Use the "Sensitive" data-type toggle so the value is hidden from the variables pane and logs. Never write a secret to the Excel log. | ⚠️ |

---

## Open items to verify in PA Desktop
- 3.2 / 3.3 exact action names and output variable names.
- 4.1 exact "If file exists" block wording.
- 5.1 confirm off-by-one on the retry operator with a real failing case.

Add new rows here as they're discovered and tested.
