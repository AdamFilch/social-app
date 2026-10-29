# [17]: Notes read path and seed data

**Depends on:** [16] Send a note merged, because both edit `NotesStore` and `NotesTab`. Blocks [18]–[20].

The Notes tab ([18]–[20], spec [notes-tab.md](../design/specs/notes-tab.md)) needs to read notes, not just send them. This ticket adds the read side to `NotesStore`:
- fetch the notes in a date range, without unsent ones;
- load a note's image through a short-lived signed URL, with an in-memory cache;
- know when the pair was made, which sets the earliest page the tab can swipe to;
- hear about new or unsent notes through the existing realtime publication.

It also makes the local data worth testing. The pair is backdated, notes from both people are spread over three weeks, and real images are put in the `notes` bucket. There's no Notes UI here: a DEBUG-only readout on the tab proves the read path, and [18] replaces it.

## Summary
- **`NotesStore`:** gains `notes(in:)`, `image(for:)` and `changes()`.
- **`SessionStore`:** gains `pairedAt`.
- **`seed.sql`:** backdates the pair and adds about 12 notes over three weeks, including one unsent note.
- **Seed images:** sample images go into `supabase/seed-notes/` and are uploaded to the bucket after `supabase db reset`.
- **Backend:** no schema change. The select policies on `notes`, `pairs` and the bucket already exist (`20261019102934_init.sql`).

## Scope
**MVP**
- **`NoteRecord`:** a `Sendable` struct with `id`, `senderId`, `imagePath` and `createdAt`, decoded from `notes`.
- **`NotesStore.notes(in: DateInterval) async throws -> [NoteRecord]`:**
  - selects `id, sender_id, image_path, created_at`;
  - filters `unsent_at is null` and `created_at` in `[start, end)`;
  - orders by `created_at desc`.
  - The tab calls it once per visible range: a week for the strip, or the month grid's span of up to 6 weeks (spec §5 `NotesTab`).
- **`NotesStore.image(for: NoteRecord) async -> UIImage?`:**
  - makes a signed URL from the `notes` bucket (60 s is enough) and downloads it;
  - caches the decoded image in an `NSCache` keyed by note id;
  - returns `nil` on failure, which [18] shows as the image-failed state.
- **`NotesStore.changes() -> AsyncStream<Void>`:**
  - yields on any insert or update on `notes` via the realtime channel;
  - the caller refetches the visible range when it yields;
  - it doesn't patch rows, so an unsent note simply drops out on refetch.
- **`SessionStore.pairedAt: Date?`:**
  - loaded in `refresh()` from the caller's `pairs` row, as its `created_at`;
  - `nil` when unpaired.
- **Seed, in `supabase/seed.sql`:**
  - the pair's `created_at` is set to `now() - interval '45 days'`, so the swipe range covers two months;
  - about 12 notes across the last 3 weeks, with fixed UUIDs `b0000000-…-0000000000NN`;
  - both senders are represented, including 3 or more notes today and at least one day with only Sam's notes;
  - one note has `unsent_at` set.
  - `created_at` is relative, e.g. `date_trunc('day', now()) - interval '3 days' + interval '9 hours 20 minutes'`, so the data stays recent after any reset.
- **Seed images:**
  - one small image per seed note (1000 × 1000, about 100 KB or less) at `supabase/seed-notes/{sender_id}/{note_id}.heic`, matching each row's `image_path`;
  - JPEG data with a `.heic` name is fine, since `UIImage` reads the content.
  - **Upload:** prefer the CLI's native bucket seeding (`[storage.buckets.notes] objects_path = "./seed-notes"` in `config.toml`) if `supabase db reset` uploads it. Otherwise use one script, `supabase/seed-notes.sh`, that runs `supabase storage cp` for each file.
  - Add the step to CLAUDE.md's Backend table and "Testing well" loop if it isn't automatic.
- **Temporary check:** a DEBUG-only `Text` on `NotesTab` reading "N notes this week · M images loaded". It's removed in [18].

