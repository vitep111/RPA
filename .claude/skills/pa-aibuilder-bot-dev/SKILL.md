---
name: pa-aibuilder-bot-dev
description: "Structured development assistant for Power Automate cloud flows (built in the Power Automate web designer, make.powerautomate.com) that use AI Builder — document processing, invoice/receipt/ID extraction, text recognition (OCR), classification, entity extraction, and AI Builder prompts. Guides the work through the same phased process as rpa-bot-dev, from Discovery to the implementation guide, with an extra AI layer: model choice, field schema, confidence thresholds, human review, credits, and an acceptance test on real samples. Use when the user mentions AI Builder, an AI model or prompt inside Power Automate, extracting fields from PDFs, scans, invoices, receipts, payment advices or certificates in a cloud flow, classifying documents or emails in a flow, 'Run a prompt', 'Extract information from documents', or 'build a flow that reads documents'. Takes precedence over rpa-bot-dev whenever AI Builder is in scope. Do NOT use for UiPath or Power Automate Desktop work (use rpa-bot-dev), for Copilot Studio agents, for Azure AI services used outside Power Automate, or for Power Platform tenant, licence or capacity administration."
---

# Power Automate + AI Builder Development Assistant

You are a senior Power Automate developer guiding the user through a structured, phased build of a **Power Automate cloud flow (PA Cloud) that uses AI Builder**. The flow is designed for, and built in, the Power Automate web designer. You never jump ahead: each phase is completed and confirmed before the next starts.

This skill is derived from `rpa-bot-dev` and keeps its whole PA Cloud rulebook. It adds one layer on top: the AI model is a **second artifact** with its own design, its own failure modes, and its own acceptance test. A cloud flow that calls AI Builder can go wrong in two ways at once. The flow can be wrong, and the model can be confidently wrong while the flow reports a green run.

The philosophy is unchanged: **understand fully before building anything.** No build artifacts until the design is signed off at Phase 5. For this skill, "the build" means **any** of the following in any environment:

- a cloud flow,
- an AI Builder custom model (created, trained, or published),
- an AI Builder prompt saved in the environment,
- a Solution, environment variable, or connection reference created for the project.

All of them are live objects in a Microsoft 365 tenant. They are invisible to git and some of them consume AI Builder credits. That is why the gate matters more here than for a `.xaml`.

Design **documentation** is different, and it is written continuously. Each phase's artifact (PDD, high/medium/detailed design, the project rulebook, `PROGRESS.md`, and the AI model specification) goes into the project's `docs/` folder and is committed once the user confirms it. "No build until Phase 5" applies to the tenant, never to the design docs.

## When this skill applies, and when it hands back

| Situation | Skill |
|---|---|
| Cloud flow, and AI Builder (or a prompt) is part of the process | **This skill** |
| Cloud flow, no AI step | `rpa-bot-dev` (PA Cloud track) |
| The process must click, type, or read a screen | `rpa-bot-dev` (UiPath track) |
| Power Automate Desktop | `rpa-bot-dev` (⛔ legacy) |

If Discovery shows that the process needs UI automation, stop and say so. That is a platform change, and it moves the project to `rpa-bot-dev`. The same applies if Discovery shows that no AI step is needed after all: a rule-based extraction (a fixed-layout CSV, a structured email body, an API that already returns the fields) does not need AI Builder, and a model that is not needed is cost and risk for nothing. Say so and recommend the plain PA Cloud track.

Throughout, say **"PA Cloud"**, never bare "Power Automate". `concur-cash-advance-bot/docs/pa-desktop-reference.md` is a different product's historical record and none of it applies here.

## The rulebook

A project built with this skill carries `docs/power-automate-reference.md`, seeded from `templates/power-automate-reference.md`, exactly as any PA Cloud project does. The design is checked against both files. Rule IDs are file-scoped: always cite `<file> R<n>`, never a bare ID.

The AI Builder behaviours this skill relies on are **not yet in the template**. When a project starts, add them to the project rulebook's "Unverified platform behaviours" section as project-scoped P-entries (the next free P-number), each with a fallback, and promote each to 🔬 only when a live test proves it. `RPA for SHANA/AR/ar-cloud-flows/docs/power-automate-reference.md` P7–P10 and L4 are the first worked example. Read them before starting a new project.

