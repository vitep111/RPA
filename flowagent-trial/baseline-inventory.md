# Pre-trial baseline — PTTEP (Default) environment

Captured 2026-08-18 before any write operation. Purpose: prove at the end of the trial that
no pre-existing flow was modified. The trial runs in Default by the user's explicit decision,
so this inventory is the safety net that the environment itself doesn't provide.

Env ID: `Default-c03b7ea5-365c-4a0f-b767-955babc64911`
Complete listing (10 flows, under the API's 50 cap — nothing truncated).

| Flow ID | Display name | State | Trigger | Actions | Last modified (UTC) |
|---|---|---|---|---|---|
| 17f722d5-81ed-4fd3-8cc5-9350ff6fb66c | 2026-08-18 Expense noti | Started | OpenApiConnection | 5 | 2026-08-18T07:26:56 |
| 6ed218e1-3ca4-477b-b17f-334eb6978041 | 2026-08-18 Email Customer Flow | Stopped | Recurrence | 4 | 2026-08-18T04:11:47 |
| 64ace1b5-ec99-4bb8-94ae-6ae60ddcd005 | Daily FX Rate Check | Started | Recurrence | 2 | 2026-08-03T03:32:43 |
| 782b3f91-9345-4364-9085-499488ed3935 | AR Email Classification | Started | OpenApiConnectionNotification | 13 | 2026-06-25T08:06:08 |
| 42ac716e-d635-419e-afe1-77f32869ddce | Tax Invoice | Started | OpenApiConnection | 4 | 2026-06-19T10:55:01 |
| af16c2d8-a354-410d-9109-72c121ed529f | Email Classification | Started | OpenApiConnectionNotification | 13 | 2026-06-11T08:23:44 |
| cfd8d99f-b636-4a6d-ab08-bd8af0099798 | Get Document No. Workflow | Started | Request (PowerAppV2) | 9 | 2026-04-21T09:29:13 |
| 84147e58-5924-4342-ad32-02231e0dd83b | Email Reminder Chat | Started | Recurrence | 9 | 2025-11-24T01:56:43 |
| 9a5a5362-cecd-40cb-84a3-31b70010d420 | RPA Upload Error | Started | Recurrence | 7 | 2025-09-09T04:44:27 |
| edf0862c-4e80-4354-a652-8b3324386dc6 | RPA Email Monitor | Started | Recurrence | 4 | 2025-03-03T03:56:10 |

8 of 10 are `Started`.

## Observed drift during baseline capture — not caused by the trial

`2026-08-18 Expense noti` changed between two read-only listings roughly 15 minutes apart:

| | First read (07:11) | Second read (07:26) |
|---|---|---|
| actionCount | 4 | 5 |
| lastModifiedTime | 07:11:14 | 07:26:56 |

No write call was issued by the trial in that window — both calls were `list_flows`. Something
outside this session edited that flow: the user in the maker portal, or another maker in the
tenant. Either way it confirms Default is an actively-edited, live environment.

Consequence for the trial: "nothing changed" cannot be asserted from timestamps alone, because
third-party edits are expected here. Verification must be **per-flow and scoped** — compare
only the flows this trial touched, and treat drift on untouched flows as background noise
rather than as a trial-caused regression.

## Guardrails adopted (given Default was chosen)

Isolation now comes from naming and discipline, not from the environment:

1. Every artifact the trial creates is prefixed **`ZZ-FLOWAGENT-TRIAL-`**. Sorts to the
   bottom of the maker list, unmistakable in an inventory, trivially greppable.
2. No write call — `create_flow`, `edit_flow`, `update_flow`, `publish_flow`, `delete_flow`,
   `disable_flow`, `run_flow`, `resubmit_run`, `cancel_run` — is ever issued against a flow ID
   in the table above. Writes target only trial-created flows.
3. `cancel_all_runs` is never used in this environment at all. It takes no per-flow scope worth
   trusting against 8 live flows.
4. T5 (deliberate fault injection) breaks only a trial-created flow. No existing flow is broken
   to test diagnosis.
5. Trial flows are created Stopped and stay Stopped except for the single controlled run in T4.
6. Cleanup at the end deletes only `ZZ-FLOWAGENT-TRIAL-` flows, listed for confirmation first.
