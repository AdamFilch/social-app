# [3]: Backend — Calls

This ticket adds the server side of a buttercup call: the three Edge Functions that create, answer and end calls, the database rules that keep the `calls` table consistent, and a local LiveKit server for development. A call is one row in `calls` (from PRD [1]) plus a LiveKit room named after that row's id. `start-call` creates the row as `ringing` and returns a LiveKit token for the caller. The callee's app sees the new row over Realtime. `answer-call` marks it `answered` and returns the callee's token, and `end-call` moves it to a final status. A one-minute `pg_cron` sweep marks forgotten ringing calls as missed. Pushes are not part of this ticket; [8] adds them to these same functions.

Frontend half: [[3]: Frontend — Calls](../3-frontend-calls.prd.md), built on the contract at the end of this document.

## Summary
Adds one migration (an index allowing one active call per pair, plus the missed-call sweep), three Edge Functions with shared helpers, function tests, passwords for the two seed users so tests can sign in, and backend commands for the local LiveKit dev server. The `calls` columns and RLS from PRD [1] don't change, so the app still only reads `calls`.

## Users
- **Primary**: [3] Frontend (the `CallStore` in the app), and the developer agent verifying calls between a simulator and a browser.
- **Not for**: end users directly; no screen changes.

## Scope
**MVP**
- Migration: `calls_one_active_per_pair` partial unique index, `sweep_ringing_calls()` + `pg_cron` schedule
- Edge Functions `start-call`, `answer-call`, `end-call` and `_shared/` helpers
- LiveKit tokens via `npm:livekit-server-sdk`; stale-call check via its `RoomServiceClient` (D38)
- Function tests (Deno) against `supabase functions serve` + `livekit-server --dev`
- Seed: passwords for the two paired seed users and the stranger (test-only)
- CLAUDE.md: LiveKit dev server + functions commands

