# [8]: Backend — Ringing

This ticket makes a buttercup call ring a phone that is closed or locked. When `start-call` creates a ringing call, it now also sends an Apple **VoIP push** to every device of the callee that has registered a `voip_token`. The push carries only the call id, the caller's name and whether it is audio or video, never a LiveKit token (D28). iOS wakes the app, which must show the call through CallKit at once. When the caller cancels or the 45 s timeout passes, `end-call` sends a second VoIP push telling that phone to stop ringing (D42). The missed-call notification is local on the callee's phone (D43), so the server sends no alert pushes in this ticket.

This ticket is also where the hosted backend first needs real accounts, so it opens with a setup checklist for Adam.

Frontend half: [[8]: Frontend — Ringing](8-frontend-callkit-ringing.prd.md).

## Summary
Adds an APNs helper to the Edge Functions (`_shared/apns.ts`: ES256 JWT from the `.p8` key, HTTP/2 to the sandbox or production host chosen by `devices.apns_env`). `start-call` sends the ring push and `end-call` the cancel push. Device rows whose token APNs rejects as unregistered are deleted. The functions are deployed to the hosted project with LiveKit Cloud and APNs secrets. No schema change.

## Users
- **Primary**: [8] Frontend, which receives the pushes; Adam, who does the account setup.
- **Not for**: simulators (no VoIP push, D44).

## Scope
**MVP**
- Manual setup checklist (below)
- `_shared/apns.ts`; ring push in `start-call`; cancel push in `end-call`
- `410 Unregistered` / `400 BadDeviceToken` → delete that `devices` row
- `supabase functions deploy start-call answer-call end-call` + `supabase secrets set` (D37)

**Out of scope**
- Alert pushes (`push-partner`, notes, hobbies) — later tickets
- Missed-call alert push — local instead (D43)

## Manual setup (Adam, before the developer starts)
1. Enrol in the Apple Developer Program (paid) and add both iPhones.
2. In Certificates, IDs & Profiles, give the app id **Push Notifications**. Create an **APNs Auth Key** (`.p8`) and note the Key ID and Team ID.
3. Create a **LiveKit Cloud** project; note its URL, API key and secret.
4. `supabase secrets set LIVEKIT_URL=wss://… LIVEKIT_API_KEY=… LIVEKIT_API_SECRET=… APNS_KEY_ID=… APNS_TEAM_ID=… APNS_BUNDLE_ID=<bundle id> APNS_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"`
5. Keep the `.p8` file outside the repo.

---

