# [1]: Supabase backend foundation

This ticket sets up the whole buttercup database on Supabase, both locally and on the hosted project `nxqcwchrigseounzkvvz`. It covers every table in [technical-spec §2](../context/technical-spec.md#2-database), the row-level security that lets each person read only their own rows and their partner's, the six Postgres functions that bundle multi-row actions, the private `notes` Storage bucket and the Realtime publication. Nothing in the iOS app changes. Ticket [3] connects `ButtercupKit` to the contract at the end of this document.

A user signs in with Apple, and a trigger gives them an empty profile. One partner creates a `pair_invites` row and shares the code; the other calls `accept_invite`, which creates the `pairs` row. From then on, every user table can be read by both people in the pair and written only by its owner. Calls and catalog entries can only be written by Edge Functions (a later ticket). Everything is checked by pgTAP tests against a fresh `supabase db reset`.

## Summary
This adds a `supabase/` folder (config, one initial migration, seed data and one pgTAP test file) and pushes the migration to the hosted project. It covers the schema, RLS, RPCs, storage policies and the realtime publication. Edge Functions, `pg_cron`, Sign in with Apple provider setup and the iOS client are out of scope.

## Users
- **Primary**: Adam, as the developer, who needs a working, tested backend before any feature can sync, and ticket [3], which builds the Swift client on this contract.
- **Not for**: end users directly; no screen changes.

## Scope
**MVP**
- `supabase init` config, plus one migration containing the `hobby_kind` enum, 12 tables, constraints, indexes, the `is_paired_with` helper, RLS policies, the profile trigger and the 6 RPCs
- Private `notes` bucket with folder-based storage policies
- `supabase_realtime` publication on `notes`, `items`, `checkins`, `calls`
- `seed.sql` and pgTAP tests
- Hosted project linked and migration pushed

**Out of scope**
- Edge Functions `start-call`, `answer-call`, `end-call`, `catalog-search`, `push-partner`: need LiveKit, APNs, TMDB and IGDB secrets (ticket [2])
- `pg_cron` ring timeout and the database webhooks that trigger `push-partner`: belong with the functions they call (ticket [2])
- Sign in with Apple provider config: needs the Apple Services ID and key (ticket [3])
- Swift client, outbox and SwiftData: ticket [3]

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Data Model](#data-model)
4. [Access rules](#access-rules)
5. [Writers](#writers)
6. [Readers](#readers)
7. [Contract for frontend](#contract-for-frontend)
8. [End-to-End Flows](#end-to-end-flows)
9. [Blast Radius](#blast-radius)
10. [File Reference](#file-reference)
11. [Acceptance Criteria](#acceptance-criteria)
12. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D0 | First ticket scope | Full schema, RLS, RPCs, storage, realtime; Edge Functions later | Schema is fully specified; functions need third-party keys | User |
| D0b | Hosted project | Created by the user in the dashboard: `nxqcwchrigseounzkvvz` | Already exists | User |
| D1 | Unsend image deletion | `unsend_note` sets `unsent_at` and deletes the favourites; the sender's app deletes `{sender}/{id}.heic` through the Storage API, retried by the outbox | Supabase blocks SQL deletes on `storage.objects` | User |
| D2 | Profile creation | `auth.users` after-insert trigger creates the `profiles` row | The profile always exists; no half-created users | User |
| D3 | Invite TTL | `expires_at` defaults to `now() + interval '24 hours'` | Short enough to be safe, long enough to pair later that day | User |
| D4 | TV +1 past the final episode | No change, and no log row is written; the user taps Finish | No surprise state changes | User |
| D5 | `devices` / `widget_push_tokens` RLS | Only the owner can read them, an exception to the partner-read rule | Push tokens are credentials; `push-partner` uses the service role | Claude — security |
| D6 | Nullability | `display_name` default `''`, `time_zone` default `'UTC'`, `avatar_tint` nullable until pairing | The trigger can't know these values; the app sets them on first launch | Claude — straightforward |
| D7 | Seed | Two paired users (Adam, Partner) + one unpaired stranger; one book (12 chapters), one show (2 seasons × 3 episodes), one game; a few notes, items, logs and check-ins | Tests need a stranger; the data covers all three hobbies | Claude — straightforward |
| D8 | RPC idempotency | `log_increment` / `set_progress` return the item unchanged if `log_id` already exists; `check_in` upserts; `finish_item` / `unsend_note` are no-ops when already applied | Outbox retries must not double-apply (T12) | Claude — straightforward |
| D9 | One migration file | All of the above goes in `<ts>_init.sql` | Nothing has been pushed yet; split once there's a reason | Claude — straightforward |
| D10 | Text enums | `calls.kind`, `calls.status`, `items.status`, `catalog_entries.source`, `widget_push_tokens.widget_kind`, `devices.apns_env` stay `text` with `check` constraints | Matches the spec; only `hobby_kind` is a Postgres enum | Claude — straightforward |

## Overview
`profiles` is 1:1 with `auth.users`. `pairs` links two profiles (stored ordered as `user_a < user_b`). All feature data (`notes`, `items`, `logs`, `checkins`, `favourites`, `calls`) points to profiles, and `is_paired_with(other)` is the single check RLS uses to let a partner read it. `catalog_entries` is shared reference data that any signed-in user can read.

Questions the data answers:
1. **Who is my partner?** → the `pairs` row containing `auth.uid()`
2. **What has my partner sent me?** → `notes where sender_id = partner and unsent_at is null`
3. **Where is each of us in a book or show?** → `items` (`status = 'current'`), ordered by `last_logged_at desc`
4. **Did we each do a hobby today?** → `checkins where day = <today in the phone's time zone>`
5. **Call history** → `calls` by `caller_id` / `callee_id`, `created_at desc`

Non-obvious design decisions:
1. **`is_paired_with` is `security definer`.** RLS on `pairs` would otherwise be evaluated inside every policy, and policies that query RLS-protected tables recurse. Making it `stable` and pinning `search_path = ''` keeps it fast and safe.
2. **Multi-row actions go through RPCs and stay idempotent on phone-made ids ([D8](#decision-log)).** The outbox may send the same action twice, and it must land once.
3. **Storage paths start with the sender's uuid.** That lets one policy, based on `storage.foldername(name)[1]`, express "the sender writes, the sender and their partner read".

## Data Model
> Source: `supabase/migrations/<ts>_init.sql` (**new**). Every table is **new**. Columns, types and FKs are exactly as in [technical-spec §2](../context/technical-spec.md#2-database); only additions or clarifications are listed here.

| Table | Additions / clarifications |
|---|---|
| `profiles` | `id` FK → `auth.users(id) on delete cascade`; `display_name text not null default ''`; `time_zone text not null default 'UTC'`; `avatar_tint text null` |
| `pairs` | `check (user_a < user_b)`, `unique (user_a, user_b)`; each user is in at most one pair: `unique (user_a)`, `unique (user_b)`, plus a check in `accept_invite` that the user isn't already the other column in another pair |
| `pair_invites` | `code` default: 16 random url-safe characters (`encode(gen_random_bytes(12), 'base64')` with `+/` replaced); `expires_at` default `now() + interval '24 hours'` |
| `devices` | `apns_env check in ('sandbox','production')`; `unique (user_id, apns_token)` |
| `widget_push_tokens` | `device_id` FK `on delete cascade`; `widget_kind check in ('notes','hobby')` |
| `calls` | `kind`, `status` checks per spec |
| `notes` | `id` has no default (made on the phone) |
| `items`, `logs` | `status check in ('current','finished')`; `percent check between 0 and 100`; `logs.item_id` FK `on delete cascade` |
| `catalog_entries` | `source check in ('openlibrary','tmdb','igdb')`; `details jsonb not null default '{}'` |

**Constraints:** all FKs to `profiles` `on delete cascade`. Indexes per spec.
**Reset needed:** first migration; `supabase db reset` locally, `supabase db push` on hosted.

**Trigger:** `handle_new_user()`, `security definer`, after insert on `auth.users` → `insert into public.profiles (id) values (new.id)`.

**Storage:** bucket `notes`, `public = false`.

**Realtime:** `alter publication supabase_realtime add table notes, items, checkins, calls`.

## Access rules
Helper: `public.is_paired_with(other uuid) returns boolean`, `language sql stable security definer set search_path = ''`; true when a `pairs` row holds `auth.uid()` and `other`.

RLS is enabled on every table. `auth.uid()` is wrapped as `(select auth.uid())` in policies so it is evaluated once per query.

| Table | select | insert | update | delete |
|---|---|---|---|---|
| `profiles` | own or partner | — (trigger) | own | — |
| `pairs` | own (`auth.uid() in (user_a, user_b)`) | — (RPC) | — | — |
| `pair_invites` | `created_by` own | `created_by = auth.uid()` | — | own |
| `devices` | **own only** (D5) | own | own | own |
| `widget_push_tokens` | own device only (D5) | own device | own device | own device |
| `calls` | caller or callee | — (service role) | — | — |
| `notes` | own or partner | `sender_id = auth.uid()` | — (RPC) | — |
| `favourites` | own or partner | own | — | own |
| `catalog_entries` | any authenticated | — (service role) | — | — |
| `items` | own or partner | own | own | own |
| `logs` | own or partner | — (RPC) | — | — |
| `checkins` | own or partner | — (RPC) | — | — |

**Storage (`storage.objects`, bucket `notes`):** insert and delete when `(storage.foldername(name))[1] = auth.uid()::text`; select when that folder is `auth.uid()` or `is_paired_with(folder::uuid)`.

## Writers
All RPCs are `security definer set search_path = ''`, check `auth.uid()` explicitly, and are granted `execute` to `authenticated` only (revoked from `anon`/`public`). Errors are raised with `raise exception using errcode = 'P0001'` and a short message the app can map.

### 1. Partner opens invite link → `accept_invite(p_code text) returns pairs`
1. Lock the invite (`for update`); fail `invite_not_found` if missing.
2. Fail `invite_expired` if `expires_at < now()`, and `invite_used` if `used_by` is set.
3. Fail `cannot_pair_self` if `created_by = auth.uid()`, and `already_paired` if either user is in a pair.
4. Insert `pairs (least, greatest)`, set `used_by`, `used_at`, and return the pair.

### 2. Tap +1 → `log_increment(p_log_id uuid, p_item_id uuid) returns items`
1. If a `logs` row with `p_log_id` exists, return the item unchanged (D8).
2. Lock the item; it must belong to `auth.uid()` and be `current`, else fail `item_not_found`.
3. Depending on the catalog entry's `hobby`:
   - **reading:** `chapter + 1`.
   - **games:** `hours + 1`.
   - **tv:** `episode + 1`. If that goes past `details.seasons[season].episode_count`, move to season + 1, episode 1. If there is no next season, do nothing and return the item without writing a log (D4).
4. Update the progress and `last_logged_at = now()`, insert a `logs` row with the new progress, and return the item.

### 3. Set progress by hand → `set_progress(p_log_id uuid, p_item_id uuid, p_chapter int, p_season int, p_episode int, p_percent smallint, p_hours numeric) returns items`
Same ownership and idempotency rules as §2. Null arguments leave a field unchanged. Writes the item, `last_logged_at` and a log row.

### 4. "Did it today" → `check_in(p_hobby hobby_kind, p_day date) returns void`
`insert … on conflict do nothing` on (`auth.uid()`, hobby, day).

### 5. Finish → `finish_item(p_item_id uuid) returns items`
Own item only. Sets `status = 'finished'`, `finished_at = coalesce(finished_at, now())`.

### 6. Unsend → `unsend_note(p_note_id uuid) returns notes`
1. Fail `note_not_found` unless `sender_id = auth.uid()`.
2. If already unsent, return it (D8).
3. Fail `unsend_window_passed` if `created_at < now() - interval '4 hours'`.
4. Set `unsent_at = now()`, delete its `favourites`, and return it. The app then deletes the Storage object (D1).

**Direct writes under RLS** (T10): the app inserts `notes`, `items`, `favourites`, `devices`, `widget_push_tokens` and `pair_invites`, and updates `profiles` and `items`.

## Readers
Plain PostgREST `select`s under RLS; there are no reader RPCs. The spec's indexes cover them: `notes (sender_id, created_at desc)`, `items (user_id, status)`, `calls (caller_id|callee_id, created_at)`.

## Contract for frontend
What ticket [3] (`ButtercupKit`) may call. Nothing else is exposed.

| Need | Call |
|---|---|
| My profile + partner's | `from('profiles').select()` (returns ≤ 2 rows) |
| Update my name / tz / tint | `from('profiles').update({display_name, time_zone, avatar_tint}).eq('id', me)` |
| Create invite | `from('pair_invites').insert({}).select('code, expires_at')` |
| Accept invite | `rpc('accept_invite', {p_code})` |
| Register device | `from('devices').upsert({user_id, apns_token, voip_token, apns_env})` |
| Widget push token | `from('widget_push_tokens').upsert({device_id, widget_kind, token})` |
| Send note | Storage `notes/{me}/{id}.heic` upload, then `from('notes').insert({id, sender_id, image_path})` |
| Unsend note | `rpc('unsend_note', {p_note_id})`, then Storage `remove(['{me}/{id}.heic'])` |
| Note image | Storage `createSignedUrl('{sender}/{id}.heic', 3600)` |
| Favourite / unfavourite | `from('favourites').insert/delete` |
| Start tracking | `from('items').insert({id, user_id, catalog_entry_id, status:'current', …, started_at, last_logged_at})` |
| +1 / set progress / finish | `rpc('log_increment' \| 'set_progress' \| 'finish_item', …)` |
| Check in | `rpc('check_in', {p_hobby, p_day})` |
| Sync since last pull | `select … where created_at > $last` (or `last_logged_at` for items) per table |
| Live updates | Realtime `postgres_changes` on `notes`, `items`, `checkins`, `calls` |

## End-to-End Flows
### Happy path: pair two accounts
```
A signs in with Apple
  └─► auth.users insert ─► handle_new_user ─► profiles(A)
A creates invite
  └─► insert pair_invites ─► code (expires in 24 h)
B signs in, opens link
  └─► rpc accept_invite(code)
        ├─ not expired, not used, not self, neither paired
        ├─ insert pairs(least(A,B), greatest(A,B))
        └─ invite marked used ─► is_paired_with now true both ways
```

### Edge case: outbox retries +1
```
App sends log_increment(L1, item) ─► network drops after commit
App retries log_increment(L1, item)
  └─► logs L1 exists ─► return item unchanged (chapter +1 applied once)
```

### Edge case: unsend after 4 h
```
rpc unsend_note(n) ─► created_at < now() - 4h ─► P0001 unsend_window_passed
```

## Blast Radius
| Change | What breaks |
|---|---|
| Renaming any table or column | The `ButtercupKit` contract above, Realtime subscriptions, and `push-partner` webhooks (ticket [2]) |
| Changing `is_paired_with` | Every select policy and the storage read policy |
| Changing the storage path shape | The storage policies and `notes.image_path` |
| Editing `<ts>_init.sql` after push | Hosted and local drift; always add a new migration instead |

## File Reference
| File | Role |
|---|---|
| `supabase/config.toml` | **new**, from `supabase init`; project_id `buttercup` |
| `supabase/migrations/<ts>_init.sql` | **new**: enum, tables, trigger, helper, RLS, RPCs, bucket, storage policies, publication |
| `supabase/seed.sql` | **new**: auth users + profiles, pair, catalog, sample rows (D7) |
| `supabase/tests/database/rls_rpc.test.sql` | **new**: pgTAP tests for the ACs below |
| [claude.md](../../claude.md) | Backend run/verify commands |

---

## Acceptance Criteria
- [x] AC1: `supabase db reset` applies the migration and seed cleanly on an empty local stack.
- [x] AC2: All 12 tables exist with RLS enabled (`select count(*) from pg_tables where schemaname='public' and rowsecurity` = 12).
- [x] AC3: Inserting into `auth.users` creates a matching `profiles` row (pgTAP).
- [x] AC4: An unpaired stranger reads 0 rows from `profiles` (other than their own), `notes`, `items`, `logs`, `checkins`, `favourites`, `calls` and `pairs` (pgTAP).
- [x] AC5: A partner can read but not insert, update or delete the other person's `notes`, `items` and `checkins` (pgTAP).
- [x] AC6: A partner cannot read the other person's `devices` or `widget_push_tokens` (pgTAP).
- [x] AC7: The `authenticated` role cannot insert into `calls` or `catalog_entries` (pgTAP).
- [x] AC8: `accept_invite` rejects expired, used, self and already-paired cases with their error messages, and on success creates `pairs` with `user_a < user_b` (pgTAP).
- [x] AC9: `log_increment` adds a chapter (reading) and an hour (games); rolls TV from S1E3 to S2E1; leaves S2E3 unchanged; and a repeated `log_id` changes nothing (pgTAP).
- [x] AC10: `check_in` called twice leaves 1 row; `finish_item` sets `finished` and `finished_at` (pgTAP).
- [x] AC11: `unsend_note` sets `unsent_at` and deletes favourites within 4 h, and fails after 4 h or for a non-sender (pgTAP).
- [x] AC12: Storage: the sender can upload to their own folder but not their partner's; the partner can select the object; a stranger cannot (pgTAP on `storage.objects`).
- [x] AC13: `notes`, `items`, `checkins` and `calls` are in `supabase_realtime` (`pg_publication_tables`).
- [x] AC14: `supabase test db` and `supabase db lint` pass.
- [x] AC15: The hosted project `nxqcwchrigseounzkvvz` is linked, `supabase db push` has applied the migration, and `supabase migration list --linked` shows local = remote. No password or key is committed.

## Required Changes
- **Init**: `supabase init`; keep the generated `config.toml` defaults (see [File Reference](#file-reference)).
- **Migration**: `supabase migration new init` → [Data Model](#data-model), [Access rules](#access-rules), [Writers](#writers).
- **Seed**: insert into `auth.users` (fixed uuids) so the trigger creates the profiles, then the pair, catalog and sample rows (D7).
- **Tests**: pgTAP using `set local role authenticated` + `set local request.jwt.claims` to impersonate the seed users, covering AC3–AC13.
- **Hosted**: `supabase link --project-ref nxqcwchrigseounzkvvz` (DB password from `SUPABASE_DB_PASSWORD`), then `supabase db push`. Requires the user to have run `supabase login`.

## Open Questions
- [ ] Should the free-project pause (after 7 days with little activity) get a keep-alive ping? Decide in ticket [2], alongside `pg_cron`.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Storage policy tests need the storage schema available in `supabase test db` | Med | AC12 unverified | Insert directly into `storage.objects` as the impersonated role; if blocked, mark ⚠️ and verify by hand in Studio |
| `supabase login` / DB password missing in the agent's env | High | AC15 blocked | The PRD is filed `partial` with clear steps for the user |

---
*Status: READY — ticket [1]*