**Out of scope**
- VoIP push, cancel push, missed-call notification — ticket [8]
- Hosted deploy of functions with LiveKit Cloud secrets — needs a LiveKit Cloud project (D9). Listed as a manual step in [8], or earlier if you create the project sooner.

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Data Model](#data-model)
4. [State Machine](#state-machine)
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
| D1 | Missing sign-in/pairing/client | A foundation ticket [2] before any call ticket | Calls need real paired users; nothing gets thrown away | User |
| D2 | Ticket granularity | One PRD per build step, big steps split (step 1 → backend/frontend, step 3 → stickers / pad, step 5 → backend/frontend) | Each ticket verifiable in one go | User |
| D3 | Heat test (step 4) | Checklist-only PRD, no code | It's a manual test | User |
| D4 | Ringing before CallKit | In-app incoming sheet driven by Realtime on `calls` while the callee's app is open | Matches technical-spec §5 two-simulator testing | User |
| D5 | Invite delivery | Share sheet with `buttercup://invite/CODE` (custom URL scheme) plus a paste-code field | No domain needed | User |
| D6 | Onboarding | Name only (prefilled if available); `time_zone` from the phone; `avatar_tint` auto at pairing | Shortest path | User |
| D7 | Visual design | Plain SwiftUI for all these tickets; designer agent spec → separate restyle ticket later | User will run the designer on the call screens | User |
| D8 | Foundation screens | Plain SwiftUI, designer later | Used once by two people | User |
| D9 | Accounts | None yet (no paid Apple account, LiveKit Cloud or APNs key). Each ticket opens with a manual setup checklist | Stated by user | User |
| D10 | Sign-in method | Supabase email one-time code now; Sign in with Apple is a later ticket | Works without a paid account and on simulators (Mailpit locally) | User |
| D11 | LiveKit environment | Local `livekit-server --dev` for development and agent verification; LiveKit Cloud keys only as hosted Edge Function secrets for the phones | Verifiable without an account | User |
| D12 | Call history | In step 1: "Recent calls" on the Calling tab, read from `calls`; missed shown as missed | Plain RLS read; helps verify statuses | User |
| D13 | In-call controls | Mute, camera on/off, flip front/back, audio route picker (`AVRoutePickerView`); flip lives on the self tile (revised by D40) | User picked all four | User |
| D14 | Call writers | `start-call`, `answer-call`, `end-call` are all Edge Functions, as in technical-spec §3 | Matches spec | User |
| D15 | Busy / glare | One active (`ringing` or `answered`) call per pair; `start-call` returns the existing ringing call so the second tapper sees it as incoming | No double rings | User |
| D16 | Network drop | Show "Reconnecting…" while LiveKit retries; end as `ended` if the partner isn't back after ~30 s | Survives Wi-Fi → cellular | User |
| D17 | Missed calls | Ring timeout in step 1 (caller calls `end-call` `missed` at 45 s; `pg_cron` sweeps `ringing` > 60 s); missed-call notification in step 5 (made local, revised by D43) | Notification arrives with the ringing work | User |
| D18 | Image stickers | Bundle every PNG in `assets/stickers` at build time; developer adds 2–3 placeholders | Assets folder is empty today | User |
| D19 | Sticker gestures | Drag to move (re-pins), pinch to resize, twist to rotate; tap → trash (spec) | User picked all | User |
| D20 | Face lost | Stickers freeze at the last face position until tracking returns | User choice | User |
| D21 | Text stickers | Type text + pick one of ~6 colours; rounded bold with ink outline | Small sheet | User |
| D22 | Drawing pad | PencilKit canvas + `PKToolPicker`, transparent background → PNG sticker | Least code | User |
| D23 | Sticker cap | Max 10 on the face at once; revisit after step 4 | Predictable load on iPhone 11 | User |
| D24 | Foreground ringing after step 5 | CallKit everywhere; the step-1 in-app sheet is removed | One code path | User |
| D25 | CallKit extras | Outgoing calls via `CXStartCallAction` (Recents, Bluetooth/CarPlay), call back from Recents (`INStartCallIntent`), answer on lock screen/Bluetooth | User picked all | User |
| D26 | Ticket list | [2] Foundation; [3] Backend/Frontend Calls; [4] ARKit camera; [5] Stickers; [6] Drawing pad; [7] Heat test; [8] Backend/Frontend Ringing | Confirmed | User |
| D27 | Live call updates | Realtime `postgres_changes` on `calls` (already in the publication) rather than a broadcast channel | Already set up in PRD [1] | Claude — straightforward |
| D28 | Callee token delivery | `answer-call` returns the callee's LiveKit token; tokens never stored in `calls` or sent in pushes (step 5 push carries `call_id` + caller name only) | Partner can read `calls`; tokens are credentials | Claude — security |
| D29 | Room name | `room_name = calls.id::text` | Unique by construction | Claude — straightforward |
| D30 | Outbox / SwiftData | Not built in [2]; calls skip the outbox (technical-spec §1); arrives with the Notes tickets | YAGNI | Claude — straightforward |
| D31 | `avatar_tint` assignment | After pairing, each app sets its own tint to the first NotePaper colour the partner isn't using (direct `profiles` update, already allowed) | No migration needed | Claude — straightforward |
| D32 | Simulator video | `#if targetEnvironment(simulator)` feeds a bundled test clip through LiveKit `BufferCapturer` (technical-spec §5) | Simulator has no camera | Claude — straightforward |
| D33 | Back camera | Front = ARKit (`ARFaceTrackingConfiguration`, 30 fps, 720p, light estimation off); back = LiveKit's camera capturer with no stickers | ARKit face tracking is front-only | Claude — straightforward |
| D34 | Sticker lifetime | Kept in memory while camera is off; cleared at call end (spec) | Spec | Claude — straightforward |
| D35 | Heat fallback | `ProcessInfo.thermalState == .critical` hides stickers, restored below it (spec) | Spec | Claude — straightforward |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |
| D37 | Secrets | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (later `APNS_*`) via `supabase secrets set`; local values in gitignored `supabase/functions/.env` | CLAUDE.md: no secrets committed | Claude — straightforward |
| D38 | Stale `answered` call (both apps died mid-call) | When `start-call` finds an `answered` call for the pair, it asks LiveKit's RoomService whether the room has participants; if empty, it marks the call `ended` and continues | Otherwise the one-active-call index (D15) blocks every future call | Claude — straightforward |
| D39 | Self tile sizes (FaceTime-style) | Small corner tile → tap → mid tile with buttons → expand (↗) button → big self view with the partner as the small tile; tap the partner's small tile to swap back; tapping elsewhere while mid returns to small | User described FaceTime's behaviour | User |
| D40 | Mid tile buttons | Flip camera (moved off the main bar) and Add sticker ([5]); main bar keeps mute, camera on/off, audio route, hang up | User picked | User |
| D41 | Add sticker from the mid tile | Switches to the big self view and opens the tray; stickers are only placed and edited in the big self view | Inferred from "edit my stickers here" (big view) — veto at review | Claude — inferred |
| D42 | Cancel push | `end-call` sends a VoIP push `{call_id, status}` for `cancelled` / `missed`; the app ends the matching CallKit call, or reports and immediately ends it if it never showed | PushKit requires every VoIP push to be reported to CallKit (ios-limits §3) | Claude — iOS rule |
| D43 | Missed-call notification | A local notification from the callee's app ("Missed call from {name}") when its ringing call ends as `missed` or `cancelled`; the callee's app also stops ringing after 60 s on its own; no server alert push | The ringing phone is already awake; covers the `pg_cron` sweep path with no extra server code — veto at review | Claude — straightforward |
| D44 | Simulator incoming calls after [8] | On simulator builds, the Realtime insert reports the call to CallKit locally, since simulators get no VoIP push | Keeps the two-simulator test from technical-spec §5 working | Claude — straightforward |
| D45 | Session readable while locked | Supabase session stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlock` | Answering from the lock screen must call `answer-call` before unlock | Claude — iOS rule |

## Overview
`calls` is the single source of truth for a call's state and doubles as the call history (D12). The LiveKit room `calls.id::text` carries the media (D29). Every status change happens in an Edge Function using the service role. The app never writes `calls`, as PRD [1] AC7 requires.

Questions the data answers:
1. **Is the pair already on a call?** → a `calls` row for the pair with `status in ('ringing','answered')`, at most one, enforced by the index
2. **Is a call ringing for me?** → Realtime insert on `calls` where `callee_id = me` and `status = 'ringing'`
3. **Did it connect?** → `answered_at is not null`

Non-obvious design decisions:
1. **Tokens are returned, never stored** ([D28](#decision-log)). Both people can read the `calls` row, so a token in it would let anyone holding the row join the room. `answer-call` therefore mints the callee's token at answer time.
2. **A second start returns the existing call** ([D15](#decision-log)). If both of you tap Call at once, the index lets only one insert through. The other request gets the existing row back with `incoming: true`, and that app shows it as an incoming call.
3. **Two LiveKit URLs.** Apps connect to `LIVEKIT_URL` (local: `ws://127.0.0.1:7880`). The functions run in Docker and call RoomService at `LIVEKIT_API_URL` (local: `http://host.docker.internal:7880`; hosted: unset, so it falls back to `LIVEKIT_URL` with `wss`→`https`).
4. **All three functions are idempotent.** Repeating `start-call` while my own call is ringing returns it. Repeating `answer-call` as the callee of an answered call returns a fresh token, which is how a reconnect gets back in. Repeating `end-call` on a finished call returns it unchanged.

## Data Model
### `calls` table (unchanged, for reference)
> Source: [supabase/migrations/20261019102934_init.sql](../../supabase/migrations/20261019102934_init.sql)

| Column | Type | Description |
|---|---|---|
| `id` | uuid pk | also the LiveKit room name |
| `room_name` | text unique | set to `id::text` by `start-call` |
| `caller_id`, `callee_id` | uuid → profiles | |
| `kind` | text `audio`/`video` | how it started; never changes when the camera toggles |
| `status` | text | see [State Machine](#state-machine) |
| `created_at`, `answered_at`, `ended_at` | timestamptz | |

**New (migration `<ts>_calls_rules.sql`):**
- `create unique index calls_one_active_per_pair on public.calls (least(caller_id, callee_id), greatest(caller_id, callee_id)) where status in ('ringing', 'answered');`
- `create extension if not exists pg_cron;`
- **new** `public.sweep_ringing_calls() returns int`, `security definer set search_path = ''`. It runs `update calls set status = 'missed', ended_at = now() where status = 'ringing' and created_at < now() - interval '60 seconds'` and returns the row count. Execute is revoked from `public`, `anon` and `authenticated`.
- `select cron.schedule('sweep-ringing-calls', '* * * * *', 'select public.sweep_ringing_calls()');`

**Reset needed:** yes, `supabase db reset`; hosted `supabase db push`.

## State Machine
```
              ┌─ answer-call (callee) ─► [answered] ─ end-call ended (either) ─► [ended]
[ringing] ────┼─ end-call declined (callee) ─► [declined]
              ├─ end-call cancelled (caller) ─► [cancelled]
              └─ end-call missed (caller, 45 s)  or  sweep (60 s) ─► [missed]
```
| Transition | Who | From |
|---|---|---|
| `answered` | callee | `ringing` |
| `declined` | callee | `ringing` |
| `cancelled`, `missed` | caller | `ringing` |
| `ended` | caller or callee | `answered` |

Every terminal transition sets `ended_at = now()`. **Blocked:** any other transition returns `invalid_transition`; a terminal row is returned unchanged.

## Writers
All three: `POST`, JWT required (default `verify_jwt`). The caller is resolved with `auth.getUser(jwt)`, and writes use a service-role client. Errors come back as `{ "error": "<code>" }` with HTTP 400 (bad input), 403 (`not_paired`), 404 (`call_not_found`) or 409 (state).

### 1. Tap Audio / Video → `start-call`
> Source: `supabase/functions/start-call/index.ts` (**new**)

**Body:** `{ "kind": "audio" | "video" }`

**What it does:**
1. Find my partner from `pairs`; no pair → 403 `not_paired`.
2. Look for an active call for the pair:
   - `ringing`, I'm the caller → return it with my token (retry).
   - `ringing`, I'm the callee → return `{ call, incoming: true }` with no token (D15).
   - `answered` → ask RoomService for the participants in `room_name`. If there are none, set it `ended` and continue (D38); otherwise 409 `busy`.
3. Insert `{id, room_name: id, caller_id: me, callee_id: partner, kind, status: 'ringing'}`. On a unique-index violation (a race), go back to step 2 once.
4. Return `{ call, token, livekit_url }`.

### 2. Tap Answer → `answer-call`
> Source: `supabase/functions/answer-call/index.ts` (**new**)

**Body:** `{ "call_id": uuid }`
1. Load the call; not found or I'm not the callee → 404 `call_not_found`.
2. `ringing` → set `answered`, `answered_at = now()`. `answered` → leave it (reconnect). Anything else → 409 `call_not_ringing` with `{ status }`.
3. Return `{ call, token, livekit_url }`.

### 3. Hang up / decline / cancel / timeout → `end-call`
> Source: `supabase/functions/end-call/index.ts` (**new**)

**Body:** `{ "call_id": uuid, "reason": "declined" | "cancelled" | "missed" | "ended" }`
1. Load the call; not a participant → 404 `call_not_found`.
2. Already terminal → return it unchanged.
3. Check the [State Machine](#state-machine) table; a disallowed transition → 409 `invalid_transition`.
4. Set `status = reason`, `ended_at = now()`, and return `{ call }`.

**Tokens** (`_shared/livekit.ts`): `AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, { identity: user_id, ttl: '2h' })` with grant `{ room: room_name, roomJoin: true, canPublish: true, canSubscribe: true }`.

**Does not write:** `devices`, `profiles` or any other table; no pushes ([8]).

## Readers
### `from('calls').select().order('created_at', desc).limit(50)`
Plain RLS read (caller or callee). **Why:** Recent calls on the Calling tab.

### Realtime `postgres_changes` on `calls`
`event: *`, RLS-filtered, so each app only sees its own calls. **Why:** the incoming sheet (insert with me as callee), and the caller learning that the call was answered, declined or missed (update).

## Contract for frontend
| Need | Call | Returns |
|---|---|---|
| Start a call | `functions.invoke('start-call', {kind})` | `{call, token, livekit_url}` or `{call, incoming: true}`; errors `not_paired`, `busy` |
| Answer / rejoin | `functions.invoke('answer-call', {call_id})` | `{call, token, livekit_url}`; errors `call_not_found`, `call_not_ringing` |
| End | `functions.invoke('end-call', {call_id, reason})` | `{call}`; errors `call_not_found`, `invalid_transition` |
| Live status | Realtime `postgres_changes` on `public.calls` | the row |
| History | `from('calls').select().order('created_at', {ascending:false}).limit(50)` | rows |

`call` is the full `calls` row in snake_case.

## End-to-End Flows
### Happy path
```
A start-call {video} ─► insert ringing ─► A joins room with token
B Realtime insert (callee = B) ─► incoming sheet ─► answer-call ─► answered ─► B joins
A Realtime update answered ─► show in-call
A end-call {ended} ─► ended, ended_at ─► B sees update, leaves room
```
### Edge case: both tap at once
```
A start-call ─► insert ok (ringing, A→B)
B start-call ─► active ringing, B is callee ─► {call, incoming: true} ─► B shows incoming
```
### Edge case: caller's app dies while ringing
```
No end-call ─► sweep at next minute (≥ 60 s) ─► missed
```

## Blast Radius
| Change | What breaks |
|---|---|
| Function names or bodies | [3] Frontend `CallStore`; [8] Frontend CallKit answer path |
| Response `call` shape | Realtime and history decoding share the same `Call` model |
| Index predicate | D15 busy/glare behaviour |
| Token identity (`user_id`) | The app matches LiveKit participants to profiles by identity |

## File Reference
| File | Role |
|---|---|
| `supabase/migrations/<ts>_calls_rules.sql` | **new** index, sweep, cron |
| `supabase/functions/_shared/supabase.ts` | **new** admin client + `getUser` |
| `supabase/functions/_shared/livekit.ts` | **new** token + room participant check |
| `supabase/functions/start-call/index.ts` | **new** |
| `supabase/functions/answer-call/index.ts` | **new** |
| `supabase/functions/end-call/index.ts` | **new** |
| `supabase/functions/tests/calls.test.ts` | **new** Deno tests |
| `supabase/functions/.env.example` | **new** keys with local dev values (`devkey` / `secret`) |
| `supabase/tests/database/calls_rules.test.sql` | **new** pgTAP |
| [supabase/seed.sql](../../supabase/seed.sql) | seed users get `encrypted_password = crypt('password', gen_salt('bf'))` |
| [claude.md](../../claude.md) | add `brew install livekit`, `livekit-server --dev`, `supabase functions serve --env-file supabase/functions/.env`, function tests |

---

## Acceptance Criteria
- [x] AC1: pgTAP: a second `ringing` row for the same pair (either direction) violates `calls_one_active_per_pair`; an `ended` row doesn't block a new one.
- [x] AC2: pgTAP: `sweep_ringing_calls()` marks a 61-second-old ringing call `missed` with `ended_at`, leaves a 30-second-old one alone, and `authenticated` can't execute it. `cron.job` contains `sweep-ringing-calls`.
- [x] AC3: Deno: `start-call` as Adam returns `ringing`, `room_name = id`, and a JWT token whose `video.room` is that id.
- [x] AC4: Deno: `start-call` from the stranger → 403 `not_paired`; Partner calling while Adam's call rings → `incoming: true`.
- [x] AC5: Deno: `answer-call` by the callee → `answered` + token; by the caller → 404; on a `cancelled` call → 409 `call_not_ringing`.
- [x] AC6: Deno: every allowed `end-call` transition in the State Machine table succeeds, and `declined` by the caller and `ended` on a `ringing` call return 409 `invalid_transition`. A repeated call returns the row unchanged.
- [x] AC7: Deno: with an `answered` call whose room is empty, `start-call` marks it `ended` and creates a new call (D38).
- [x] AC8: `lk room join --url ws://127.0.0.1:7880 --token <token from start-call>` connects to the dev server.
- [x] AC9: `supabase db reset && supabase test db && supabase db lint` pass, and the Deno tests pass with `supabase functions serve` and `livekit-server --dev` running. No secrets are committed.

## Required Changes
- **Migration**: `supabase migration new calls_rules` → [Data Model](#data-model).
- **Functions**: three functions + `_shared` → [Writers](#writers).
- **Env**: `.env.example` with `LIVEKIT_URL=ws://127.0.0.1:7880`, `LIVEKIT_API_URL=http://host.docker.internal:7880`, `LIVEKIT_API_KEY=devkey`, `LIVEKIT_API_SECRET=secret` (D37).
- **Seed**: passwords for the seed users.
- **Tests**: pgTAP for AC1–AC2, Deno for AC3–AC7.
- **Docs**: CLAUDE.md backend table.

## Features Catalog
- **Extends**: New feature (#1 Calls). Create the entry in `.claude/context/features.md`.
- **Closes known gaps**: none

## Open Questions
- [ ] When should the LiveKit Cloud project be created? Needed before calls work on the phones; at the latest in [8].

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `pg_cron` not available in the local stack image | Low | AC2 | It ships with Supabase Postgres; if not, mark AC2 ⚠️ and rely on the 45 s client timeout |
| `host.docker.internal` unreachable from edge runtime | Low | AC7 | `LIVEKIT_API_URL` is configurable |

---
*Status: COMPLETED — PR #PENDING*