## Table of Contents
1. [Decision Log](#decision-log)
2. [Overview](#overview)
3. [Writers](#writers)
4. [Contract for frontend](#contract-for-frontend)
5. [End-to-End Flows](#end-to-end-flows)
6. [Blast Radius](#blast-radius)
7. [File Reference](#file-reference)
8. [Acceptance Criteria](#acceptance-criteria)
9. [Required Changes](#required-changes)

---

## Decision Log
| #  | Decision | Choice | Why | Decided by |
|----|----------|--------|-----|------------|
| D9 | Accounts | None yet (no paid Apple account, LiveKit Cloud or APNs key). Each ticket opens with a manual setup checklist | Stated by user | User |
| D17 | Missed calls | Ring timeout in step 1 (caller calls `end-call` `missed` at 45 s; `pg_cron` sweeps `ringing` > 60 s); missed-call notification in step 5 (made local, revised by D43) | Notification arrives with the ringing work | User |
| D24 | Foreground ringing after step 5 | CallKit everywhere; the step-1 in-app sheet is removed | One code path | User |
| D25 | CallKit extras | Outgoing calls via `CXStartCallAction` (Recents, Bluetooth/CarPlay), call back from Recents (`INStartCallIntent`), answer on lock screen/Bluetooth | User picked all | User |
| D28 | Callee token delivery | `answer-call` returns the callee's LiveKit token; tokens never stored in `calls` or sent in pushes (step 5 push carries `call_id` + caller name only) | Partner can read `calls`; tokens are credentials | Claude — security |
| D36 | Device-only verification | Tickets needing camera/push ([4], [5], [6], [8] frontend) build + simulator-check what's possible; on-device ACs are a manual checklist, filed `partial` until the user runs it | Agent can't hold two iPhones | Claude — straightforward |
| D37 | Secrets | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (later `APNS_*`) via `supabase secrets set`; local values in gitignored `supabase/functions/.env` | CLAUDE.md: no secrets committed | Claude — straightforward |
| D42 | Cancel push | `end-call` sends a VoIP push `{call_id, status}` for `cancelled` / `missed`; the app ends the matching CallKit call, or reports and immediately ends it if it never showed | PushKit requires every VoIP push to be reported to CallKit (ios-limits §3) | Claude — iOS rule |
| D43 | Missed-call notification | A local notification from the callee's app ("Missed call from {name}") when its ringing call ends as `missed` or `cancelled`; the callee's app also stops ringing after 60 s on its own; no server alert push | The ringing phone is already awake; covers the `pg_cron` sweep path with no extra server code — veto at review | Claude — straightforward |
| D44 | Simulator incoming calls after [8] | On simulator builds, the Realtime insert reports the call to CallKit locally, since simulators get no VoIP push | Keeps the two-simulator test from technical-spec §5 working | Claude — straightforward |
| D45 | Session readable while locked | Supabase session stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlock` | Answering from the lock screen must call `answer-call` before unlock | Claude — iOS rule |

## Overview
`devices` (PRD [1]) already holds `voip_token` and `apns_env` per device, readable only by its owner and by the service role. The functions read the callee's devices with the service-role client and send one push per device.

Non-obvious design decisions:
1. **Push failures never fail the call.** `start-call` returns the caller's token even if APNs is down. Pushes are sent after the insert, with a 5 s timeout, and errors are logged. The caller then sees a normal unanswered call, and the callee's app (if it's open) still sees the Realtime insert.
2. **The topic is `<bundle id>.voip`** for VoIP pushes, with `apns-push-type: voip`, `apns-priority: 10` and `apns-expiration: 0`, so a ring is never delivered late.
3. **The JWT is cached for 50 minutes** inside the function instance. APNs rejects tokens older than an hour, and refreshing too often gets throttled.

## Writers
### 1. `start-call` (changed)
After a **new** row is inserted (not on the retry or `incoming` paths), it sends to each callee device with a non-null `voip_token`:
```json
{ "type": "ring", "call_id": "<uuid>", "caller_name": "Adam", "kind": "video" }
```

### 2. `end-call` (changed)
When `reason` is `cancelled` or `missed`, it sends to each callee device:
```json
{ "type": "cancel", "call_id": "<uuid>", "status": "missed" }
```
`declined` and `ended` send nothing, because the callee's own app already knows.

**Edge cases:**
- Callee has no device with a `voip_token` → no push; the call still rings in an open app via Realtime.
- APNs `410` or `400 BadDeviceToken` → delete that `devices` row.

**Does not write:** `calls` (unchanged rules from [3]); `devices` except deleting dead tokens.

## Contract for frontend
| Need | Call / payload |
|---|---|
| Register for ringing | `from('devices').upsert({user_id, apns_token, voip_token, apns_env}, onConflict: 'user_id,apns_token')` (PRD [1]) |
| Ring push | `{type: "ring", call_id, caller_name, kind}` |
| Cancel push | `{type: "cancel", call_id, status}` |
| Answer / decline / end | unchanged [3] contract |

## End-to-End Flows
### Happy path: ring a locked phone
```
A start-call ─► insert ringing ─► APNs voip push ─► B's phone wakes ─► CallKit ring
```
### Edge case: caller cancels
```
A end-call cancelled ─► cancel push ─► B ends CallKit call ─► local "Missed call from Adam"
```

## Blast Radius
| Change | What breaks |
|---|---|
| Push payload keys | [8] Frontend push handler; a wrong shape means a VoIP push the app can't report, and iOS kills it |
| `APNS_BUNDLE_ID` | Every push (topic mismatch → 400) |

## File Reference
| File | Role |
|---|---|
| `supabase/functions/_shared/apns.ts` | **new** JWT + send + dead-token cleanup |
| `supabase/functions/start-call/index.ts` | ring push (from [3]) |
| `supabase/functions/end-call/index.ts` | cancel push (from [3]) |
| `supabase/functions/tests/apns.test.ts` | **new** tests with a stubbed `fetch` |

---

## Acceptance Criteria
- [ ] AC1: Deno: `start-call` creating a new call sends exactly one ring push per callee device with a `voip_token`, to `api.sandbox.push.apple.com` for `sandbox` rows and `api.push.apple.com` for `production`, with the headers in Overview §2 (stubbed `fetch`).
- [ ] AC2: Deno: the retry and `incoming: true` paths send no push.
- [ ] AC3: Deno: `end-call` `cancelled` and `missed` send a cancel push; `declined` and `ended` send none.
- [ ] AC4: Deno: an APNs `410` deletes that device row; an APNs network error still returns the call with a token.
- [ ] AC5: The [3] backend tests still pass, and `supabase db reset && supabase test db && supabase db lint` pass.
- [ ] AC6 (hosted, manual): after setup, the functions are deployed and `start-call` on the hosted project returns a LiveKit Cloud token. A real push reaches a registered phone (checked together with [8] Frontend AC1).
- [ ] AC7: No secret or `.p8` content is committed.

## Required Changes
- **APNs helper**: see [Overview](#overview).
- **Functions**: push calls per [Writers](#writers).
- **Deploy**: secrets + `supabase functions deploy` (manual setup above).

## Features Catalog
- **Extends**: #1 Calls
- **Closes known gaps**: none

## Open Questions
- [ ] video-calls-spec says "the caller gets a missed-call notification". This plan notifies the **callee** (the person who missed it), like the Phone app. Confirm.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Edge runtime `fetch` doesn't negotiate HTTP/2 with APNs | Low | No pushes | Verify in AC6 early; fallback: a tiny relay is out of scope, so flag it |
| Free Supabase project paused | Med | Calls fail | PRD [1] open question about a keep-alive ping |

---
*Status: READY — ticket [8] backend*