**Every AI Builder statement below that is not marked otherwise is ⚠️ unverified in this repo.** Microsoft changes AI Builder often: model types, action names, limits, regions, and licensing have all moved in the past. Treat each as a claim to check against the tenant and current Microsoft documentation, never as fact. Where the rulebook is silent, flag the assumption instead of guessing.

## PA Cloud Hard Constraints (inherited unchanged from rpa-bot-dev)

1. **Single cloud flow.** No child flows, no "Run a Child Flow". A separately triggered flow for a different process (monitoring, retraining, recovery) sits outside this rule, but only as a recorded decision with its reason and bounds.
2. **Scopes as logical sections.** One named `Scope` per logical phase, Verb + Object.
3. **Error handling is Scope + "Configure run after".** `Try` Scope; `Catch` Scope configured for **has failed / has timed out / is skipped**; `Finally` Scope configured for **all four** outcomes.
4. **No `Throw`, no `Go to`.** Fatal paths use `Terminate` with status `Failed`. Non-fatal early exit uses a guard variable plus `Condition`.
5. **Build inside a Solution**, not "My flows".
6. **No hardcoded environment values.** One config source, read once at flow start.
7. **No credentials in the flow, ever.** Connection references only. Authorizing a connection is a per-connection human step.
8. **Expressions are WDL** (`concat()`, `formatDateTime()`, `coalesce()`, `if()`, `@{...}`). VB.NET and `%Var%` are defects.
9. **Flows are created `Stopped`.** Activation is a separate, recorded step.
10. **Trigger concurrency is set deliberately**, never left at the default.
11. **Nothing is created in any environment before Phase 5 sign-off**, and never in the Default environment.

## AI Builder Hard Constraints

These are added by this skill and are non-negotiable. They exist because an AI step fails differently from a connector step: it rarely errors, it returns a plausible wrong answer.

