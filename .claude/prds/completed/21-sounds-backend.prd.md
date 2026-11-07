# [21]: Sounds backend

**Depends on:** [2] Foundation merged. Blocks [22]–[27].

This ticket adds the data side of the shared soundboard (spec [soundboard.md](../design/specs/soundboard.md) §11.2 risk 2, §12 technical-spec items 3–7). A sound is one row in a **new** `sounds` table plus one `.m4a` file in a **new** private `sounds` bucket. The pair's library is every row whose sender is you or your partner, and both partners can read, change, reorder and delete every sound. A stranger sees and changes nothing. New sounds go to the top of the shared order on their own, and one RPC rewrites the whole order at once, so two people dragging at the same moment can never leave duplicate positions. There's no app UI here; [22] reads this data and [23]/[24] write it.

## Summary
Adds one migration: the `sounds` table, its RLS, a `before insert` trigger for `position`, the `reorder_sounds` RPC, the `sounds` bucket and its policies, and `sounds` in the realtime publication. It also adds seed sounds (rows plus real `.m4a` files uploaded by a script, like `seed-notes.sh`) and pgTAP cases. Nothing existing changes.

## Scope
**MVP**
- **`sounds` table (new):** the columns in Data Model below, with check constraints.
- **RLS (S26):** select, update and delete when `sender_id = auth.uid() or is_paired_with(sender_id)`. Insert only with `sender_id = auth.uid()`. This is the one user table either partner may update and delete.
- **Position trigger:** `before insert` sets `position` to the pair's minimum minus 1 (or 0 when the pair has none), so a new sound lands first (S19) even when it comes from the offline outbox.
- **`reorder_sounds(ordered_ids uuid[])` (new RPC):** locks the caller's pair sound rows `for update`, checks the ids are exactly that set (else raises `sounds_mismatch`), and rewrites `position` 1…n in one transaction. The last commit wins.
- **Bucket `sounds` (new, private):** insert into your own folder `{auth.uid()}/…`; select and delete in your own or your partner's folder. The same folder check as the `notes` bucket policies.
- **Realtime:** add `sounds` to `supabase_realtime`. No push (S23).
- **Seed:** 6 sounds with fixed UUIDs `c0000000-0000-0000-0000-0000000000NN`, from both senders, 1 with no emoji, 1 trimmed. Files are in `supabase/seed-sounds/{sender_id}/{id}.m4a`, uploaded by `supabase/seed-sounds.sh`.

**Out of scope**
- Any app code: [22]–[27].
- Cleaning up orphan files (a row deleted, file removal failed). Add it if orphans show up.

---

## Decision Log
| # | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| S7 | Delete | Either partner, with a confirm | Shared board | User |
| S11 | Trim storage | Keep the original file; store `trim_start_ms` / `trim_end_ms` | Undoable, no re-encode or re-upload | User |
| S13 | Emoji | Optional; null shows 🔊 | One less step | User |
| S17–S20 | Order | Drag to reorder, one shared `position`, new sounds first | Shared board | User |
| S23 | Partner adds | Appears over realtime, no push | Quiet; no push backend yet | User |
| S26 | Access | One library per pair; both partners have full rights; stranger denied (`is_paired_with`) | Same pattern as `notes` | Claude — straightforward |
| S27 | Storage | Private bucket `sounds` at `{sender_id}/{id}.m4a`; `sounds` table | Same pattern as `notes` (`20261019102934_init.sql`) | Claude — straightforward |
| B1 | Position on insert | `before insert` trigger: pair minimum − 1 | An offline insert doesn't need to know the order (spec §11.2) | Claude — straightforward |
| B2 | Concurrent reorder | One `reorder_sounds` RPC with `for update` and a full renumber | No per-pair unique constraint is possible without a `pair_id`; the RPC carries the guarantee (spec §11.2) | Claude — straightforward |
| B3 | Deleting the file | **No `delete_sound` RPC** (replaces spec §12 tech 5). The app deletes the row under RLS, then removes the file with the Storage API under the bucket delete policy | Supabase Storage blocks deleting `storage.objects` rows from SQL, and a SQL delete would leave the file behind anyway | Claude — straightforward |
| B4 | Seed audio | `.m4a` files made on the Mac with `say` + `afconvert` (mono AAC), committed under `supabase/seed-sounds/` | Real files so [22] can play them; same flow as `seed-notes.sh` | Claude — straightforward |

