# [15]: Outbox and note upload

**Depends on:** [2] Foundation merged. Independent of [9]–[14]; can be built in parallel.

This ticket builds the app's outbox (technical-spec §1) with its first action: sending a note. A note image and its id are saved on the phone first, and a background flusher then uploads the image to the `notes` Storage bucket and inserts the `notes` row. If the phone is offline, the flusher waits until `NWPathMonitor` reports a connection, then tries again. The note id is made on the phone, so a retry never creates a second note. There's no UI here; [16] connects the Send button to it.

## Summary
Adds an App Group to the app target, a SwiftData store inside it, an `OutboxAction` model, an `Outbox` flusher in `ButtercupKit`, and a `NotesStore.send(imageData:)` that writes a local `Note` plus its outbox entry. The backend already has the `notes` table, the insert policy and the bucket (migration `20261019102934_init.sql`), so there are no schema changes.

## Scope
**MVP**
- App Group `group.<bundle id>` on the app target. The SwiftData container and note images live there (technical-spec §1).
- `OutboxAction` (`id`, `kind`, `payload`, `createdAt`, `attempts`). Only the `sendNote(noteId, imagePath)` kind is used now.
- Flusher: runs on launch, after each enqueue, and when `NWPathMonitor` becomes satisfied. Processes actions in order and leaves failed ones for the next run.
- `sendNote`: upload `{sender_id}/{note_id}.heic` with `upsert: true`, then insert the `notes` row with the phone-made `id`. A unique violation (`23505`) counts as success. On success, delete the action and keep the local `Note`.
- `NotesStore.send(imageData:) -> NoteSendResult` (`.online` / `.offline` from `NWPathMonitor` at that moment)

**Out of scope**
- The other outbox actions (+1, favourite, unsend …): their own tickets
- Partner notification and widget push (`push-partner`): a later backend ticket
- Downloading notes, the Notes grid and widgets

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| N1 | Build the shared outbox now | A general `OutboxAction` with one kind | Adam chose the outbox for sending (spec D7–D8); technical-spec §1 makes it the path for every write | User |
| N2 | Idempotency | Phone-made uuid; Storage `upsert: true`; insert treats `23505` as done | A retry after a lost response must not duplicate | Claude — straightforward |
| N3 | Checking it | A DEBUG-only "Send test note" button on the Notes tab placeholder, removed in [16] | There is no Xcode test target yet | Claude — straightforward |

## End-to-End Flows
### Online
```
send(imageData) ─► save Note + OutboxAction ─► return .online
flusher ─► upload → insert row ─► delete action
```
### Offline, then back
```
send ─► saved ─► return .offline ─ flusher upload fails ─► action kept
NWPathMonitor satisfied ─► flusher ─► upload → insert ─► one row in notes
```
### Retry after a lost response
```
insert succeeded, app killed before the action was deleted ─► next launch ─► upload (upsert) ─► insert 23505 ─► treated as done
```

## Blast Radius
| Change | What breaks |
|---|---|
| App Group entitlement | Signing: Debug needs the group on the dev team (no paid account required for simulator) |
| SwiftData container at app launch | Launch path; a schema error would crash at start |

## File Reference
| File | Role |
|---|---|
| `Buttercup/Buttercup.entitlements` | **new** App Group |
| `ButtercupKit/Sources/ButtercupKit/Outbox.swift` | **new** model + flusher |
| `ButtercupKit/Sources/ButtercupKit/NotesStore.swift` | **new** `Note` model, `send` |
| `Buttercup/ButtercupApp.swift` | model container, inject `NotesStore` |

---

## Acceptance Criteria
- [ ] AC1: Simulator, `adam@example.com`, online: "Send test note" creates exactly one `notes` row with the phone-made id, and `{adam id}/{id}.heic` exists in the bucket (checked in Studio or SQL).
- [ ] AC2: With the local stack stopped (`supabase stop`): the send returns `.offline` and the action stays. After `supabase start`, the flusher sends it, giving exactly one row.
- [ ] AC3: Forcing a retry of an already-inserted note (run the action twice) leaves one row and no error.
- [ ] AC4: Signed in as `partner@example.com`, the row is readable. As `stranger@example.com` it isn't (existing RLS, recheck only).
- [ ] AC5: `supabase test db` still passes, and the build check passes.

## Required Changes
- **Outbox**: technical-spec §1 Outbox.
- **Notes flow**: technical-spec §Notes steps 1–2.

## Features Catalog
- **Extends**: #2 Notes widget
- **Closes known gaps**: SwiftData cache and outbox deferred in [2] (D30)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `NWPathMonitor` says online but the server is unreachable | Med | Toast says "Sent" while it's queued | Acceptable: the flusher still delivers. The toast text reflects the network path only (spec §3.8) |

---
*Status: READY — ticket [15]*