**Out of scope**
- Any Notes UI, which belongs to [18]–[20]
- Thumbnails or a disk cache. `NSCache` is enough for now; add a disk cache when scrolling months feels slow.
- The widget's image path

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| P1 | Ticket split | 4 tickets: read path [17], week view [18], note dialog [19], month view [20] | Each one can be checked on its own | User |
| P2 | Seed images | Sample files in `supabase/seed-notes/`, uploaded after reset | Tiles, mini-cards and the dialog can't be checked without real images | User |
| P3 | Backdate the seed pair | `now() - 45 days` | With `now()` the swipe range is one week (spec §3.5) | Claude — straightforward |
| P4 | Realtime handling | `changes()` only signals; the caller refetches | One code path for inserts and unsends; spec §5 allows refetch-only | Claude — straightforward |
| P5 | Image loading | Signed URL plus `NSCache` | Bucket is private (`20261019102934_init.sql`); spec §4.3 | Claude — straightforward |
| P6 | Remote note type | New `NoteRecord`, separate from [15]'s SwiftData `Note` | The local `Note` is the outbox copy; remote rows aren't persisted | Claude — straightforward |

## End-to-End Flows
```
NotesTab appears ─► notes(in: this week) ─► [NoteRecord] newest first
tile visible ─► image(for:) ─► cache hit? return : signed URL → download → cache
partner sends ─► realtime insert ─► changes() yields ─► refetch range
partner unsends ─► realtime update ─► changes() yields ─► refetch, note gone
supabase db reset ─► seed rows ─► images uploaded ─► tab shows real notes
```

## Blast Radius
| Change | What breaks |
|---|---|
| More seed notes from Adam | `rls_rpc.test.sql:41` expects exactly 1 note from Adam ("AC5: partner reads notes"). Change it to check the fixed id `b0000000-…-0001` is readable, or update the count |
| Backdated `pairs.created_at` | Nothing reads it yet. Recheck that `rls_rpc` still passes |
| Bucket seeding in `config.toml` | `supabase start` / `db reset` upload time grows slightly |

## File Reference
| File | Role |
|---|---|
| `ButtercupKit/Sources/ButtercupKit/NotesStore.swift` | `NoteRecord`, `notes(in:)`, `image(for:)`, `changes()` |
| `ButtercupKit/Sources/ButtercupKit/SessionStore.swift` | `pairedAt` |
| `supabase/seed.sql` | backdated pair, ~12 notes |
| `supabase/seed-notes/**` | **new** sample images |
| `supabase/config.toml` or `supabase/seed-notes.sh` | image upload |
| `supabase/tests/database/rls_rpc.test.sql` | AC5 count fix |
| `Buttercup/ContentView.swift` | DEBUG readout |
| `CLAUDE.md` | seed-image step, if manual |

---

## Acceptance Criteria
- [ ] AC1: After `supabase db reset` (plus the upload step if manual), the notes in the database match the seed: three weeks across both senders, with one unsent. Every non-unsent row has its object in the bucket.
- [ ] AC2: `supabase test db` and `supabase db lint` pass.
- [ ] AC3: Signed in as `adam@example.com`, the DEBUG readout shows this week's count without the unsent note, and every image loads.
- [ ] AC4: Inserting a note for Sam with SQL while the app is open updates the DEBUG count within a few seconds, through realtime.
- [ ] AC5: `pairedAt` is about 45 days ago for Adam and nil for `stranger@example.com`. A DEBUG print or breakpoint is enough to check it.
- [ ] AC6: The build check passes.

## Required Changes
- **CLAUDE.md:** the seed-image step and the reset loop, if they're not automatic.
- **technical-spec:** add `notes(in:)` and the signed-URL image path to the Notes flow section.

## Features Catalog
- **Extends**: #2 Notes widget

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `objects_path` bucket seeding doesn't run on `db reset` for a migration-made bucket | Med | No images locally | Fall back to the `storage cp` script |
| Relative seed timestamps cross midnight in UTC vs the phone's zone | Low | A note lands on the next or previous day | Times are between 7 am and 9 pm; acceptable for test data |

---
*Status: READY — ticket [17]*