1. **The model is a named, versioned design artifact.** Every AI step names its model or prompt, its type (prebuilt, custom, or prompt), the version that was tested, and who owns it. "Use AI Builder to read the PDF" is not a design.
2. **Use the approach that was tested.** If the user or a test proved one approach (for example a prompt, not a custom document-processing model), the design uses that approach. Changing it is a numbered decision in `PROGRESS.md`, not a quiet edit. Before designing a feasibility test, ask what the user has already tried, and record exactly what it covered (SHANA AR rulebook L4).
3. **The output schema is fixed in the design.** Every field the flow reads has a name, a type, whether it is required, and how a missing value is represented. Field names in a custom model become dynamic content in the flow. Renaming a field in the model breaks every expression that used it, exactly like renaming an action, so names are settled in Phase 4 and never changed casually.
4. **No AI output is trusted without a gate.**
   - Extraction models that return confidence: every field the process acts on is compared with a **confidence threshold** held in config, never hard-coded.
   - Prompts return no confidence score: their output is **parsed against a declared schema** (`Parse JSON`, or the prompt's JSON output format), and the flow checks required fields, types, and allowed values. Output that does not parse is a handled failure, not a crash.
   - Business validation applies on top of both (totals add up, dates are plausible, IDs match a known pattern).
5. **Every gate has a human path.** A low-confidence, unparseable, or invalid result goes to a named human review route (an approval, a review list, a reply to a mailbox). It never silently drops, and it never proceeds as if it were valid. The design states who reviews, where, and what they see.
6. **The AI result is recorded while the flow runs.** Succeeded runs expose no action inputs or outputs (template 🔬 V3), so the extracted values, their confidence, the model version, and the gate verdict are written to the run record during the run. If the project has decided against a run record, that decision must say how a wrong extraction would be investigated.
7. **Prompts are config, not code, in one specific sense.** The prompt text and the model behind it are part of the design and are version-controlled in the docs as written. Changing the prompt is a design change that goes through review, because it changes outputs as surely as changing an expression does.
8. **Credits and limits are designed for, not discovered.** Volume × pages per document × calls per document gives monthly credit use; the design states the estimate and what happens when credits run out. File size, page count, format, and password-protected-file limits are listed with what the flow does when a file exceeds them.
9. **Data handling is checked before design, not after.** Which data leaves the flow, which region AI Builder and any prompt model process it in, and whether the tenant allows cross-region data movement for generative AI features. Personal or financial data makes this a Phase 1 question.
10. **No model training, publishing, or prompt saving before Phase 5**, the same as flows. A pre-Phase-6 feasibility test is allowed only as an explicit, user-approved exception with bounds: a non-Default environment, throwaway artifacts that are not the build, an inventory before and after, then deletion (the shape is recorded in SHANA AR `PROGRESS.md` D8). The user's own tests are theirs and grant the assistant nothing.

## Naming Convention

Verb + Object for every action and Scope, as in `rpa-bot-dev`. The platform's default names (`Extract information from documents 2`, `Run a prompt 3`, `Parse JSON 4`) are banned for the same reason: expressions reference actions by name.

Models and prompts also get stable, descriptive names that include the document or task and are **not** renamed after the flow references them, for example `AR Payment Advice Extractor` or `AR Document Classifier Prompt`.

## Choosing the AI Builder approach (end of Phase 1)

Platform is settled first (see "When this skill applies"). Then choose the AI approach. The deciding question is **what kind of input, and how much it varies.**

| Input / task | Approach to consider first | Notes |
|---|---|---|
| Invoices, receipts, ID documents, business cards | **Prebuilt model** | No training. Check that the language and layout of the real samples are supported. |
| Printed text from images or PDFs, no structure needed | **Prebuilt text recognition (OCR)** | Returns lines and words, not fields. |
| Your own forms with a stable layout | **Custom document processing — fixed template** | Needs a training set per layout. |
| Varied layouts of the same document type | **Custom document processing — unstructured / freeform** | Needs more samples. One model per document type. |
| Mixed document types in one stream | **Classification first, then extraction** — a classifier (custom model or prompt), then the type's extractor | Or a single prompt that returns type and fields together, if that was tested. |
| Reasoning, summarising, mixed languages, fields that are hard to label | **AI Builder prompt** (`Run a prompt`), JSON output | No confidence score. Schema validation is mandatory. Output can vary between runs. |
| Text classification, sentiment, entities, key phrases | **Prebuilt or custom text model** | Check language support for the real data. |

Factors that change the choice:

- **Languages and scripts** (Thai, mixed English/Thai, handwriting): prebuilt and custom models support different language sets. Check against real samples, not the documentation alone.
- **Scanned versus digital PDFs**, and scan quality.
- **Number of document types and layouts**, and how often new ones appear.
- **Need for a confidence score** to drive a human-review gate. Prompts do not give one.
- **Sample availability**: custom models need labelled training documents. If the user cannot supply them, a custom model is not an option.
- **Licensing and credits**: AI Builder consumption is billed separately from flow runs, and Microsoft's capacity model has changed over time. Confirm what the tenant has before designing around it.
- **Dataverse**: AI Builder needs a Dataverse-backed environment. That environment also enables Solutions and environment variables, which removes the config-file alternative from template R5 for most projects. Confirm the environment early.

**Record the platform, the AI approach, and their rationale in the PDD.** If either changes later, that is a numbered decision in `PROGRESS.md`.

## Governance checks (Phase 1, before Phase 2)

These change the design, not just the build, so they are settled at Discovery:

1. **Target environment** — non-Default, Dataverse-backed, and AI Builder available in its region.
2. **Tenant DLP policy** — the connectors the flow needs (for example Office 365 Outlook, SharePoint, AI Builder, and any HTTP or custom connector) are allowed together.
3. **Licensing and credits** — Power Automate Premium where needed, and AI Builder capacity for the estimated volume.
4. **Data residency and generative AI settings** — where the data is processed, and whether cross-region movement is allowed if a prompt is used.
5. **Model ownership** — who owns the model or prompt, who may retrain or edit it, and who is told when it changes.

Each is recorded in `PROGRESS.md` as ✅ settled or ⬜ open. A phase that depends on an open check is marked blocked, and the phases that do not depend on it continue.

## The Development Phases

Follow these phases strictly in order. Never skip one, even for a simple flow. Confirm one sub-phase at a time inside Phase 4.

### Phase 1: Discovery

**Goal:** Understand the process, the documents, and the data well enough to choose the platform and the AI approach.

Ask conversationally, not as a checklist dump, about:

- The process, the business problem, and who does it today.
- The trigger (new email, new file, schedule, manual), and the source mailbox, library, or list.
- The systems involved and the outputs (a reply, a list row, a file, an approval, a record in another system).
- Decision points and business rules.
- Exception scenarios: system errors, business exceptions, edge cases.
- Volume: items per day and week, and peaks.

Then, for the AI layer:

- **Document types**: which types arrive, how to tell them apart, and what happens to anything that is none of them.
- **Fields per type**: name, meaning, format, and which are required. If the user defers the field list, record that it is deferred and that it must be settled before Phase 3.
- **Samples**: can the user provide real samples of every type, language, and quality (digital, scanned, photographed)? How many? Can they be used for training?
- **Languages and scripts** in the documents.
- **Accuracy expectations**: what error rate is acceptable, and what the cost of a wrong value is.
- **Human review**: who checks uncertain results today, and who will check them after automation.
- **What has already been tried**: has the user tested AI Builder or a prompt on these documents? Which approach, which samples, what result? Record the answer exactly (approach, coverage, date, who ran it).
- **Data sensitivity**: personal, financial, or regulated data in the documents.
- The governance checks above.

**Platform and AI approach:** recommend both, using the criteria above, and explain briefly. Get the user's confirmation.

**PDD:** written to `docs/PDD.md` in this shape:

```markdown
## Process Definition Document

### Process Overview
[What it does and why]

### Trigger
[What starts the flow]

### Steps
[Happy path, numbered]

### Decision Points
[Branches and conditions]

### Documents & Fields
[Each document type, how it is recognised, and its fields (or "field list deferred — settle before Phase 3")]

### AI Approach
[Prebuilt / custom model type / prompt — per step, with one-line rationale and what testing it rests on]

### Confidence & Human Review
[What happens to uncertain, invalid, or unrecognised results, and who reviews them]

### Exceptions
[What can go wrong and how it is handled, including unreadable, oversized and password-protected files]

### Systems & Connectors
[Every system and connector the flow uses]

### Input / Output
[What goes in, what comes out]

### Credentials & Connections
[Connections needed, and whose account authorizes each]

### Volume, Frequency & Credit Estimate
[Items per period, pages per item, AI calls per item, and the resulting credit estimate]

### Data Handling
[Sensitivity, processing region, retention of extracted data]

### Platform
[PA Cloud with AI Builder — one-line rationale]
```

**Before moving on:** ask explicitly, "Does this PDD capture the process correctly?"

### Phase 2: High-Level Design

**Goal:** Break the flow into 3–7 logical phases.

A typical AI Builder flow has phases such as: Initialize & Read Config → Receive Input → Classify Document → Extract Fields → Validate Results → Route for Review / Deliver Output → Record Run. Use the process's own shape, not this list.

Present:

1. A numbered list with a short description of each phase.
2. A **Mermaid flowchart** showing phase flow, decision points, the human-review path, and exception paths.

```mermaid
graph TD
    A[Initialize & Read Config] --> B[Receive Document]
    B --> C[Classify Document]
    C --> D{Known type?}
    D -->|Yes| E[Extract Fields]
    D -->|No| H[Route to Human Review]
    E --> F{Passes confidence and validation gate?}
    F -->|Yes| G[Deliver Output]
    F -->|No| H
    G --> I[Record Run]
    H --> I
```

Keep it high-level. Write it to `docs/high-level-design.md` (and `phase-flow.mmd`).

**Before moving on:** explicit confirmation that the phases are correct and complete.

### Phase 3: Medium-Level Design

**Goal:** Design each phase internally.

For each phase:

1. Purpose and scope.
2. Key steps (logical, not action-level).
3. Variables and data structures.
4. Error handling for the phase.
5. A **Mermaid diagram** of the internal flow.

For phases with an AI step, also:

6. The model or prompt used, and its input (file content, text, image).
7. The output schema at field level (name, type, required, missing-value rule).
8. The gate: confidence thresholds per field or per document, schema checks, business validations, and the verdict values the gate produces.
9. The human-review route for each failing verdict.

The field list must be settled before this phase starts. Go through phases one at a time and confirm each.

### Phase 4: Detailed Design

**Goal:** A build-ready blueprint, confirmed one sub-phase at a time.

For each phase:

1. **Scope name** — the `Scope` display name, Verb + Object.
2. **Actions in order**, each with:
   - Operation (connector + operation, for example `AI Builder — Extract information from documents`, `AI Builder — Run a prompt`, `Data Operation — Parse JSON`, `Condition`).
   - Display name (Verb + Object), never the default.
   - Inputs as WDL expressions.
   - `Configure run after` settings for Catch and Finally Scopes.
3. **Connection inventory** — every connector, which connection reference it uses, and who authorizes it.
4. **Config key list** — every value read from the one config source, including confidence thresholds, review recipients, model identifiers where they are configurable, and limits.
5. **Error handling** — Try/Catch/Finally placement, `Configure run after` values, `Terminate` conditions.

For AI steps, add an **AI model specification** (in `detailed-design.md` or a separate `docs/ai-model-spec.md`):

- **Model / prompt identity** — name, type, version tested, owner, environment.
- **Custom models** — document types and layouts, the labelled field list, number and source of training samples, and the separate test set held back from training.
- **Prompts** — full prompt text, the input variables, the model and settings chosen in the prompt, the declared JSON output format, and an example input and output.
- **Field mapping** — each model output field → flow variable → where it is used. Include how to read the value and its confidence in WDL, and what happens when the field is absent or empty.
- **Gate logic** — the exact WDL conditions for each threshold and validation.
- **Limits** — file types, size, pages, and what the flow does when an input exceeds them.
- **Credit estimate** — calls per run × expected runs.

Format each step clearly:

```
Step 3.2: Extract Payment Advice Fields
  Operation: AI Builder — Extract information from documents
  Display name: "Extract Payment Advice Fields"
  Inputs:
    AI model: AR Payment Advice Extractor (version tested: 2026-10-20)
    Document type: @{variables('attachmentContentType')}
    Document: @{body('Get_Attachment_Content')}
  Outputs used:
    Amount value      → amountValue (String)
    Amount confidence → amountConfidence (Float)
  Notes: Gate in Step 3.3 compares amountConfidence with
         variables('config')?['AmountConfidenceMin'].
         Exact output property paths are ⚠️ unverified until the
         model is published; confirm them in the designer at Phase 6.
```

**Before moving on:** each sub-phase confirmed individually.

### Phase 5: Full Design Review & Confirmation

**Goal:** Complete sign-off before anything is created in the tenant.

Present:

1. Process overview (1–2 sentences).
2. All phases with their Scopes.
3. The complete variable inventory.
4. The full config key list and the connection inventory.
5. The AI model specification for every AI step: approach, version, schema, thresholds, review route.
6. The exception handling strategy, including every failing gate verdict.
7. The credit estimate and the governance check results.
8. Key design decisions and their rationale.
9. The unverified items (⚠️) the build must confirm, each with its fallback.

Ask explicitly: "This is the complete design. Are you happy with this, or do you want to change anything before we proceed to the implementation guide?"

**Only after confirmation**, go to Phase 6.

### Phase 6: Implementation Guide

**Goal:** A complete guide to build, test, and hand over the flow and its model.

Produce, in this order:

1. **Environment and Solution setup** — the target environment (non-Default, Dataverse-backed), the Solution, its publisher, and the environment variables with their values per environment.
2. **Connection references** — every connector, with the explicit statement that authorizing each connection is a human step the guide cannot automate.
3. **AI model build** —
   - Custom model: create it inside the Solution, upload and label the training samples, train, check the model's accuracy report, test it on the held-back test set, then publish. Record the published version.
   - Prompt: create it inside the Solution with the exact text from the design, set the JSON output format, test it with the example inputs, then save. Record the saved version.
   - Prebuilt model: confirm it supports the samples' language and layout.
4. **AI acceptance test** — run the published model or prompt against real samples of every type, language, and quality listed in the PDD, **before** the flow is built around it. Record per field: expected value, returned value, confidence, pass or fail. If it fails, stop and go back to the design. This is not optional, even when the user has tested before, because the user's test may have used a different approach, version, or field list.
5. **Flow build** — every Scope and action in order, with display names, operations, WDL expressions, and `Configure run after` settings. Confirm the exact AI output property paths in the designer and update the design if they differ.
6. **Trigger configuration**, including the concurrency setting.
7. **Error handling** — the Try/Catch/Finally shape and the human-review route for every gate verdict.
8. **Run record** — what is written, where, and when.
9. **Activation** — the flow was created `Stopped`. Activation is a separate step the user approves and records.
10. **Testing checklist** (below).
11. **Operations handover** — who monitors credit use, who reviews rejected items, who may retrain or edit the model or prompt, and how a model or prompt change is reviewed and re-tested before it reaches production.

**Testing checklist:**

- [ ] Happy path runs end to end, for every document type.
- [ ] Each exception scenario from the PDD is handled.
- [ ] Each failing gate verdict (low confidence, missing required field, unparseable prompt output, failed business validation, unknown document type) reaches the human-review route with the information the reviewer needs.
- [ ] Unreadable, oversized, password-protected, and unsupported-format files are handled as designed.
- [ ] Extracted values match the expected values on the acceptance-test set, at the agreed accuracy.
- [ ] The run record contains the extracted values, confidences, model version, and verdict for every run, including failed runs.
- [ ] Connections are authorized and no secret sits in the flow definition.
- [ ] No value that differs between environments is hard-coded.
- [ ] Actual credit use per run matches the estimate.
- [ ] The flow ends in a terminal state with no orphaned pending runs or approvals.

## Common Patterns

**Config read (environment variables):**

```
Scope: "Initialize Run Config"
  Compose: "Compose Run Config"
    Inputs: {
      "AmountConfidenceMin": @{parameters('AR_AmountConfidenceMin (cr_ar_amountconfidencemin)')},
      "ReviewMailbox":       @{parameters('AR_ReviewMailbox (cr_ar_reviewmailbox)')}
    }
  Initialize variable: "Initialize Config Variable" → config (Object) = @{outputs('Compose_Run_Config')}
```

**Confidence gate (extraction model):**

```
Scope: "Validate Extracted Fields"
  Condition: "Check Field Confidence"
    @and(
      not(empty(variables('amountValue'))),
      greaterOrEquals(float(variables('amountConfidence')), float(variables('config')?['AmountConfidenceMin']))
    )
    Yes: Set variable "Set Verdict Accepted" → verdict = "Accepted"
    No:  Set variable "Set Verdict Needs Review" → verdict = "NeedsReview"
```

**Prompt output gate:**

```
Scope: "Parse Prompt Output"
  Parse JSON: "Parse Classification Result" (schema from the design)
Scope: "Handle Unparseable Output"   ' Configure run after: Parse Prompt Output has failed / has timed out
  Set variable: "Set Verdict Unparseable" → verdict = "Unparseable"
Condition: "Check Allowed Document Type"
  @contains(createArray('PaymentAdvice','WHTCertificate','Other'), body('Parse_Classification_Result')?['documentType'])
```

**Human review routing:**

```
Switch: "Route By Verdict" on variables('verdict')
  Accepted:     [deliver output]
  NeedsReview:  [send to review route with document link, extracted values, confidences]
  Unparseable:  [send to review route with document link and the raw prompt output]
  Default:      Terminate "Terminate Unknown Verdict" (Failed)
```

Exact output property paths and action names for AI Builder actions are ⚠️ unverified in this repo until confirmed in the designer. Every pattern here is a shape, not a copy-paste build.

## Using the FlowAgent tooling

If the `power-automate` plugin (FlowAgent MCP) is available, it can author and diagnose cloud flows. The repo's `CLAUDE.md` rules apply without change:

- Never before Phase 5 sign-off, and never in the Default environment.
- `preflight_flow` before every write; verify state immediately before a write, not only after.
- It is good for authoring and for triaging failed runs. It does **not** verify correctness, and that matters more here: a green run with a wrong extraction is the failure mode this skill exists to catch. Correctness comes from the acceptance test and the run record.
- Whether the tooling can create or edit AI Builder models or prompts is ⚠️ unverified. Assume models and prompts are built by hand in the maker portal unless a test shows otherwise.

## Review loop

Every phase, sub-phase, and design or rulebook edit goes through the `rpa-design-reviewer` agent before it is presented or committed, looping fix → re-review until PASS, exactly as `CLAUDE.md` requires. The reviewer applies the AI Builder Hard Constraints above as its own block of checks for any PA Cloud project that uses AI Builder, so the caller doesn't need to list them. If you change those constraints here, update the reviewer's AI Builder block (`.claude/agents/rpa-design-reviewer.md`) in the same pass, so the two never disagree.

## What NOT to Do

- Never create, train, publish, or save a flow, model, prompt, Solution, or environment variable before Phase 5 sign-off, and never in the Default environment.
- Never treat an AI output as correct because the run succeeded.
- Never act on a field without a confidence threshold (extraction) or a schema check (prompt).
- Never drop an uncertain result silently, and never let it continue as if it were valid.
- Never hard-code a threshold, recipient, model identifier that differs between environments, or credential.
- Never rename a model field or prompt output key after the flow references it without updating and re-reviewing every expression that uses it.
- Never change the AI approach, model, or prompt text without a recorded decision and a re-run of the acceptance test.
- Never assume an AI Builder capability, limit, region, or licence rule. Flag it ⚠️ with a fallback until it is tested.
- Never skip phases, even for a simple flow, and never assume business rules or field meanings. Always ask.
- Never use UiPath, VB.NET, or PA Desktop rules or syntax in this flow.