## Data Model
### `sounds` table (new)
| Column | Type | Default | Description |
|---|---|---|---|
| `id` | uuid pk | — | Made on the phone (S28) |
| `sender_id` | uuid → `profiles` on delete cascade | — | Who recorded it |
| `title` | text | — | 1–30 characters after trimming whitespace |
| `emoji` | text null | null | One emoji; null shows 🔊 |
| `audio_path` | text | — | `{sender_id}/{id}.m4a` in `sounds` |
| `duration_ms` | int | — | 1–10000 |
| `trim_start_ms` | int | 0 | `0 ≤ trim_start_ms` |
| `trim_end_ms` | int | — | `≤ duration_ms`; `trim_end_ms − trim_start_ms ≥ 500`, or the full clip when it's under 0.5 s |
| `position` | int | set by trigger | Shared order; lower first |
| `created_at` | timestamptz | `now()` | |

**Index:** `(sender_id, position)`.
**Reset needed:** yes, `supabase db reset && supabase/seed-notes.sh && supabase/seed-sounds.sh`.

## End-to-End Flows
```
[23] insert (sender = me) ─► trigger: position = pair min − 1 ─► realtime ─► partner's grid
[24] reorder_sounds([c3, c1, c2…]) ─► lock pair rows ─► ids match? ─► position 1…n ─► realtime
two reorders at once ─► second waits on the lock ─► last commit wins ─► no duplicates
[24] delete row (partner's sound) ─► RLS allows ─► Storage remove {partner}/{id}.m4a ─► allowed
stranger select / update / delete / upload ─► nothing returned or changed
```

## Blast Radius
| Change | What breaks |
|---|---|
| New migration | Nothing existing. `supabase db push` puts it on hosted |
| Reset loop | CLAUDE.md gains `supabase/seed-sounds.sh` after every reset |

## File Reference
| File | Role |
|---|---|
| `supabase/migrations/{timestamp}_sounds.sql` | **new** table, RLS, trigger, RPC, bucket, policies, publication |
| `supabase/seed.sql` | seed sound rows |
| `supabase/seed-sounds/**` | **new** sample `.m4a` files |
| `supabase/seed-sounds.sh` | **new** upload script |
| `supabase/tests/database/sounds.test.sql` | **new** pgTAP |
| `CLAUDE.md` | seed-sounds step in the Backend table and "Testing well" |

---

## Acceptance Criteria
- [x] AC1: After the reset and both seed scripts, the 6 seed rows exist and each has its object in `sounds`.
- [x] AC2: pgTAP: Adam and Partner can each select, update and delete each other's sounds. Insert works only as yourself. `stranger@example.com` selects nothing and changes nothing.
- [x] AC3: pgTAP: inserting a sound gives it a lower `position` than every existing pair sound.
- [x] AC4: pgTAP: `reorder_sounds` with the pair's ids in a new order gives positions 1…n in that order. A missing, extra or foreign id raises `sounds_mismatch` and changes nothing. A stranger can't reorder.
- [x] AC5: Storage: uploading to your own folder works and to your partner's is denied. Your partner can read and delete your file. A stranger can do neither. Checked with pgTAP on `storage.objects` policies or a function test.
- [x] AC6: The check constraints reject an empty title, a 31-character title, a duration over 10000 and a trim under 0.5 s.
- [x] AC7: `sounds` is in `supabase_realtime`.
- [x] AC8: `supabase test db` and `supabase db lint` pass.

## Required Changes
- **technical-spec.md:** paste spec §12 technical-spec items 3, 4, 5 (only the `reorder_sounds` row, noting B3) and 6, plus the storage-rules and trim bullets of item 7.
- **CLAUDE.md:** the seed-sounds step.

## Features Catalog
- **Extends**: New feature, Sounds

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The trigger computes the pair minimum without seeing the partner's rows (RLS inside the trigger) | Med | New sounds don't land first | Make the trigger `security definer` with a fixed `search_path`, as the existing RPCs do |

---
*Status: COMPLETED — PR #26*
